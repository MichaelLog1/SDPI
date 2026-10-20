`timescale 1 ns / 10 ps

import sm_core_if_pkg::*;
import sm_core_env_pkg::*;


module sm_core_tb #(
    parameter int unsigned INSTRUCTION_WIDTH = sm_core_if_pkg::INSTRUCTION_WIDTH,
    parameter int unsigned DATA_WIDTH = sm_core_if_pkg::DATA_WIDTH,
    parameter int unsigned IMEM_DEPTH = sm_core_if_pkg::IMEM_DEPTH,
    parameter int unsigned SM_WINDOW = sm_core_if_pkg::SM_WINDOW,
    parameter int unsigned NUM_PINS = sm_core_if_pkg::NUM_PINS,
    parameter bit USE_FRAC_DIV = sm_core_if_pkg::USE_FRAC_DIV,
    parameter int unsigned DIV_INT_WIDTH = sm_core_if_pkg::DIV_INT_WIDTH,
    parameter int unsigned DIV_FRAC_WIDTH = sm_core_if_pkg::DIV_FRAC_WIDTH,
    parameter int unsigned NUM_IRQ = sm_core_if_pkg::NUM_IRQ,
    parameter int unsigned FIFO_DEPTH = sm_core_if_pkg::FIFO_DEPTH,
    parameter int unsigned NUM_FRAMES = 10000
);
    
    logic clk = 0;
    sm_core_if vif (.clk(clk));
    sm_env #(.NUM_FRAMES(NUM_FRAMES)) env;

    sm_core #(
        .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .IMEM_DEPTH(IMEM_DEPTH),
        .SM_WINDOW(SM_WINDOW),
        .NUM_PINS(NUM_PINS),
        .USE_FRAC_DIV(USE_FRAC_DIV),
        .DIV_INT_WIDTH(DIV_INT_WIDTH),
        .DIV_FRAC_WIDTH(DIV_FRAC_WIDTH),
        .NUM_IRQ(NUM_IRQ)
    ) dut_sm_core (
        .clk(clk),
        .rst_n(vif.rst_n),
        .en(vif.en),
        .restart(vif.restart),
        .instruction(vif.instruction),
        .pc_absolute(vif.pc_absolute),
        .tx_en(vif.tx_en),
        .tx_data(vif.tx_data),
        .rx_en(vif.rx_en),
        .rx_data(vif.rx_data),
        .empty(vif.empty),
        .full(vif.full),
        .uio_in(vif.uio_in),
        .uio_out(vif.uio_out),
        .uio_oe(vif.uio_oe),
        .div_int(vif.div_int),
        .div_frac(vif.div_frac),
        .pc_base(vif.pc_base),
        .wrap_top(vif.wrap_top),
        .wrap_bottom(vif.wrap_bottom),
        .jmp_pin(vif.jmp_pin),
        .sideset_count(vif.sideset_count),
        .sideset_opt(vif.sideset_opt),
        .osr_shiftdir(vif.osr_shiftdir),
        .isr_shiftdir(vif.isr_shiftdir),
        .autopull(vif.autopull),
        .autopush(vif.autopush),
        .isr_threshold(vif.isr_threshold),
        .osr_threshold(vif.osr_threshold),
        .delay_from_y(vif.delay_from_y),
        .pin_out_base(vif.pin_out_base),
        .pin_out_count(vif.pin_out_count),
        .pin_set_base(vif.pin_set_base),
        .pin_set_count(vif.pin_set_count),
        .pin_in_base(vif.pin_in_base),
        .pin_sideset_base(vif.pin_sideset_base),
        .irq_flags(vif.irq_flags),
        .irq_clear(vif.irq_clear),
        .irq_set(vif.irq_set)
    );

    fifo #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut_tx_fifo (
        .clk(clk),
        .rst_n(vif.rst_n),
        .wr_en(vif.tx_fifo_wr_en),
        .wr_data(vif.tx_fifo_wr_data),
        .rd_en(vif.tx_en),
        .rd_data(vif.tx_data),
        .full(vif.tx_fifo_full),
        .empty(vif.empty),
        .current_depth(vif.tx_fifo_current_depth),
        .overflow(vif.tx_fifo_overflow),
        .underflow(vif.tx_fifo_underflow),
        .clear(vif.tx_fifo_clear)
    );

    fifo #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut_rx_fifo (
        .clk(clk),
        .rst_n(vif.rst_n),
        .wr_en(vif.rx_en),
        .wr_data(vif.rx_data),
        .rd_en(vif.rx_fifo_rd_en),
        .rd_data(vif.rx_fifo_rd_data),
        .full(vif.full),
        .empty(vif.rx_fifo_empty),
        .current_depth(vif.rx_fifo_current_depth),
        .overflow(vif.rx_fifo_overflow),
        .underflow(vif.rx_fifo_underflow),
        .clear(vif.rx_fifo_clear)
    );

    initial begin : generate_clock
        forever #10 clk <= !clk;
    end
    /* for reference
    initial begin : run
        // fill mem with traps
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            vif.mem[i] <= 16'b0000000000011111;
        end

        // small test program
        vif.mem[0] <= 16'b1110000000000001;
        vif.mem[1] <= 16'b1110000000000010;
        vif.mem[2] <= 16'b1110000000000011;
        vif.mem[3] <= 16'b1110000000000100;
        vif.mem[4] <= 16'b0000000000000000;

        // reset configuration
        vif.div_int <= DIV_INT_WIDTH'(1);
        vif.div_frac <= 1'b0;
        vif.pc_base <= '0;
        vif.wrap_top <= SM_WINDOW - 1;
        vif.wrap_bottom <= '0;
        vif.jmp_pin <= '0;
        vif.sideset_count <= '0;
        vif.sideset_opt <= '0;
        vif.osr_shiftdir <= '0;
        vif.isr_shiftdir <= '0;
        vif.autopull <= '0;
        vif.autopush <= '0;
        vif.isr_threshold <= '0; // a full 16 bit word
        vif.osr_threshold <= '0; // a full 16 bit word
        vif.delay_from_y <= '0;
        vif.pin_out_base <= '0;
        vif.pin_out_count <= '0;
        vif.pin_set_base <= '0;
        vif.pin_set_count <= 3;
        vif.pin_in_base <= '0;
        vif.pin_sideset_base <= '0;
        vif.irq_flags <= '0;
        // driving signals
        vif.rst_n <= 1'b0;
        vif.en <= 1'b0;
        vif.restart <= 1'b0;
        vif.uio_in <= '0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        vif.rst_n <= 1'b1;
        vif.en <= 1'b1;

        for (int i = 0; i < 50; i++) begin
            @(vif.monitor_cb);
            $display("CYCLE %d\n", vif.cycle);
            $display("pc_absolute: %d, instruction: %d", vif.monitor_cb.pc_absolute, vif.monitor_cb.instruction);
            $display("uio_out: %d\n", vif.monitor_cb.uio_out);
        end
        $finish;
    end
    */

    initial begin : run
        env = new(vif);
        env.run();
    end

    
endmodule