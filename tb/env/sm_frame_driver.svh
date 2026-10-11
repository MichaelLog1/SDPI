class sm_frame_driver;
    virtual sm_core_if vif;
    mailbox #(sm_program) frame_driver_mailbox;

    function new(virtual sm_core_if _vif, mailbox #(sm_program) mb);
        vif = _vif;
        frame_driver_mailbox = mb;
    endfunction

    task drive_frame(sm_program prog);
        // drive config
        vif.driver_cb.div_int <= prog.cfg.div_int;
        vif.driver_cb.div_frac <= prog.cfg.div_frac;
        vif.driver_cb.pc_base <= prog.cfg.pc_base;
        vif.driver_cb.wrap_top <= prog.cfg.wrap_top;
        vif.driver_cb.wrap_bottom <= prog.cfg.wrap_bottom;
        vif.driver_cb.jmp_pin <= prog.cfg.jmp_pin;
        vif.driver_cb.sideset_count <= prog.cfg.sideset_count;
        vif.driver_cb.sideset_opt <= prog.cfg.sideset_opt;
        vif.driver_cb.osr_shiftdir <= prog.cfg.osr_shiftdir;
        vif.driver_cb.isr_shiftdir <= prog.cfg.isr_shiftdir;
        vif.driver_cb.autopull <= prog.cfg.autopull;
        vif.driver_cb.autopush <= prog.cfg.autopush;
        vif.driver_cb.isr_threshold <= prog.cfg.isr_threshold;
        vif.driver_cb.osr_threshold <= prog.cfg.osr_threshold;
        vif.driver_cb.delay_from_y <= prog.cfg.delay_from_y;
        vif.driver_cb.pin_out_base <= prog.cfg.pin_out_base;
        vif.driver_cb.pin_out_count <= prog.cfg.pin_out_count;
        vif.driver_cb.pin_set_base <= prog.cfg.pin_set_base;
        vif.driver_cb.pin_set_count <= prog.cfg.pin_set_count;
        vif.driver_cb.pin_in_base <= prog.cfg.pin_in_base;
        vif.driver_cb.pin_sideset_base <= prog.cfg.pin_sideset_base;
        // idle values for control signals
        vif.driver_cb.restart <= 1'b0;
        vif.driver_cb.uio_in <= '0;
        vif.driver_cb.tx_fifo_wr_en <= 1'b0;
        vif.driver_cb.tx_fifo_wr_data <= '0;
        vif.driver_cb.tx_fifo_clear <= 1'b0;
        vif.driver_cb.rx_fifo_rd_en <= 1'b0;
        vif.driver_cb.rx_fifo_clear <= 1'b0;

        // reset
        vif.driver_cb.rst_n <= 1'b0;
        vif.driver_cb.en <= 1'b0;
        repeat (5) @(vif.driver_cb);
        vif.driver_cb.rst_n <= 1'b1;
        @(vif.driver_cb);

        // fill program with traps (jmp to offset 31)
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            vif.mem[i] <= encode_jmp(JMP_ALWAYS, 31, 0, 0, 0, 0, 0);
        end

        // load the actual frame
        for (int i = 0; i < prog.instr.size(); i++) begin
            vif.mem[prog.cfg.pc_base + i] <= prog.instr[i].encode();
        end
        @(vif.driver_cb);

        // enable
        vif.driver_cb.en <= 1'b1;
        @(vif.driver_cb);

        // wait for frame to end
        // TODO: make this more sophistocated
        repeat (1000) @(vif.driver_cb);

        // disable
        vif.driver_cb.en <= 1'b0;
        repeat (3) @(vif.driver_cb);
    endtask

    task run();
        sm_program item;
        forever begin
            frame_driver_mailbox.get(item);
            if (item == null) return;

            drive_frame(item);
        end
    endtask
endclass
