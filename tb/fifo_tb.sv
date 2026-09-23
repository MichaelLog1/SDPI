module fifo_tb #(
    parameter int unsigned FIFO_DEPTH = 4,
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned NUM_FRAMES = 10000
);
    // DUT signals
    logic clk = 0;
    logic rst_n;
    logic wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic full;
    logic empty;
    logic [$clog2(FIFO_DEPTH):0] current_depth;
    logic overflow;
    logic underflow;
    logic clear;

    // TB signals
    int cycle = 0;
    int passed = 0;
    int failed = 0;

    // typedefs
    typedef enum logic[2:0] {
        OP_NOP,
        OP_WRITE,
        OP_READ,
        OP_RW,
        OP_CLEAR,
        OP_RESET
    } op_t;

    typedef enum logic [3:0] {
        RESET,
        CLEAR,
        PUSH,
        POP,
        PUSH_POP,
        PUSH_ON_EMPTY,
        PUSH_ON_FULL,
        OVERFLOW,
        UNDERFLOW,
        IDLE,
        UNKNOWN
    } model_rule_t;

    typedef struct {
        logic [DATA_WIDTH-1:0] rd_data;
        logic full;
        logic empty;
        logic [$clog2(FIFO_DEPTH):0] current_depth;
        logic overflow;
        logic underflow;
    } outputs_t;

    fifo #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .full(full),
        .empty(empty),
        .current_depth(current_depth),
        .overflow(overflow),
        .underflow(underflow),
        .clear(clear)
    );

    class fifo_transaction;
        rand logic rst_n;
        rand logic wr_en;
        rand logic [DATA_WIDTH-1:0] wr_data;
        rand logic rd_en;
        rand logic clear;

        virtual function string to_string();
            return "";
        endfunction
    endclass

    class fifo_stim extends fifo_transaction;
        rand op_t operation;

        function string to_string();
            return "";
        endfunction

        // TODO: add constraints
        constraint c_reset {
            if (operation == OP_RESET)
                rst_n == 0;
            else
                rst_n == 1;
        }

        constraint c_nop {
            if (operation == OP_NOP) {
                wr_en == 0;
                rd_en == 0;
            }
        }

        constraint c_write {
            if (operation == OP_WRITE) {
                wr_en == 1;
                rd_en == 0;
            }
        }

        constraint c_read {
            if (operation == OP_READ) {
                wr_en == 0;
                rd_en == 1;
            }
        }

        constraint c_rw {
            if (operation == OP_RW) {
                wr_en == 1;
                rd_en == 1;
            }
        }

        constraint c_clear {
            if (operation == OP_CLEAR)
                clear == 1;
            else
                clear == 0;
        }

        constraint c_operation {
            operation dist {
                OP_RESET :/ 1,
                OP_NOP :/ 33,
                OP_WRITE :/ 20,
                OP_READ :/ 20,
                OP_RW :/ 25,
                OP_CLEAR :/ 2
            };
        }
    endclass

    class fifo_obs extends fifo_transaction;
        logic [DATA_WIDTH-1:0] rd_data;
        logic full;
        logic empty;
        logic [$clog2(FIFO_DEPTH):0] current_depth;
        logic overflow;
        logic underflow;
        int cycle;

        function string to_string();

        endfunction

        function void sample();
            rst_n = monitor_cb.rst_n;
            wr_en = monitor_cb.wr_en;
            wr_data = monitor_cb.wr_data;
            rd_en = monitor_cb.rd_en;
            rd_data = monitor_cb.rd_data;
            full = monitor_cb.full;
            empty = monitor_cb.empty;
            current_depth = monitor_cb.current_depth;
            overflow = monitor_cb.overflow;
            underflow = monitor_cb.underflow;
            clear = monitor_cb.clear;
            cycle = monitor_cb.cycle;
        endfunction
    endclass

    virtual class fifo_seq;
        pure virtual task body(mailbox #(fifo_stim) mb);
    endclass

    class rand_seq extends fifo_seq;
        task body(mailbox #(fifo_stim) mb);
            fifo_stim item;
            int burst_length = $urandom_range(5, 40);
            for (int i = 0; i < burst_length; i++) begin
                item = new();
                assert (item.randomize())
                else $fatal(1, "Failed to randomize.");
                mb.put(item);
            end
        endtask
    endclass

    class model;
        logic [DATA_WIDTH-1:0] queue [$];
        int valid = 0;

        logic model_overflow;
        logic model_underflow;


        function int is_valid();
            return valid;
        endfunction

        function void reset();
            valid = 1;
            model_overflow = 0;
            model_underflow = 0;
            queue.delete();
        endfunction

        function outputs_t predict(fifo_obs item);
            outputs_t outputs;

            outputs.rd_data = queue[$];
            outputs.full = (queue.size() == FIFO_DEPTH);
            outputs.empty = (queue.size() == 0);
            outputs.current_depth = queue.size();
            outputs.overflow = model_overflow;
            outputs.underflow = model_underflow;
            return outputs;
        endfunction

        function model_rule_t step(fifo_obs item);
            model_rule_t rule;
            logic [DATA_WIDTH-1:0] temp;

            if ($isunknown(item.rst_n) || 
                $isunknown(item.wr_en) || 
                $isunknown(item.wr_data) || 
                $isunknown(item.rd_en) ||
                $isunknown(item.clear)) begin

                return UNKNOWN;
            end

            if (!item.rst_n) begin
                rule = RESET;
                reset();
            end else if (item.clear) begin
                rule = CLEAR;
                reset();
            end else begin
                if (item.rd_en && item.wr_en) begin
                    if (queue.size() == 0) begin
                        rule = PUSH_ON_EMPTY;
                        model_underflow = 1;
                        queue.push_front(item.wr_data);
                    end else if (queue.size() == FIFO_DEPTH) begin
                        rule = PUSH_ON_FULL;
                        temp = queue.pop_back();
                        queue.push_front(item.wr_data);
                    end else begin
                        rule = PUSH_POP;
                        temp = queue.pop_back();
                        queue.push_front(item.wr_data);
                    end
                end else if (item.rd_en) begin
                    if (queue.size() == 0) begin
                        rule = UNDERFLOW;
                        model_underflow = 1;
                    end else begin
                        rule = POP;
                        temp = queue.pop_back();
                    end
                end else if (item.wr_en) begin
                    if (queue.size() == FIFO_DEPTH) begin
                        rule = OVERFLOW;
                        model_overflow = 1;
                    end else begin
                        rule = PUSH;
                        queue.push_front(item.wr_data);
                    end
                end else begin
                    rule = IDLE;
                end
            end

                return rule;
        endfunction
    endclass

    // tb control
    mailbox #(fifo_stim) driver_mailbox = new;
    mailbox #(fifo_obs) scoreboard_mailbox = new;
    event driver_done;

    initial begin : generate_clock
        forever #10 clk <= ~clk;
    end

    clocking driver_cb @(posedge clk);
        default output #0;
        output rst_n, wr_en, wr_data, rd_en, clear;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n, wr_en, wr_data, rd_en, rd_data, full, empty, current_depth, overflow, underflow, clear, cycle;
    endclocking

    initial begin : cycle_counter
        forever begin
            @(posedge clk);
            cycle <= cycle + 1;
        end
    end

    initial begin : generator
        fifo_seq seq;
        rand_seq r_seq;

        r_seq = new();

        for (int i = 0; i < NUM_FRAMES; i++) begin
            randcase
                100: seq = r_seq;
            endcase

            seq.body(driver_mailbox);
        end

        // sentinal value
        driver_mailbox.put(null);
    end

    initial begin : driver
        fifo_stim item;

        // reset
        driver_cb.rst_n <= 1'b0;
        driver_cb.wr_en <= 1'b0;
        driver_cb.wr_data <= '0;
        driver_cb.rd_en <= 1'b0;
        driver_cb.clear <= 1'b0;
        repeat (5) @(driver_cb);
        driver_cb.rst_n <= 1'b1;

        forever begin
            driver_mailbox.get(item);

            if (item == null) break;

            driver_cb.rst_n <= item.rst_n;
            driver_cb.wr_en <= item.wr_en;
            driver_cb.wr_data <= item.wr_data;
            driver_cb.rd_en <= item.rd_en;
            driver_cb.clear <= item.clear;
            @(driver_cb);
        end
        driver_cb.wr_en <= 1'b0;
        driver_cb.rd_en <= 1'b0;
        repeat (5) @(driver_cb);

        ->driver_done;
    end

    initial begin : monitor
        fifo_obs item;

        forever begin
            @(monitor_cb);
            item = new();
            item.sample();
            scoreboard_mailbox.put(item);
        end
    end

    initial begin : scoreboard
        fifo_obs item;
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
                    // model will return X for an empty queue
                    // these instances are meaningless and shouldnt be checked
                    if (!expected.empty) begin
                        if (item.rd_data === expected.rd_data) begin
                            passed++;
                        end else begin
                            failed++;
                            $display("Test failed (cycle %0d): Rule: %s, rd_data = %0x instead of %0x.\n", item.cycle, rule.name(), item.rd_data, expected.rd_data);
                            $display("%s", item.to_string());
                        end
                    end

                    if (item.full === expected.full) begin
                        passed++;
                    end else begin
                        failed++;
                        $display("Test failed (cycle %0d): Rule: %s, full = %0x instead of %0x.\n", item.cycle, rule.name(), item.full, expected.full);
                        $display("%s", item.to_string());
                    end
                    
                    if (item.empty === expected.empty) begin
                        passed++;
                    end else begin
                        failed++;
                        $display("Test failed (cycle %0d): Rule: %s, empty = %0x instead of %0x.\n", item.cycle, rule.name(), item.empty, expected.empty);
                        $display("%s", item.to_string());
                    end

                    if (item.current_depth === expected.current_depth) begin
                        passed++;
                    end else begin
                        failed++;
                        $display("Test failed (cycle %0d): Rule: %s, current_depth = %0x instead of %0x.\n", item.cycle, rule.name(), item.current_depth, expected.current_depth);
                        $display("%s", item.to_string());
                    end

                    if (item.overflow === expected.overflow) begin
                        passed++;
                    end else begin
                        failed++;
                        $display("Test failed (cycle %0d): Rule: %s, overflow = %0x instead of %0x.\n", item.cycle, rule.name(), item.overflow, expected.overflow);
                        $display("%s", item.to_string());
                    end

                    if (item.underflow === expected.underflow) begin
                        passed++;
                    end else begin
                        failed++;
                        $display("Test failed (cycle %0d): Rule: %s, underflow = %0x instead of %0x.\n", item.cycle, rule.name(), item.underflow, expected.underflow);
                        $display("%s", item.to_string());
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