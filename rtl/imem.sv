module imem #(
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned IMEM_DEPTH = 64,
    parameter int unsigned NUM_SM = 2
) (
    input logic clk,
    input logic [NUM_SM-1:0][$clog2(IMEM_DEPTH)-1:0] rd_addr,
    output logic [NUM_SM-1:0][DATA_WIDTH-1:0] rd_data,
    input logic wr_en,
    input logic [$clog2(IMEM_DEPTH)-1:0] wr_addr,
    input logic [DATA_WIDTH-1:0] wr_data
);

    generate
        if ((IMEM_DEPTH != (1 << ($clog2(IMEM_DEPTH))))) begin
            $fatal(1, "IMEM_DEPTH must be a power of 2. IMEM_DEPTH: %d", IMEM_DEPTH);
        end

        if (DATA_WIDTH != 16) begin
            $fatal(1, "DATA_WIDTH must be 16 to fit the instruction set. DATA_WIDTH: %d", DATA_WIDTH);
        end
    endgenerate

    logic [DATA_WIDTH-1:0] mem [IMEM_DEPTH];

    always_comb begin
        for (int i = 0; i < NUM_SM; i++) begin
            rd_data[i] = mem[rd_addr[i]];
        end
    end

    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end
    
endmodule