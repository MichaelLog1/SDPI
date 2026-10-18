class sm_rx_agent;
    virtual sm_core_if vif;

    typedef enum logic [1:0] {
        CLOG,
        DRIP,
        DRAIN
    } stimulus_mode_t;

    // DEBUG
    bit override_flag = 0;
    stimulus_mode_t override_mode = CLOG;

    // randomized data
    rand stimulus_mode_t mode;
    rand int unsigned clog_length; // number of cycles to starve
    rand int unsigned drip_gap; // gap between words pushed
    rand int unsigned drip_num_words; // number of words to trickle
    rand int unsigned drain_length; // number of words to saturate with

    function new(virtual sm_core_if _vif);
        vif = _vif;
    endfunction

    task clog(int length);
        vif.driver_cb.rx_fifo_rd_en <= 1'b0;
        repeat (length) @(vif.driver_cb);
    endtask

    task drip(int gap, int num_words);
        for (int i = 0; i < num_words; i++) begin
            if (vif.monitor_cb.rx_fifo_current_depth > 1) begin
                vif.driver_cb.rx_fifo_rd_en <= 1'b1;
                @(vif.driver_cb);
                vif.driver_cb.rx_fifo_rd_en <= 1'b0;
            end else begin
                @(vif.driver_cb); // ensure at least one cycle wait
            end
            repeat (gap) @(vif.driver_cb);
        end
    endtask

    task drain(int length);
        for (int i = 0; i < length; i++) begin
            if (vif.monitor_cb.rx_fifo_current_depth > 1) begin
                vif.driver_cb.rx_fifo_rd_en <= 1'b1;
            end else begin
                vif.driver_cb.rx_fifo_rd_en <= 1'b0;
            end
            @(vif.driver_cb);
        end
        vif.driver_cb.rx_fifo_rd_en <= 1'b0;
        @(vif.driver_cb);
    endtask

    task run();
        vif.driver_cb.rx_fifo_rd_en <= 1'b0; // prevent X
        forever begin
            // randomize mode
            assert(randomize())
            else $fatal(1, "Failed to randomize");

            case (mode)
                CLOG: begin
                    clog(clog_length);
                end

                DRIP: begin
                    drip(drip_gap, drip_num_words);
                end

                DRAIN: begin
                    drain(drain_length);
                end
            endcase
            @(vif.driver_cb); // need this so the sim wont hang
        end
    endtask

    // constraints
    constraint c_mode {
        if (!override_flag) {
            mode dist {
                CLOG :/ 33,
                DRIP :/ 33,
                DRAIN :/ 34
            };
        } else {
            mode == override_mode;
        }
    }

    constraint c_clog_length {
        clog_length inside {
            [10:40]
        };
    }

    constraint c_drip_gap {
        drip_gap inside {
            [0:10]
        };
    }

    constraint c_drip_num_words {
        drip_num_words inside {
            [1:10]
        };
    }

    constraint c_drain_length {
        drain_length inside {
            [20:100]
        };
    }

endclass
