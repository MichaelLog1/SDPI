package sm_core_if_pkg;
    localparam int unsigned INSTRUCTION_WIDTH = 16;
    localparam int unsigned DATA_WIDTH = 16;
    localparam int unsigned IMEM_DEPTH = 64;
    localparam int unsigned SM_WINDOW = 32;
    localparam int unsigned NUM_PINS = 8;
    localparam bit USE_FRAC_DIV = 0;
    localparam int unsigned DIV_INT_WIDTH = 16;
    localparam int unsigned DIV_FRAC_WIDTH = 8;
    localparam int unsigned NUM_IRQ = 8;
    localparam int unsigned FIFO_DEPTH = 4;
endpackage