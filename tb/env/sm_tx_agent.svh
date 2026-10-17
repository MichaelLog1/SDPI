class sm_tx_agent;
    virtual sm_core_if vif;

    typedef enum logic [1:0] {
        STARVE,
        TRICKLE,
        SATURATE
    } stimulus_mode_t;

    // DEBUG
    bit override_flag = 0;
    stimulus_mode_t override_mode = STARVE;

    // randomized data
    rand stimulus_mode_t mode;
    rand int unsigned starve_length; // number of cycles to starve
    rand int unsigned trickle_gap; // gap between words pushed
    rand int unsigned trickle_num_words; // number of words to trickle
    rand int unsigned saturate_length; // number of words to saturate with

    rand logic [DATA_WIDTH-1:0] wr_stimulus;

    function new(virtual sm_core_if _vif);
        vif = _vif;
    endfunction

    task starve(int length);
        vif.driver_cb.tx_fifo_wr_en <= 1'b0;
        repeat (length) @(vif.driver_cb);
    endtask

    task trickle(int gap, int num_words);
        for (int i = 0; i < num_words; i++) begin
            if (vif.monitor_cb.tx_fifo_current_depth < ((FIFO_DEPTH - 2 > 1) ? (FIFO_DEPTH - 2) : 1)) begin
                assert(randomize(wr_stimulus));
                vif.driver_cb.tx_fifo_wr_data <= wr_stimulus;
                vif.driver_cb.tx_fifo_wr_en <= 1'b1;
                @(vif.driver_cb);
                vif.driver_cb.tx_fifo_wr_en <= 1'b0;
            end else begin
                @(vif.driver_cb); // ensure at least one cycle wait
            end
            repeat (gap) @(vif.driver_cb);
        end
    endtask

    task saturate(int length);
        for (int i = 0; i < length; i++) begin
            if (vif.monitor_cb.tx_fifo_current_depth < ((FIFO_DEPTH - 2 > 1) ? (FIFO_DEPTH - 2) : 1)) begin
                assert(randomize(wr_stimulus));
                vif.driver_cb.tx_fifo_wr_data <= wr_stimulus;
                vif.driver_cb.tx_fifo_wr_en <= 1'b1;
            end else begin
                vif.driver_cb.tx_fifo_wr_en <= 1'b0;
            end
            @(vif.driver_cb);
        end
        vif.driver_cb.tx_fifo_wr_en <= 1'b0;
        @(vif.driver_cb);
    endtask

    task run();
        vif.driver_cb.tx_fifo_wr_en <= 1'b0; // prevent X
        forever begin
            // randomize mode
            assert(randomize())
            else $fatal(1, "Failed to randomize");

            case (mode)
                STARVE: begin
                    starve(starve_length);
                end

                TRICKLE: begin
                    trickle(trickle_gap, trickle_num_words);
                end

                SATURATE: begin
                    saturate(saturate_length);
                end
            endcase
            @(vif.driver_cb); // need this so the sim wont hang
        end
    endtask

    // constraints
    constraint c_mode {
        if (!override_flag) {
            mode dist {
                STARVE :/ 33,
                TRICKLE :/ 33,
                SATURATE :/ 34
            };
        } else {
            mode == override_mode;
        }
    }

    constraint c_starve_length {
        starve_length inside {
            [10:40]
        };
    }

    constraint c_trickle_gap {
        trickle_gap inside {
            [0:10]
        };
    }

    constraint c_trickle_num_words {
        trickle_num_words inside {
            [1:10]
        };
    }

    constraint c_saturate_length {
        saturate_length inside {
            [20:100]
        };
    }

endclass
