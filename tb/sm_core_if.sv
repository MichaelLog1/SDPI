interface sm_core_if #(
    parameter int unsigned INSTRUCTION_WIDTH = sm_core_if_pkg::INSTRUCTION_WIDTH,
    parameter int unsigned IMEM_DEPTH = sm_core_if_pkg::IMEM_DEPTH,
    parameter int unsigned DATA_WIDTH = sm_core_if_pkg::DATA_WIDTH,
    parameter int unsigned NUM_PINS = sm_core_if_pkg::NUM_PINS,
    parameter int unsigned DIV_INT_WIDTH = sm_core_if_pkg::DIV_INT_WIDTH,
    parameter int unsigned DIV_FRAC_WIDTH = sm_core_if_pkg::DIV_FRAC_WIDTH,
    parameter int unsigned SM_WINDOW = sm_core_if_pkg::SM_WINDOW,
    parameter int unsigned NUM_IRQ = sm_core_if_pkg::NUM_IRQ,
    parameter int unsigned FIFO_DEPTH = sm_core_if_pkg::FIFO_DEPTH
) (
    input logic clk
);
    // DUT signals
    logic rst_n;
    logic en;
    logic restart;
    logic [INSTRUCTION_WIDTH-1:0] instruction;
    logic [$clog2(IMEM_DEPTH)-1:0] pc_absolute;
    logic tx_en;                    // tx fifo rd_en
    logic [DATA_WIDTH-1:0] tx_data; // tx fifo rd_data
    logic rx_en;                    // rx fifo wr_en
    logic [DATA_WIDTH-1:0] rx_data; // rx fifo wr_data
    logic empty;                    // tx fifo empty
    logic full;                     // rx fifo full
    logic [NUM_PINS-1:0] uio_in;
    logic [NUM_PINS-1:0] uio_out;
    logic [NUM_PINS-1:0] uio_oe;
    logic [DIV_INT_WIDTH-1:0] div_int;
    logic [DIV_FRAC_WIDTH-1:0] div_frac;
    logic [$clog2(IMEM_DEPTH)-1:0] pc_base;
    logic [$clog2(SM_WINDOW)-1:0] wrap_top;
    logic [$clog2(SM_WINDOW)-1:0] wrap_bottom;
    logic [2:0] jmp_pin;
    logic [$clog2(6)-1:0] sideset_count;
    logic sideset_opt;
    logic osr_shiftdir;
    logic isr_shiftdir;
    logic autopull;
    logic autopush;
    logic [4:0] isr_threshold;
    logic [4:0] osr_threshold;
    logic delay_from_y;
    logic [2:0] pin_out_base;
    logic [3:0] pin_out_count;
    logic [2:0] pin_set_base;
    logic [2:0] pin_set_count;
    logic [2:0] pin_in_base;
    logic [2:0] pin_sideset_base;
    logic [NUM_IRQ-1:0] irq_flags;
    logic [NUM_IRQ-1:0] irq_clear;
    logic [NUM_IRQ-1:0] irq_set;
    // Non-DUT signals
    // external tx fifo
    logic tx_fifo_wr_en;
    logic [DATA_WIDTH-1:0] tx_fifo_wr_data;
    logic tx_fifo_full;
    logic [$clog2(FIFO_DEPTH):0] tx_fifo_current_depth;
    logic tx_fifo_overflow;
    logic tx_fifo_underflow;
    logic tx_fifo_clear;
    // external rx fifo
    logic rx_fifo_rd_en;
    logic [DATA_WIDTH-1:0] rx_fifo_rd_data;
    logic rx_fifo_empty;
    logic [$clog2(FIFO_DEPTH):0] rx_fifo_current_depth;
    logic rx_fifo_overflow;
    logic rx_fifo_underflow;
    logic rx_fifo_clear;
    // external irqs
    logic [NUM_IRQ-1:0] ext_irq_set;
    logic [NUM_IRQ-1:0] ext_irq_clr;
    // cycle counter
    int cycle = 0;
    // program memory
    logic [15:0] mem [IMEM_DEPTH];

    assign instruction = mem[pc_absolute];

    clocking driver_cb @(posedge clk);
        default output #0;
        output rst_n, en, restart, uio_in, div_int, div_frac, pc_base, wrap_top, wrap_bottom, jmp_pin, sideset_count, sideset_opt, osr_shiftdir, isr_shiftdir, autopull, autopush, isr_threshold, osr_threshold, delay_from_y, pin_out_base, pin_out_count, pin_set_base, pin_set_count, pin_in_base, pin_sideset_base, irq_flags, tx_fifo_wr_en, tx_fifo_wr_data, tx_fifo_clear, rx_fifo_rd_en, rx_fifo_clear, ext_irq_set, ext_irq_clr;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n, en, restart, instruction, pc_absolute, tx_en, tx_data, rx_en, rx_data, empty, full, uio_in, uio_out, uio_oe, div_int, div_frac, pc_base, wrap_top, wrap_bottom, jmp_pin, sideset_count, sideset_opt, osr_shiftdir, isr_shiftdir, autopull, autopush, isr_threshold, osr_threshold, delay_from_y, pin_out_base, pin_out_count, pin_set_base, pin_set_count, pin_in_base, pin_sideset_base, irq_flags, irq_clear, irq_set, tx_fifo_wr_en, tx_fifo_wr_data, tx_fifo_full, tx_fifo_current_depth, tx_fifo_overflow, tx_fifo_underflow, tx_fifo_clear, rx_fifo_rd_en, rx_fifo_rd_data, rx_fifo_empty, rx_fifo_current_depth, rx_fifo_overflow, rx_fifo_underflow, rx_fifo_clear, ext_irq_set, ext_irq_clr, cycle;
    endclocking

    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
endinterface
