// a shift register parameterizable for input and output shifts

// shift_amt covers values 1-16
module shift_reg #(
    parameter int unsigned IS_INPUT = 0,
    parameter int unsigned DATA_WIDTH = 16
) (
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic shift_dir, // 1 = MSB first
    input logic [$clog2(DATA_WIDTH):0] threshold,
    input logic do_shift,
    input logic [$clog2(DATA_WIDTH):0] shift_amt,
    input logic [DATA_WIDTH-1:0] shift_data_in,
    output logic [DATA_WIDTH-1:0] shift_data_out,
    input logic do_load,
    input logic [DATA_WIDTH-1:0] load_data,
    input logic do_unload,
    output logic [DATA_WIDTH-1:0] unload_data,
    output logic [$clog2(DATA_WIDTH):0] count_out,
    output logic threshold_reached
);
    // registers
    logic [DATA_WIDTH-1:0] shift_r;
    logic [$clog2(DATA_WIDTH):0] count_r;

    // comb
    logic [DATA_WIDTH-1:0] shift_mask;
    assign shift_mask = (((DATA_WIDTH)'(1)<<shift_amt) - 1);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shift_r <= '0;
            if (IS_INPUT) begin
                count_r <= '0;
            end else begin
                count_r <= DATA_WIDTH;
            end
        end else begin
            if (en) begin
                // check for load first
                if (do_unload) begin
                    shift_r <= '0;
                    count_r <= '0;
                end else if (do_load) begin
                    shift_r <= load_data;
                    count_r <= '0;
                end else if (do_shift) begin
                    // shift if no load
                    if (shift_dir) begin
                        shift_r <= (shift_r << shift_amt) | (shift_data_in & shift_mask);
                    end else begin
                        shift_r <= (shift_r >> shift_amt) | ((shift_data_in & shift_mask) << (DATA_WIDTH-shift_amt));
                    end
                    if (count_r + shift_amt > DATA_WIDTH) begin
                        count_r <= DATA_WIDTH;
                    end else begin
                        count_r <= count_r + shift_amt;
                    end
                end
            end
        end
    end

    assign unload_data = shift_r;
    assign count_out = count_r;
    assign threshold_reached = threshold ? (count_r >= threshold) : count_r >= DATA_WIDTH;
    assign shift_data_out = shift_dir ? (shift_r >> (DATA_WIDTH - shift_amt)) : (shift_r & shift_mask);

    
endmodule