`timescale 1 ns / 10 ps

module sm_pc_tb #(
    parameter int unsigned SM_WINDOW = 32,
    parameter int unsigned IMEM_DEPTH = 64,
    parameter int unsigned NUM_TESTS = 1000,
    parameter int unsigned MIN_CYCLES_BETWEEN_TESTS = 1,
    parameter int unsigned MAX_CYCLES_BETWEEN_TESTS = 10

);

    logic clk = 0;
    logic rst_n;
    logic restart;
    logic advance;
    logic load_req;
    logic [$clog2(SM_WINDOW)-1:0] load_data;
    logic [$clog2(IMEM_DEPTH)-1:0] pc_base;
    logic [$clog2(SM_WINDOW)-1:0] wrap_top;
    logic [$clog2(SM_WINDOW)-1:0] wrap_bottom;
    logic [$clog2(IMEM_DEPTH)-1:0] pc_absolute;
    logic [$clog2(SM_WINDOW)-1:0] pc_local;

    sm_pc #(
        .SM_WINDOW(SM_WINDOW),
        .IMEM_DEPTH(IMEM_DEPTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .restart(restart),
        .advance(advance),
        .load_req(load_req),
        .load_data(load_data),
        .pc_base(pc_base),
        .wrap_top(wrap_top),
        .wrap_bottom(wrap_bottom),
        .pc_absolute(pc_absolute),
        .pc_local(pc_local)
    );

    typedef enum bit [2:0] {
        UNKNOWN,
        RESET,
        RESTART,
        LOAD,
        WRAP,
        INCREMENT,
        STAY
    } model_t;

    class sm_pc_item;
        logic rst_n;
        rand logic restart;
        rand logic advance;
        rand logic load_req;
        rand logic [$clog2(SM_WINDOW)-1:0] load_data;
        rand logic [$clog2(IMEM_DEPTH)-1:0] pc_base;
        rand logic [$clog2(SM_WINDOW)-1:0] wrap_top;
        rand logic [$clog2(SM_WINDOW)-1:0] wrap_bottom;
        logic [$clog2(IMEM_DEPTH)-1:0] pc_absolute;
        logic [$clog2(SM_WINDOW)-1:0] pc_local;

        constraint c_restart_dist {
            restart dist {
                0 :/ 98,
                1 :/ 2
            };
        }

        constraint c_advance_dist {
            advance dist {
                0 :/ 20,
                1 :/ 80
            };
        }

        constraint c_load_req_dist {
            load_req dist {
                0 :/ 97,
                1 :/ 3
            };
        }

        constraint c_load_data_dist {
            load_data dist { 
                0 :/ 10,
                1 :/ 10,
                [2:16] :/ 30,
                [17:31] :/ 50
            };
        }
    endclass

    class Model;
        logic [$clog2(SM_WINDOW)-1:0] model_pc_local;
        logic prediction_valid = 0;

        function logic [$clog2(SM_WINDOW)-1:0] get_local();
            return model_pc_local;
        endfunction

        function logic get_valid();
            return prediction_valid;
        endfunction

        function model_t step(sm_pc_item item);
            model_t rule;
            if ($isunknown(item.rst_n) || 
                $isunknown(item.restart) || 
                $isunknown(item.advance) || 
                $isunknown(item.load_req) || 
                $isunknown(item.load_data) ||
                $isunknown(item.wrap_top) || 
                $isunknown(item.wrap_bottom)) begin

                return UNKNOWN;
            end
            
            if (!item.rst_n) begin
                model_pc_local = '0;
                prediction_valid = 1;
                rule = RESET;

            end else begin
                if (item.restart) begin
                    model_pc_local = '0;
                    rule = RESTART;
                end else if (item.advance) begin
                    if (item.load_req) begin
                        model_pc_local = item.load_data;
                        rule =  LOAD;
                    end else begin
                        if (model_pc_local == item.wrap_top) begin
                            model_pc_local = item.wrap_bottom;
                            rule = WRAP;
                        end else begin
                            model_pc_local = model_pc_local + ($clog2(SM_WINDOW))'(1);
                            rule = INCREMENT;
                        end
                    end
                end else begin
                    rule = STAY;
                end
            end

            return rule;
        endfunction
    endclass

    class coverage_monitor;
        // member vars
        logic [$clog2(IMEM_DEPTH)-1:0] prev_pc_base;
        logic [$clog2(SM_WINDOW)-1:0] prev_wrap_top;
        logic [$clog2(SM_WINDOW)-1:0] prev_wrap_bottom;
        int wrap_increments;
        int redirect_increments;
        logic have_previous_item;
        logic loop_clean;


        covergroup rule_cg with function sample(model_t rule);
            rule : coverpoint rule {
                bins legal_rules[] = {RESET, RESTART, LOAD, WRAP, INCREMENT, STAY};
                illegal_bins illegal_rules = {UNKNOWN};
            }
        endgroup

        covergroup priorities_cg with function sample(sm_pc_item item, logic [$clog2(SM_WINDOW)-1:0] prev_pc_local);
            res : coverpoint item.restart {
                option.weight = 0;
                bins true = {1};
                bins false = {0};
            }

            adv : coverpoint item.advance {
                option.weight = 0;
                bins true = {1};
                bins false = {0};
            }

            lreq : coverpoint item.load_req {
                option.weight = 0;
                bins true = {1};
                bins false = {0};
            }

            pc_wrap : coverpoint (item.wrap_top == prev_pc_local) {
                option.weight = 0;
                bins true = {1};
                bins false = {0};
            }

            all : cross res, adv, lreq, pc_wrap iff (item.rst_n);
        endgroup

        covergroup wrap_cg with function sample(sm_pc_item item, logic [$clog2(SM_WINDOW)-1:0] prev_pc_local, model_t rule);
            top_gt_bottom : coverpoint (item.wrap_top > item.wrap_bottom) iff (rule == WRAP) {
                bins true = {1};
            }

            top_eq_bottom : coverpoint (item.wrap_top == item.wrap_bottom) iff (rule == WRAP) {
                bins true = {1};
            }

            top_lt_bottom : coverpoint (item.wrap_top < item.wrap_bottom) iff (rule == WRAP) {
                bins true = {1};
            }

            top_edge : coverpoint item.wrap_top iff (rule == WRAP) {
                option.weight = 0;
                bins max = {SM_WINDOW-1};
                bins min = {0};
                bins between = {[1:SM_WINDOW-2]};
            }

            bottom_edge : coverpoint item.wrap_bottom iff (rule == WRAP) {
                option.weight = 0;
                bins max = {SM_WINDOW-1};
                bins min = {0};
                bins between = {[1:SM_WINDOW-2]};
            }

            edges : cross top_edge, bottom_edge iff (rule == WRAP);

            //increment_from : coverpoint 
        endgroup

        covergroup load_cg with function sample(sm_pc_item item, logic [$clog2(SM_WINDOW)-1:0] prev_pc_local, model_t rule);
            load_extreme : coverpoint item.load_data iff (rule == LOAD) {
                bins zero = {0};
                bins max = {SM_WINDOW-1};
            }

            load_top : coverpoint (item.load_data == item.wrap_top) iff (rule == LOAD) {
                bins true = {1};
            }
            
            load_bottom : coverpoint (item.load_data == item.wrap_bottom) iff (rule == LOAD) {
                bins true = {1};
            }

            load_self : coverpoint (item.load_data == prev_pc_local) iff (rule == LOAD) {
                bins true = {1};
            }

            load_backward : coverpoint (item.load_data < prev_pc_local) iff (rule == LOAD) {
                bins true = {1};
            }

            load_forward : coverpoint (item.load_data > prev_pc_local) iff (rule == LOAD) {
                bins true = {1};
            }
        endgroup

        covergroup absolute_cg with function sample(sm_pc_item data_item, sm_pc_item result_item);
            base_value : coverpoint (result_item.pc_base) {
                bins zero = {0};
                bins window_end = {IMEM_DEPTH - SM_WINDOW};
                bins max = {IMEM_DEPTH - 1};
                bins other = {[1:(IMEM_DEPTH-SM_WINDOW-1)]};
            }

            base_region : coverpoint (result_item.pc_base) {
                bins fits = {[0:(IMEM_DEPTH-SM_WINDOW)]};
                bins straddle = {[(IMEM_DEPTH-SM_WINDOW+1):(IMEM_DEPTH-1)]};
            }

            sum : coverpoint (int'(result_item.pc_base) + result_item.pc_local) {
                bins no_wrap = {[0:(IMEM_DEPTH-1)]};
                bins wrap = {[IMEM_DEPTH:(IMEM_DEPTH+SM_WINDOW-2)]};
                bins at_last = {IMEM_DEPTH-1};
                bins at_first_wrapped = {IMEM_DEPTH};
            }

            base_changed : coverpoint (result_item.pc_base != prev_pc_base) iff (data_item.rst_n && have_previous_item) {
                bins true = {1};
            }
        endgroup

        //TODO: FINISH COVERGROUPS
        covergroup sequence_cg with function sample();

        endgroup

        function new();
            rule_cg = new();
            priorities_cg = new();
            wrap_cg = new();
            load_cg = new();
            absolute_cg = new();
            
            prev_pc_base = 0;
            prev_wrap_top = 0;
            prev_wrap_bottom = 0;
            wrap_increments = 0;
            redirect_increments = 0;
            have_previous_item = 0;
            loop_clean = 0;
        endfunction

        function void sample_transaction(sm_pc_item data_item, sm_pc_item result_item, logic [$clog2(SM_WINDOW)-1:0] prev_pc_local, model_t rule);
            rule_cg.sample(rule);
            if (rule != UNKNOWN) begin
                priorities_cg.sample(data_item, prev_pc_local);
                wrap_cg.sample(data_item, prev_pc_local, rule);
                load_cg.sample(data_item, prev_pc_local, rule);
                absolute_cg.sample(data_item, result_item);

                // update member vars
                if (rule == INCREMENT) begin
                    wrap_increments++;
                end else if (rule != STAY) begin
                    wrap_increments = 0;
                end


                prev_pc_base = result_item.pc_base;
                prev_wrap_top = data_item.wrap_top;
                prev_wrap_bottom = data_item.wrap_bottom;
                have_previous_item = 1;

            end else begin
                have_previous_item = 0;
                loop_clean = 0;
                wrap_increments = 0;
                redirect_increments = 0;
            end
        endfunction
    endclass

    mailbox driver_mailbox = new;
    mailbox scoreboard_data_mailbox = new;
    mailbox scoreboard_result_mailbox = new;

    event driver_done;

    int passed = 0;
    int failed = 0;

    Model model;
    coverage_monitor cm;
    
    initial begin : generate_clock
        forever #10 clk <= ~clk;
    end

    task automatic reset(int cycles);
        rst_n <= 1'b0;
        repeat (cycles) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;
    endtask

    initial begin : initialization
        rst_n <= 1'b0;
        restart <= 1'b0;
        advance <= 1'b0;
        load_req <= 1'b0;
        load_data <= '0;
        pc_base <= '0;
        wrap_top <= '0;
        wrap_bottom <= '0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;
    end

    initial begin : generator
        sm_pc_item item;
        @(posedge rst_n);
        for (int i = 0; i < NUM_TESTS; i++) begin
            item = new();
            assert (item.randomize())
            else $fatal(1, "Failed to randomize.");

            driver_mailbox.put(item);
        end
    end

    initial begin : monitor
        sm_pc_item data_item;
        sm_pc_item result_item;
        forever begin
            data_item = new();
            data_item.rst_n = rst_n;
            data_item.restart = restart;
            data_item.advance = advance;
            data_item.load_req = load_req;
            data_item.load_data = load_data;
            data_item.pc_base = pc_base;
            data_item.wrap_top = wrap_top;
            data_item.wrap_bottom = wrap_bottom;
            scoreboard_data_mailbox.put(data_item);
            @(posedge clk);
            result_item = new();
            result_item.pc_local = pc_local;
            result_item.pc_absolute = pc_absolute;
            result_item.pc_base = pc_base;
            scoreboard_result_mailbox.put(result_item);      
        end
    end

    initial begin : driver
        sm_pc_item item;
        @(posedge rst_n);
        for (int i = 0; i < NUM_TESTS; i++) begin
            driver_mailbox.get(item);
            restart <= item.restart;
            advance <= item.advance;
            load_req <= item.load_req;
            load_data <= item.load_data;
            pc_base <= item.pc_base;
            wrap_top <= item.wrap_top;
            wrap_bottom <= item.wrap_bottom;
            @(posedge clk);

            repeat ($urandom_range(MIN_CYCLES_BETWEEN_TESTS-1, MAX_CYCLES_BETWEEN_TESTS-1)) @(posedge clk);
        end
        ->driver_done;
    end

    initial begin : scoreboard
        sm_pc_item data_item;
        sm_pc_item result_item;
        logic [$clog2(IMEM_DEPTH)-1:0] expected_pc_absolute;
        logic [$clog2(SM_WINDOW)-1:0] expected_pc_local;
        logic [$clog2(SM_WINDOW)-1:0] prev_pc_local;
        logic prediction_valid;
        model_t rule;
        model = new;
        cm = new;

        forever begin
            // update model
            scoreboard_data_mailbox.get(data_item);
            prev_pc_local = model.get_local();
            rule = model.step(data_item);
            
            scoreboard_result_mailbox.get(result_item);
            expected_pc_absolute = result_item.pc_local + result_item.pc_base;
            expected_pc_local = model.get_local();
            prediction_valid = model.get_valid();

            if (prediction_valid) cm.sample_transaction(data_item, result_item, prev_pc_local, rule);

            if (prediction_valid === 1) begin
                if (rule == UNKNOWN) begin
                    $display("Test failed (time %0t): model prediction is valid but model decision is unknown.\n", $time);
                    failed++;
                end else begin
                    if (result_item.pc_local === expected_pc_local) begin
                        passed++;
                    end else begin
                        $display("Test failed (time %0t): pc_local = %0d instead of %0d.\n Inputs shown below:\n", $time, result_item.pc_local, expected_pc_local);
                        $display("rst_n: %d\n restart: %d\n advance: %d\n load_req: %d\n load_data: %d\n pc_base: %d\n wrap_top: %d\n wrap_bottom: %d\n", data_item.rst_n, data_item.restart, data_item.advance, data_item.load_req, data_item.load_data, data_item.pc_base, data_item.wrap_top, data_item.wrap_bottom);
                        failed++;
                    end

                    if (result_item.pc_absolute === expected_pc_absolute) begin
                        passed++;
                    end else begin
                        $display("Test failed (time %0t): pc_absolute = %0d instead of %0d.\n Inputs shown below:\n", $time, result_item.pc_absolute, expected_pc_absolute);
                        $display("rst_n: %d\n restart: %d\n advance: %d\n load_req: %d\n load_data: %d\n pc_base: %d\n wrap_top: %d\n wrap_bottom: %d\n", data_item.rst_n, data_item.restart, data_item.advance, data_item.load_req, data_item.load_data, data_item.pc_base, data_item.wrap_top, data_item.wrap_bottom);
                        failed++;
                    end
                end
            end
        end
    end

    initial begin : reporting
        @(driver_done);
        repeat (1) @(posedge clk);
        $display("Tests completed: %0d passed, %0d failed", passed, failed);
        if (failed > 0) $fatal(1, "Fail.");
        else if (failed == 0 && passed == 0) $fatal(1, "No checks performed.");
        else $finish("Pass.");

    end
endmodule