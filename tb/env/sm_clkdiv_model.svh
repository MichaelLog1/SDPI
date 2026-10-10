class sm_clkdiv_model #(
    parameter bit USE_FRAC_DIV = 0
);
    int gap;
    logic [DIV_FRAC_WIDTH-1:0] frac_accumulator;
    logic tick_r;

    function logic tick();
        return tick_r;
    endfunction

    function void reset(logic [DIV_INT_WIDTH-1:0] div_int);
        gap = div_int;
        frac_accumulator = 0;
        tick_r = 0;
    endfunction

    function void step(logic rst_n, 
                        logic en, 
                        logic [DIV_INT_WIDTH-1:0] div_int, 
                        logic [DIV_FRAC_WIDTH-1:0] div_frac);
        logic [DIV_FRAC_WIDTH:0] frac_overflow;
        int div_load = div_int ? div_int : 1;

        if (!en || !rst_n) begin
            reset(div_int);        
        end else if (en) begin
            gap = gap - 1;
            if (gap == 0) begin
                // a tick happens here
                if (USE_FRAC_DIV) begin
                    frac_overflow = frac_accumulator + div_frac;
                    frac_accumulator = frac_accumulator + div_frac;
                    if (frac_overflow[DIV_FRAC_WIDTH]) begin
                        gap = div_load + 1;
                    end else begin
                        gap = div_load;
                    end
                end else begin
                    gap = div_load;
                end
                tick_r = 1;
            end else begin
                tick_r = 0;
            end
        end
    endfunction
endclass
