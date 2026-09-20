module clkdiv #(
    bit USE_FRAC_DIV = 0,
    int unsigned DIV_INT_WIDTH = 16,
    int unsigned DIV_FRAC_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [DIV_INT_WIDTH-1:0] div_int,
    input logic [DIV_FRAC_WIDTH-1:0] div_frac,
    output logic tick
);

    logic [DIV_INT_WIDTH:0] count_r, count_load;
    logic [DIV_FRAC_WIDTH-1:0] frac_accumulator_r;
    logic [DIV_FRAC_WIDTH:0] frac_ovf;
    logic tick_r;

    assign count_load = div_int ? { 1'b0, div_int } : (DIV_INT_WIDTH+1)'(1);
    assign frac_ovf = frac_accumulator_r + div_frac;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count_r <= count_load;
            frac_accumulator_r <= '0;
            tick_r <= 1'b0;
        end else begin
            tick_r <= 1'b0;
            if (en) begin
                if (count_r == 1) begin
                    tick_r <= 1'b1; // output tick
                    if (USE_FRAC_DIV) begin
                        frac_accumulator_r <= frac_ovf[DIV_FRAC_WIDTH-1:0];
                        if (frac_ovf[DIV_FRAC_WIDTH]) begin // overflow occured
                            count_r <= count_load + 1;
                        end else begin
                            count_r <= count_load;
                        end
                    end else begin
                        count_r <= count_load;
                    end
                end else begin
                    count_r <= count_r - 1;
                end
            end else begin
                count_r <= count_load;
                frac_accumulator_r <= '0;
            end
        end
    end

    assign tick = tick_r;
    
endmodule
