class sm_scoreboard;
    int passed = 0;
    int failed = 0;
    int stalled = 0;
    int retired[IMEM_DEPTH];
    int fetched[IMEM_DEPTH];
    logic [INSTRUCTION_WIDTH-1:0] frame_words[IMEM_DEPTH];
    // fifo flags for reporting (somethings wrong if these are set)
    // could be agent implementation or DUT
    int rx_underflow = 0;
    int rx_overflow = 0;
    int tx_underflow = 0;
    int tx_overflow = 0;
    
    sm_iss model;
    mailbox #(sm_obs) scoreboard_mailbox;

    function new(mailbox #(sm_obs) mb);
        scoreboard_mailbox = mb;
        model = new();
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            retired[i] = 0;
            fetched[i] = 0;
            frame_words[i] = '0;
        end
    endfunction

    function void print(logic [$clog2(6)-1:0] frame_sideset_count, logic frame_sideset_opt);
        $display("%4s %7s %7s %30s", "ADDR", "FETCHED", "RETIRED", "INSTRUCTION");
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            if (fetched[i] > 0) begin
                if (retired[i] == 0) begin
                    stalled = 1; // an instruction isnt retiring for some reason.
                                 // this could be a tb issue (tx agent somehow causing
                                 // pull to stall) or a dut issue
                end
                $display("%4d %7d %7d %30s", i, fetched[i], retired[i], disassemble(frame_words[i], frame_sideset_count, frame_sideset_opt));
            end
        end
    endfunction

    task run();
        sm_obs item;
        sm_iss::sm_model_predictions_t prediction;
        bit valid;
        logic advance;
        logic prev_en = 1;

        logic [$clog2(6)-1:0] frame_sideset_count;
        logic frame_sideset_opt;

        forever begin
            valid = model.is_valid();
            scoreboard_mailbox.get(item);
            prediction = model.predict(item);
            advance = model.get_advance(item);
            model.step(item);

            if (!prev_en && item.en) begin
                // we can latch any important info here
                frame_sideset_count = item.sideset_count;
                frame_sideset_opt = item.sideset_opt;
            end

            if (valid) begin
                // check all outputs
                if (item.pc_absolute === prediction.pc_absolute) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): pc_absolute = %0x instead of %0x.\n", item.cycle, item.pc_absolute, prediction.pc_absolute);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.uio_out === prediction.uio_out) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): uio_out = %0x instead of %0x.\n", item.cycle, item.uio_out, prediction.uio_out);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.uio_oe === prediction.uio_oe) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): uio_oe = %0x instead of %0x.\n", item.cycle, item.uio_oe, prediction.uio_oe);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.tx_en === prediction.tx_en) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): tx_en = %0x instead of %0x.\n", item.cycle, item.tx_en, prediction.tx_en);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.rx_en === prediction.rx_en) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): rx_en = %0x instead of %0x.\n", item.cycle, item.rx_en, prediction.rx_en);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.rx_data === prediction.rx_data) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): rx_data = %0x instead of %0x.\n", item.cycle, item.rx_data, prediction.rx_data);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.irq_set === prediction.irq_set) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): irq_set = %0x instead of %0x.\n", item.cycle, item.irq_set, prediction.irq_set);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                if (item.irq_clear === prediction.irq_clear) begin
                    passed++;
                end else begin
                    $display("Test failed (cycle %0d): irq_clear = %0x instead of %0x.\n", item.cycle, item.irq_clear, prediction.irq_clear);
                    $display("%s", item.to_string_short());
                    failed++;
                end

                // update instruction retirement data structure
                if (item.rst_n) begin
                    if (advance && item.en) begin
                        retired[item.pc_absolute]++;
                    end
                    if (item.en) begin
                        fetched[item.pc_absolute]++;
                        frame_words[item.pc_absolute] = item.instruction;
                    end        
                end

                // set ovf/unf flags
                if (item.rx_fifo_underflow) begin
                    rx_underflow = 1;
                    $error("rx_underflow");
                end
                
                if (item.rx_fifo_overflow) begin
                    rx_overflow = 1;
                    $error("rx_overflow");
                end

                if (item.tx_fifo_underflow) begin
                     tx_underflow = 1;
                     $error("tx_underflow");
                end

                if (item.tx_fifo_overflow) begin
                    tx_overflow = 1;
                    $error("tx_overflow");
                end
            end

            // frame end detector
            if (prev_en && !item.en) begin
                print(frame_sideset_count, frame_sideset_opt);
                for (int i = 0; i < IMEM_DEPTH; i++) begin
                    retired[i] = 0;
                    fetched[i] = 0;
                    frame_words[i] = '0;
                end
            end
            prev_en = item.en;
        end
    endtask
endclass
