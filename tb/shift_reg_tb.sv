`timescale 1 ns / 10 ps

module shift_reg_tb #(
    parameter int unsigned IS_INPUT = 0,
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned NUM_FRAMES = 10000
);
    // DUT signals
    logic clk = 0;
    logic rst_n;
    logic en;
    logic shift_dir;
    logic [$clog2(DATA_WIDTH):0] threshold;
    logic do_shift;
    logic [$clog2(DATA_WIDTH):0] shift_amt;
    logic [DATA_WIDTH-1:0] shift_data_in;
    logic [DATA_WIDTH-1:0] shift_data_out;
    logic do_load;
    logic [DATA_WIDTH-1:0] load_data;
    logic do_unload;
    logic [DATA_WIDTH-1:0] unload_data;
    logic [$clog2(DATA_WIDTH):0] count_out;
    logic threshold_reached;

    // tb signals
    int cycle = 0;
    int passed = 0;
    int failed = 0;

    shift_reg #(
        .IS_INPUT(IS_INPUT),
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .shift_dir(shift_dir),
        .threshold(threshold),
        .do_shift(do_shift),
        .shift_amt(shift_amt),
        .shift_data_in(shift_data_in),
        .shift_data_out(shift_data_out),
        .do_load(do_load),
        .load_data(load_data),
        .do_unload(do_unload),
        .unload_data(unload_data),
        .count_out(count_out),
        .threshold_reached(threshold_reached)
    );

    typedef enum logic [2:0] {
        OP_NOP,
        OP_LOAD,
        OP_UNLOAD,
        OP_SHIFT,
        OP_RESET
    } op_t;

    typedef enum logic [2:0] {
        RESET,
        LOAD,
        UNLOAD,
        SHIFT,
        HOLD,
        IDLE,
        UNKNOWN
    } model_rule_t;

    typedef struct {
            logic [DATA_WIDTH-1:0] shift_data_out;
            logic [DATA_WIDTH-1:0] unload_data;
            logic [$clog2(DATA_WIDTH):0] count_out;
            logic threshold_reached;
    } outputs_t;

    class shift_transaction;
        rand logic rst_n;
        rand logic en;
        rand logic shift_dir;
        rand logic [$clog2(DATA_WIDTH):0] threshold;
        rand logic do_shift;
        rand logic [$clog2(DATA_WIDTH):0] shift_amt;
        rand logic [DATA_WIDTH-1:0] shift_data_in;
        rand logic do_load;
        rand logic [DATA_WIDTH-1:0] load_data;
        rand logic do_unload;

        virtual function string to_string();
            return $sformatf("Transaction values:\nrst_n: %d\nen: %d\nshift_dir: %d\nthreshold: %d\ndo_shift: %d\nshift_amt: %d\nshift_data_in: %d\ndo_load: %d\nload_data: %d\ndo_unload: %d\n",
                      rst_n,
                      en,
                      shift_dir,
                      threshold,
                      do_shift,
                      shift_amt,
                      shift_data_in,
                      do_load,
                      load_data,
                      do_unload);
        endfunction
    endclass

    class shift_stim extends shift_transaction;
        rand op_t operation;

        function string to_string();
            return $sformatf("%soperation: %d\n", super.to_string(), operation);
        endfunction

        // TODO: stimulus constraints
        constraint c_reset {
            if (operation == OP_RESET)
                rst_n == 0;
            else
                rst_n == 1;
        }

        constraint c_shift {
            if (operation == OP_SHIFT)
                do_shift == 1;
            else
                do_shift == 0;
        }

        constraint c_load {
            if (operation == OP_LOAD)
                do_load == 1;
            else
                do_load == 0;
        }

        constraint c_unload {
            if (operation == OP_UNLOAD)
                do_unload == 1;
            else
                do_unload == 0;
        }

        constraint c_shift_amt {
            shift_amt <= DATA_WIDTH;
        }

        constraint c_threshold {
            threshold <= DATA_WIDTH;
        }

        constraint c_operation {
            operation dist {
                OP_NOP :/ 29,
                OP_LOAD :/ 10,
                OP_UNLOAD :/ 10,
                OP_SHIFT :/ 50,
                OP_RESET :/ 1
            };
        }

        constraint c_en {
            en dist {
                0 :/ 20,
                1 :/ 80
            };
        }
    endclass

    class shift_obs extends shift_transaction;
        logic [DATA_WIDTH-1:0] shift_data_out;
        logic [DATA_WIDTH-1:0] unload_data;
        logic [$clog2(DATA_WIDTH):0] count_out;
        logic threshold_reached;
        int cycle;

        function string to_string();
            return $sformatf("%sshift_data_out: %d\nunload_data: %d\ncount_out %d\nthreshold_reached: %d\ncycle: %d\n", super.to_string(), shift_data_out, unload_data, count_out, threshold_reached, cycle);
        endfunction

        function void sample();
            rst_n = monitor_cb.rst_n;
            en = monitor_cb.en;
            shift_dir = monitor_cb.shift_dir;
            threshold = monitor_cb.threshold;
            do_shift = monitor_cb.do_shift;
            shift_amt = monitor_cb.shift_amt;
            shift_data_in = monitor_cb.shift_data_in;
            do_load = monitor_cb.do_load;
            load_data = monitor_cb.load_data;
            do_unload = monitor_cb.do_unload;
            shift_data_out = monitor_cb.shift_data_out;
            unload_data = monitor_cb.unload_data;
            count_out = monitor_cb.count_out;
            threshold_reached = monitor_cb.threshold_reached;
            cycle = monitor_cb.cycle;
        endfunction
    endclass

    virtual class shift_seq;
        pure virtual task body(mailbox #(shift_stim) mb);
    endclass

    class rand_seq extends shift_seq;

        task body(mailbox #(shift_stim) mb);
            shift_stim item;
            int burst_length = $urandom_range(5, 40);
            for (int i = 0; i < burst_length; i++) begin
                item = new();
                assert(item.randomize())
                else $fatal(1, "Failed to randomize.");
                mb.put(item);
            end
        endtask
    endclass

    class full_frame_seq extends shift_seq;
        int stall_probability = 0;
        int max_stall_length = 0;

        task body(mailbox #(shift_stim) mb);
            shift_stim item;
            int eff;
            int n_shifts;
            int stall_cycles;

            logic [$clog2(DATA_WIDTH):0] thresh;
            logic dir;
            logic [$clog2(DATA_WIDTH):0] amt;

            // generate config
            assert(std::randomize(dir))
            else $fatal(1, "Failed to randomize.");
            assert(std::randomize(thresh) with {
                thresh dist {
                    0 :/ 20,
                    1 :/ 20,
                    [2:DATA_WIDTH-1] :/ 30,
                    DATA_WIDTH :/ 30
                };
            })
            else $fatal(1, "Failed to randomize.");

            eff = (thresh == 0) ? DATA_WIDTH : thresh;

            assert(std::randomize(amt) with {
                eff % amt == 0;
                amt inside {
                    [1:DATA_WIDTH]
                };
            })
            else $fatal(1, "Failed to randomize.");

            n_shifts = eff / amt;
            
            // need one load item to load a word
            item = new();
            assert(item.randomize() with {
                operation == OP_LOAD;
                shift_dir == dir;
                threshold == thresh;
                en == 1;
            })
            else $fatal(1, "Failed to randomize.");
            mb.put(item);

            // stall
            if ($urandom_range(99) < stall_probability) begin
                stall_cycles = $urandom_range(max_stall_length, 1);
                for (int j = 0; j < stall_cycles; j++) begin
                    item = new();
                    assert(item.randomize() with {
                        operation == OP_SHIFT;
                        shift_dir == dir;
                        threshold == thresh;
                        shift_amt == amt;
                        en == 0;
                    })
                    else $fatal(1, "Failed to randomize.");
                    mb.put(item);
                end
            end
 
            // shift in
            for (int i = 0; i < n_shifts; i++) begin
                item = new();
                assert(item.randomize() with {
                    operation == OP_SHIFT;
                    shift_dir == dir;
                    threshold == thresh;
                    shift_amt == amt;
                    en == 1;
                })
                else $fatal(1, "Failed to randomize.");
                mb.put(item);

                // stall
                if ($urandom_range(99) < stall_probability) begin
                    stall_cycles = $urandom_range(max_stall_length, 1);
                    for (int j = 0; j < stall_cycles; j++) begin
                        item = new();
                        assert(item.randomize() with {
                            operation == OP_SHIFT;
                            shift_dir == dir;
                            threshold == thresh;
                            shift_amt == amt;
                            en == 0;
                        })
                        else $fatal(1, "Failed to randomize.");
                        mb.put(item);
                    end
                end
            end

            // stall
            if ($urandom_range(99) < stall_probability) begin
                stall_cycles = $urandom_range(max_stall_length, 1);
                for (int j = 0; j < stall_cycles; j++) begin
                    item = new();
                    assert(item.randomize() with {
                        operation == OP_SHIFT;
                        shift_dir == dir;
                        threshold == thresh;
                        shift_amt == amt;
                        en == 0;
                    })
                    else $fatal(1, "Failed to randomize.");
                    mb.put(item);
                end
            end

            // unload
            item = new();
            assert(item.randomize() with {
                operation == OP_UNLOAD;
                shift_dir == dir;
                threshold == thresh;
                shift_amt == amt;
                en == 1;
            })
            else $fatal(1, "Failed to randomize.");
            mb.put(item);
        endtask
    endclass

    class stall_seq extends full_frame_seq;
        function new();
            stall_probability = 30;
            max_stall_length = 6;
        endfunction
    endclass

    class model;
        logic shift_r [DATA_WIDTH];
        int count;
        int valid = 0;

        function int is_valid();
            return valid;
        endfunction

        function void reset();
            valid = 1;
            foreach (shift_r[i]) shift_r[i] = 0;
            if (IS_INPUT) begin
                count = 0;
            end else begin
                count = DATA_WIDTH;
            end
        endfunction

        function outputs_t predict(shift_obs item);
            outputs_t outputs;
            logic [DATA_WIDTH-1:0] shift_out;
            shift_out = '0;
            if (item.shift_dir) begin
                for (int i = 0; i < item.shift_amt; i++) begin
                    shift_out[i] = shift_r[DATA_WIDTH-item.shift_amt+i];
                end
            end else begin
                for (int i = 0; i < item.shift_amt; i++) begin
                    shift_out[i] = shift_r[i];
                end
            end

            outputs.shift_data_out = shift_out;
            foreach (shift_r[i]) outputs.unload_data[i] = shift_r[i];
            outputs.count_out = count;
            outputs.threshold_reached = item.threshold ? (count >= item.threshold) : count >= DATA_WIDTH;
            return outputs;
        endfunction

        function model_rule_t step(shift_obs item);
            model_rule_t rule;

            if ($isunknown(item.rst_n) || 
                $isunknown(item.en) || 
                $isunknown(item.shift_dir) || 
                $isunknown(item.threshold) || 
                $isunknown(item.do_shift) ||
                $isunknown(item.shift_amt) || 
                $isunknown(item.shift_data_in) ||
                $isunknown(item.do_load) ||
                $isunknown(item.load_data) ||
                $isunknown(item.do_unload)) begin

                return UNKNOWN;
            end

            if (!item.rst_n) begin
                rule = RESET;
                reset();
            end else begin
                if (item.en) begin
                    if (item.do_unload) begin
                        rule = UNLOAD;
                        foreach (shift_r[i]) shift_r[i] = 0;
                        count = 0;
                    end else if (item.do_load) begin
                        rule = LOAD;
                        foreach (shift_r[i]) shift_r[i] = item.load_data[i];
                        count = 0;
                    end else if (item.do_shift) begin
                        rule = SHIFT;
                        if (item.shift_dir) begin
                            logic temp_shift [DATA_WIDTH] = shift_r;

                            for (int i = 0; i < DATA_WIDTH - item.shift_amt; i++) begin
                                shift_r[i+item.shift_amt] = temp_shift[i];
                            end

                            for (int i = 0; i < item.shift_amt; i++) begin
                                shift_r[i] = item.shift_data_in[i];
                            end
                        end else begin
                            for (int i = 0; i < DATA_WIDTH - item.shift_amt; i++) begin
                                shift_r[i] = shift_r[i+item.shift_amt];
                            end

                            for (int i = 0; i < item.shift_amt; i++) begin
                                shift_r
                                [DATA_WIDTH-item.shift_amt+i] = item.shift_data_in[i];
                            end
                        end
                        if (count + item.shift_amt > DATA_WIDTH) count = DATA_WIDTH;
                        else count += item.shift_amt;
                    end else begin
                        rule = IDLE;
                    end
                end else begin
                    rule = HOLD;
                end
            end
            return rule;
        endfunction
    endclass
    
    mailbox #(shift_stim) driver_mailbox = new;
    mailbox #(shift_obs) scoreboard_mailbox = new;
    event driver_done;

    initial begin : generate_clock
        forever #10 clk <= ~clk;
    end

    clocking driver_cb @(posedge clk);
        default output #0;
        output rst_n, en, shift_dir, threshold, do_shift, shift_amt, shift_data_in, do_load, load_data, do_unload;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n, en, shift_dir, threshold, do_shift, shift_amt, shift_data_in, do_load, load_data, do_unload, shift_data_out, unload_data, count_out, threshold_reached, cycle;
    endclocking

    initial begin : cycle_counter
        forever begin
            @(posedge clk);
            cycle <= cycle + 1;
        end
    end

    initial begin : generator
        shift_seq seq;
        rand_seq r_seq;
        full_frame_seq f_seq;
        stall_seq s_seq;

        r_seq = new();
        f_seq = new();
        s_seq = new();

        for (int i = 0; i < NUM_FRAMES; i++) begin
            randcase
                30 : seq = r_seq;
                40 : seq = f_seq;
                30 : seq = s_seq;
            endcase
            seq.body(driver_mailbox);
        end
        
        // insert sentinal value
        driver_mailbox.put(null);
    end

    initial begin : driver
        shift_stim item;

        // reset
        driver_cb.rst_n <= 1'b0;
        driver_cb.en <= 1'b0;
        driver_cb.shift_dir <= 1'b0;
        driver_cb.threshold <= '0;
        driver_cb.do_shift <= 1'b0;
        driver_cb.shift_amt <= '0;
        driver_cb.shift_data_in <= '0;
        driver_cb.do_load <= 1'b0;
        driver_cb.load_data <= '0;
        driver_cb.do_unload <= 1'b0;
        repeat (5) @(driver_cb);
        driver_cb.rst_n <= 1'b1;

        forever begin
            driver_mailbox.get(item);

            // sentinal value check
            if (item == null) begin
                break;
            end

            driver_cb.rst_n <= item.rst_n;
            driver_cb.en <= item.en;
            driver_cb.shift_dir <= item.shift_dir;
            driver_cb.threshold <= item.threshold;
            driver_cb.do_shift <= item.do_shift;
            driver_cb.shift_amt <= item.shift_amt;
            driver_cb.shift_data_in <= item.shift_data_in;
            driver_cb.do_load <= item.do_load;
            driver_cb.load_data <= item.load_data;
            driver_cb.do_unload <= item.do_unload;
            @(driver_cb);
        end
        driver_cb.do_shift <= 1'b0;
        driver_cb.do_load <= 1'b0;
        driver_cb.do_unload <= 1'b0;
        repeat (5) @(driver_cb);
        ->driver_done;

    end

    initial begin : monitor
        shift_obs item;

        forever begin
            @(monitor_cb);
            item = new();
            item.sample();
            scoreboard_mailbox.put(item);
        end
    end

    initial begin : scoreboard
        shift_obs item;
        model model;
        outputs_t expected;
        model_rule_t rule;
        int valid;

        model = new;

        forever begin
            valid = model.is_valid();

            scoreboard_mailbox.get(item);
            expected = model.predict(item);
            rule = model.step(item);
            
            if (valid) begin
                if (rule == UNKNOWN) begin
                    $display("Test failed (time %0t): model prediction is valid but model decision is unknown.\n", $time);
                    failed++;
                end else begin
                    if (item.shift_data_out === expected.shift_data_out) begin
                        passed++;
                    end else begin
                        $display("Test failed (cycle %0d): Rule: %s, shift_data_out = %0x instead of %0x.\n", item.cycle, rule.name(), item.shift_data_out, expected.shift_data_out);
                        $display("%s", item.to_string());
                        failed++;
                    end

                    if (item.unload_data === expected.unload_data) begin
                        passed++;
                    end else begin
                        $display("Test failed (cycle %0d): Rule: %s, unload_data = %0x instead of %0x.\n", item.cycle, rule.name(), item.unload_data, expected.unload_data);
                        $display("%s", item.to_string());
                        failed++;
                    end

                    if (item.count_out === expected.count_out) begin
                        passed++;
                    end else begin
                        $display("Test failed (cycle %0d): Rule: %s, count_out = %0x instead of %0x.\n", item.cycle, rule.name(), item.count_out, expected.count_out);
                        $display("%s", item.to_string());
                        failed++;
                    end

                    if (item.threshold_reached === expected.threshold_reached) begin
                        passed++;
                    end else begin
                        $display("Test failed (cycle %0d): Rule: %s, threshold_reached = %0x instead of %0x.\n", item.cycle, rule.name(), item.threshold_reached, expected.threshold_reached);
                        $display("%s", item.to_string());
                        failed++;
                    end
                end 
            end
        end
    end

    initial begin : reporting
        @(driver_done);
        do @(posedge clk); while (scoreboard_mailbox.num() != 0);
        repeat (5) @(posedge clk);
        $display("Tests completed: %0d passed, %0d failed", passed, failed);
        if (failed > 0) $fatal(1, "Fail.");
        else if (failed == 0 && passed == 0) $fatal(1, "No checks performed.");
        else $finish("Pass.");

    end
endmodule
