module fifo #(
    parameter int unsigned FIFO_DEPTH = 4,
    parameter int unsigned DATA_WIDTH = 16
) (
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic full,
    output logic empty,
    output logic [$clog2(FIFO_DEPTH):0] current_depth,
    output logic overflow,
    output logic underflow,
    input logic clear
);

    generate
        if (FIFO_DEPTH <= 1) begin
            $fatal(1, "FIFO_DEPTH must greater than 1. FIFO_DEPTH: %d", FIFO_DEPTH);
        end

        if ((FIFO_DEPTH != (1 << ($clog2(FIFO_DEPTH))))) begin
            $fatal(1, "FIFO_DEPTH must be a power of 2. FIFO_DEPTH: %d", FIFO_DEPTH);
        end
    endgenerate

    logic [DATA_WIDTH-1:0] fifo [FIFO_DEPTH];

    logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr_r;
    logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr_r;
    logic [$clog2(FIFO_DEPTH):0] count_r;
    logic overflow_r;
    logic underflow_r;
    logic rd_accepted;
    logic wr_accepted;
    logic wr_overflow;
    logic rd_underflow;

    assign rd_accepted = (rd_en && !empty);
    assign wr_accepted = (wr_en && !full) || (wr_en && rd_en);
    assign rd_underflow = (rd_en && empty);
    assign wr_overflow = (wr_en && full) && (!rd_en);
    

    always_ff @(posedge clk) begin
        if (!rst_n || clear) begin
            rd_ptr_r <= '0;
            wr_ptr_r <= '0;
            count_r <= '0;
            overflow_r <= 1'b0;
            underflow_r <= 1'b0;
        end else begin
            if (wr_accepted) begin
                fifo[wr_ptr_r] <= wr_data;
                wr_ptr_r <= wr_ptr_r + 1;
            end
            
            if (rd_accepted) begin
                rd_ptr_r <= rd_ptr_r + 1;
            end

            count_r <= count_r + (wr_accepted - rd_accepted);
            overflow_r <= (overflow_r || wr_overflow);
            underflow_r <= (underflow_r || rd_underflow);
        end
    end
    
    assign rd_data = fifo[rd_ptr_r];
    assign current_depth = count_r;
    assign empty = (count_r == 0);
    assign full = (count_r >= FIFO_DEPTH);
    assign overflow = overflow_r;
    assign underflow = underflow_r;
endmodule