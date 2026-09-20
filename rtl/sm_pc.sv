module sm_pc #(
    int unsigned SM_WINDOW = 32,
    int unsigned IMEM_DEPTH = 64
) (
    input logic clk,
    input logic rst_n,
    input logic restart,
    input logic advance,
    input logic load_req,
    input logic [$clog2(SM_WINDOW)-1:0] load_data,
    input logic [$clog2(IMEM_DEPTH)-1:0] pc_base,
    input logic [$clog2(SM_WINDOW)-1:0] wrap_top,
    input logic [$clog2(SM_WINDOW)-1:0] wrap_bottom,
    output logic [$clog2(IMEM_DEPTH)-1:0] pc_absolute,
    output logic [$clog2(SM_WINDOW)-1:0] pc_local
);

    // checks to ensure parameters make sense
    generate
        if ((IMEM_DEPTH != (1 << ($clog2(IMEM_DEPTH))))) begin
            $fatal(1, "IMEM_DEPTH must be a power of 2. IMEM_DEPTH: %d", IMEM_DEPTH);
        end

        if (SM_WINDOW != 32) begin
            $fatal(1, "SM_WINDOW must be 32 to fit a 16 bit instruction set. SM_WINDOW: %d", SM_WINDOW);
        end

        if (SM_WINDOW > IMEM_DEPTH) begin
            $fatal(1, "IMEM_DEPTH must be greater than or equal to SM_WINDOW. IMEM_DEPTH: %d, SM_WINDOW: %d", IMEM_DEPTH, SM_WINDOW);
        end
    endgenerate
    
    logic [$clog2(SM_WINDOW)-1:0] pc_local_r;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pc_local_r <= '0;
        end else begin
            if (restart) begin
                pc_local_r <= '0;
            end else if (advance) begin
                if (load_req) begin
                    pc_local_r <= load_data;
                end else begin
                    if (pc_local_r == wrap_top) begin
                        pc_local_r <= wrap_bottom;
                    end else begin
                        pc_local_r <= pc_local_r + 1'b1;
                    end
                end
            end
        end
    end

    assign pc_absolute = pc_base + pc_local_r;
    assign pc_local = pc_local_r;

endmodule