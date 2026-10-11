class sm_scoreboard;
    int passed = 0;
    int failed = 0;
    
    sm_iss model;
    mailbox #(sm_obs) scoreboard_mailbox;

    function new(mailbox #(sm_obs) mb);
        scoreboard_mailbox = mb;
        model = new();
    endfunction

    task run();
        sm_obs item;
        sm_iss::sm_model_predictions_t prediction;
        bit valid;

        forever begin
            valid = model.is_valid();
            scoreboard_mailbox.get(item);
            prediction = model.predict(item);
            model.step(item);

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
            end
        end
    endtask
endclass