class sm_osr_model;
    logic shift_r [DATA_WIDTH];
    int count;

    function bit get_threshold_reached(logic [$clog2(DATA_WIDTH):0] threshold);
        return (threshold ? (count >= threshold) : count >= DATA_WIDTH);
    endfunction

    function logic [DATA_WIDTH-1:0] get_unload_data();
        logic [DATA_WIDTH-1:0] result;
        for (int i = 0; i < DATA_WIDTH; i++) begin
            result[i] = shift_r[i];
        end
        return result;
    endfunction

    function logic [DATA_WIDTH-1:0] get_shift_data_out(logic [$clog2(DATA_WIDTH):0] shift_amt, logic shiftdir);
        logic [DATA_WIDTH-1:0] temp_shift_r;
        for (int i = 0; i < DATA_WIDTH; i++) begin
            temp_shift_r[i] = shift_r[i];
        end

        return (shiftdir ? (temp_shift_r >> (DATA_WIDTH - shift_amt)) : (temp_shift_r & (((DATA_WIDTH)'(1)<<shift_amt) - 1)));
    endfunction

    function void reset();
        foreach (shift_r[i]) shift_r[i] = 0;
        count = DATA_WIDTH;
    endfunction

    function void step(logic rst_n, logic en, logic do_unload, logic do_load, logic do_shift, logic shiftdir, logic [DATA_WIDTH-1:0] load_data, logic [$clog2(DATA_WIDTH):0] shift_amt, logic [DATA_WIDTH-1:0] shift_data_in);
        if (!rst_n) begin
            reset();
        end else begin
            if (en) begin
                if (do_unload) begin
                    foreach (shift_r[i]) shift_r[i] = 0;
                    count = 0;
                end else if (do_load) begin
                    foreach (shift_r[i]) shift_r[i] = load_data[i];
                    count = 0;
                end else if (do_shift) begin
                    if (shiftdir) begin
                        logic temp_shift [DATA_WIDTH] = shift_r;

                        for (int i = 0; i < DATA_WIDTH - shift_amt; i++) begin
                            shift_r[i+shift_amt] = temp_shift[i];
                        end

                        for (int i = 0; i < shift_amt; i++) begin
                            shift_r[i] = shift_data_in[i];
                        end
                    end else begin
                        for (int i = 0; i < DATA_WIDTH - shift_amt; i++) begin
                            shift_r[i] = shift_r[i+shift_amt];
                        end

                        for (int i = 0; i < shift_amt; i++) begin
                            shift_r[DATA_WIDTH-shift_amt+i] = shift_data_in[i];
                        end
                    end
                    if (count + shift_amt > DATA_WIDTH) count = DATA_WIDTH;
                    else count += shift_amt;
                end
            end
        end
    endfunction
endclass
