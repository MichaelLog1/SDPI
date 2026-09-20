`timescale 1 ns / 10 ps

module clkdiv_tb #(
    bit USE_FRAC_DIV = 1,
    int unsigned DIV_INT_WIDTH = 16,
    int unsigned DIV_FRAC_WIDTH = 8,
    int unsigned NUM_TESTS = 1000
);

    logic clk = 0;
    logic rst_n;
    logic en;
    logic [DIV_INT_WIDTH-1:0] div_int;
    logic [DIV_FRAC_WIDTH-1:0] div_frac;
    logic tick;

    int queue [$];
    int errors = 0;
    int test_count = NUM_TESTS;

    clkdiv #(
        .USE_FRAC_DIV(USE_FRAC_DIV),
        .DIV_INT_WIDTH(DIV_INT_WIDTH),
        .DIV_FRAC_WIDTH(DIV_FRAC_WIDTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .div_int(div_int),
        .div_frac(div_frac),
        .tick(tick)
    );

    initial begin : generate_clock
        forever #10 clk <= ~clk;
    end

    task automatic reset(int cycles);
        rst_n <= 1'b0;
        en <= 1'b0;
        div_int <= 0;
        div_frac <= 0;
        repeat (cycles) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;
    endtask

    task automatic driver();
        logic [DIV_INT_WIDTH-1:0] temp_int;
        logic [DIV_FRAC_WIDTH-1:0] temp_frac;
        forever begin
            en <= 1'b0;
            assert(std::randomize(temp_int) with {
                temp_int dist { 0 :/ 20,
                              1 :/ 20,
                              [2:2**DIV_INT_WIDTH-2] :/ 40, 
                              2**DIV_INT_WIDTH-1 :/ 20
                            };
            });
            
            assert(std::randomize(temp_frac) with {
                temp_frac dist {
                              [0:2**DIV_FRAC_WIDTH-1] :/ 100
                            };
            });

            div_int <= temp_int;
            div_frac <= temp_frac;

            repeat ($urandom_range(1, 100)) @(posedge clk);
            en <= 1'b1;
            repeat (2 + $urandom_range(0, 3*div_int)) @(posedge clk);
        end
    endtask

    task automatic monitor();
        int prev = 0;
        int curr = 0;
        int current_cycle = 0;
        logic [DIV_INT_WIDTH-1:0] current_div_int;
        logic [DIV_FRAC_WIDTH-1:0] current_div_frac;
        bit clean = 1;
        bit restart = 1;
        do begin
            @(posedge clk);
            current_cycle++;
        end while (!tick);
        prev = current_cycle;

        forever begin
            do begin
                if (!en || !rst_n) begin
                    clean = 0;
                    restart = 1;
                end
                current_div_int = div_int;
                current_div_frac = div_frac;
                @(posedge clk);
                current_cycle++;
            end while (!tick);
            curr = current_cycle;
            if (clean) begin
                queue.push_back(curr-prev);        // the gap
                queue.push_back(current_div_int);  // div_int for this gap
                queue.push_back(current_div_frac); // div_frac for this gap
                queue.push_back(restart);          // should the accumulator's frac state be cleared?
                restart = 0;
            end
            prev = current_cycle;
            clean = 1;
        end
    endtask

    task automatic scoreboard();
        int gap;
        int expected_gap;
        logic [DIV_INT_WIDTH-1:0] observed_int_div;
        logic [DIV_FRAC_WIDTH-1:0] observed_frac_div;
        bit restart;
        logic [DIV_FRAC_WIDTH-1:0] frac_accumulator;
        logic [DIV_FRAC_WIDTH:0] frac_ovf;
        int ovf;

        forever begin
            do begin
                @(posedge clk);
            end while (queue.size() == 0);
            gap = queue.pop_front();
            observed_int_div = queue.pop_front();
            observed_frac_div = queue.pop_front();
            restart = queue.pop_front();

            // update model

            // if we restart, clear the fraction accumulator first
            if (restart) begin
                frac_accumulator = 0;
            end

            // compute accumulator value and determine if ovf occured
            frac_ovf = frac_accumulator + observed_frac_div;
            frac_accumulator = frac_ovf[DIV_FRAC_WIDTH-1:0];

            // if we ovf, the expected gap is incremented
            if (frac_ovf[DIV_FRAC_WIDTH] == 1) begin
                ovf = 1;
            end else begin
                ovf = 0;
            end

            expected_gap = observed_int_div ? observed_int_div : 1;
            if (USE_FRAC_DIV) expected_gap = expected_gap + ovf;
            if (gap !== expected_gap) begin
                errors++;
                $error("[%0t]: Gap: %d, Expected: %d", $time, gap, expected_gap);
            end
            test_count--;
        end
    endtask

    task automatic tick_watchdog();
        int count = 0;
        logic [DIV_INT_WIDTH:0] expected_div_int;
        forever begin
            @(posedge clk);
            if (!en || !rst_n) begin
                count = 0;
            end else if (tick) begin
                count = 0;
            end else begin
                count++;
            end
            expected_div_int = div_int ? div_int : 1;
            if (USE_FRAC_DIV) expected_div_int++;
            if (count > expected_div_int) begin
                $fatal(1, "[WATCHDOG]: count: %d, expected: %d, div_int: %d\n", count, expected_div_int, div_int);
            end
        end
    endtask

    initial begin
        // fork tasks here
        reset(5);

        fork
            driver();
            monitor();
            scoreboard();
            tick_watchdog();
        join_none

        do @(posedge clk); while (test_count);
        // report error count or test done
        if (errors > 0) $display("%d errors reported.", errors);
        else $display("Tests complete.");
        $finish;
    end

    assert property (@(posedge clk) !rst_n |=> !tick)
    else errors++;
    assert property (@(posedge clk) disable iff (!rst_n) !en |=> !tick)
    else errors++;

endmodule