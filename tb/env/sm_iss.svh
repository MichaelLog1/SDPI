class sm_iss;
    bit valid = 0;
    logic [$clog2(SM_WINDOW)-1:0] pc_local;
    logic [DATA_WIDTH-1:0] X;
    logic [DATA_WIDTH-1:0] Y;
    logic [NUM_PINS-1:0] uio_out;
    logic [NUM_PINS-1:0] uio_oe;
    logic [4:0] delay_count;

    // rising edge state
    logic [NUM_PINS-1:0] prev_uio_in;
    logic [NUM_PINS-1:0] falling_edge = '0;
    logic [NUM_PINS-1:0] rising_edge = '0;

    // registers
    logic irq_set_issued = 1'b0;

    // submodels
    sm_isr_model isr_model;
    sm_osr_model osr_model;
    sm_clkdiv_model #(.USE_FRAC_DIV(0)) clkdiv_model;

    typedef struct {
        logic [$clog2(IMEM_DEPTH)-1:0] pc_absolute;
        logic [NUM_PINS-1:0] uio_out;
        logic [NUM_PINS-1:0] uio_oe;
        logic tx_en;
        logic rx_en;
        logic [DATA_WIDTH-1:0] rx_data;
        logic [NUM_IRQ-1:0] irq_set;
        logic [NUM_IRQ-1:0] irq_clear;
    } sm_model_predictions_t;

    typedef struct {
        // next register values
        logic [DATA_WIDTH-1:0] next_X;
        logic [DATA_WIDTH-1:0] next_Y;
        logic [NUM_PINS-1:0] next_uio_out;
        logic [NUM_PINS-1:0] next_uio_oe;
        logic pc_load_req;
        logic [$clog2(SM_WINDOW)-1:0] pc_load_data;
        logic [4:0] delay;
        logic next_irq_set_issued;
        // ISR control inputs
        logic isr_do_unload;
        logic isr_do_load;
        logic isr_do_shift;
        logic [DATA_WIDTH-1:0] isr_load_data;
        logic [$clog2(DATA_WIDTH):0] isr_shift_amt;
        logic [DATA_WIDTH-1:0] isr_shift_data_in;
        // OSR control inputs
        logic osr_do_load;
        logic osr_do_shift;
        logic [DATA_WIDTH-1:0] osr_load_data;
        logic [$clog2(DATA_WIDTH):0] osr_shift_amt;
        // general control
        logic tick;
        logic advance;
        logic blocked;
        logic stall_autopush;
        logic stall_autopull;
        logic stall_push;
        logic stall_pull;
        logic waiting;
        logic stall_irq;
        logic datapath_reset_n;
        // boundary outputs
        logic tx_en;
        logic rx_en;
        logic [DATA_WIDTH-1:0] rx_data;
        logic [NUM_IRQ-1:0] irq_set;
        logic [NUM_IRQ-1:0] irq_clear;
    } comb_t;

    function new();
        isr_model = new();
        osr_model = new();
        clkdiv_model = new();
    endfunction

    function logic get_advance(sm_obs item);
        comb_t comb_signals = comb(item); 
        return comb_signals.advance;
    endfunction

    function bit is_valid();
        return valid;
    endfunction

    function void reset(logic [DIV_INT_WIDTH-1:0] div_int);
        valid = 1;
        pc_local = '0;
        X = '0;
        Y = '0;
        uio_out = '0;
        uio_oe = '0;
        delay_count = '0;
        prev_uio_in = '0;
        rising_edge = '0;
        falling_edge = '0;
        irq_set_issued = '0;
        isr_model.reset();
        osr_model.reset();
        clkdiv_model.reset(div_int);
    endfunction

    // derive combinational signals, no writes
    local function comb_t comb(sm_obs item);
        comb_t comb_output;
        logic advance = 1'b0;
        logic blocked = 1'b0;
        logic waiting = 1'b0;
        logic stall_autopush = 1'b0;
        logic stall_autopull = 1'b0;
        logic stall_push = 1'b0;
        logic stall_pull = 1'b0;
        logic stall_irq = 1'b0;
        logic datapath_reset_n = 1'b0;
        logic [NUM_IRQ-1:0] irq_set_req = '0;
        logic [NUM_IRQ-1:0] irq_clr_req = '0;
        logic isr_do_shift = 1'b0;
        logic osr_do_shift = 1'b0;
        logic [$clog2(DATA_WIDTH):0] isr_shift_amt = '0;
        logic [$clog2(DATA_WIDTH):0] osr_shift_amt = '0;
        logic isr_autopush_fire = '0;
        logic isr_push_fire = '0;
        logic isr_do_unload = '0;
        logic rx_en = '0;
        logic [DATA_WIDTH-1:0] rx_data = '0;
        logic isr_do_load = '0;
        logic [DATA_WIDTH-1:0] isr_load_data = '0;
        logic osr_autopull_fire = '0;
        logic osr_pull_fire = '0;
        logic osr_do_load = '0;
        logic tx_en = '0;
        logic [DATA_WIDTH-1:0] osr_load_data = '0;
        logic [DATA_WIDTH-1:0] mov_osr_data = '0;
        logic [DATA_WIDTH-1:0] mov_isr_data = '0;
        logic jmp_taken = 1'b0;
        logic is_out_pc_load = 1'b0;
        logic is_mov_pc_load = 1'b0;
        logic pc_load_req = 1'b0;
        logic [NUM_IRQ-1:0] irq_clear = '0;
        logic [NUM_IRQ-1:0] irq_set = '0;
        logic [$clog2(6)-1:0] sideset_pin_count = '0;
        logic [DATA_WIDTH-1:0] isr_shift_data_in = '0;
        logic tick;

        // register nexts
        logic [DATA_WIDTH-1:0] next_X = X;
        logic [DATA_WIDTH-1:0] next_Y = Y;
        logic [NUM_PINS-1:0] next_uio_out = uio_out;
        logic [NUM_PINS-1:0] next_uio_oe = uio_oe;
        logic next_irq_set_issued = irq_set_issued;
        logic [$clog2(SM_WINDOW)-1:0] pc_load_data = '0; // TODO check this


        // helpers
        decoded_instruction_t decoded = decode(item.instruction, item.sideset_count, item.sideset_opt);
        instruction_t instr = decoded.instruction;
        logic [4:0] delay = decoded.delay;
        logic [4:0] sideset_data = decoded.sideset_data;
        logic sideset_valid = decoded.sideset_valid;

        // wrapped counts
        logic [4:0] wrapped_out_count = !instr.operand.out.count ? 16 : instr.operand.out.count;
        logic [4:0] wrapped_in_count = !instr.operand.in.count ? 16 : instr.operand.in.count;

        logic is_jmp = (instr.opcode == JMP);
        logic is_wait = (instr.opcode == WAIT);
        logic is_in = (instr.opcode == IN);
        logic is_out = (instr.opcode == OUT);
        logic is_push = (instr.opcode == PUSH_PULL) & !instr.operand.push_pull.push_pull;
        logic is_pull = (instr.opcode == PUSH_PULL) & instr.operand.push_pull.push_pull;
        logic is_mov = (instr.opcode == MOV);
        logic is_irq = (instr.opcode == IRQ);
        logic is_set = (instr.opcode == SET);

        if (is_jmp) begin
            pc_load_data = instr.operand.jmp.offset;
            case (instr.operand.jmp.cond)
                JMP_ALWAYS: jmp_taken = 1'b1;
                JMP_X_EQ_ZERO: if (X == 0) jmp_taken = 1'b1;
                JMP_X_NE_ZERO: begin
                    if (X != 0) begin
                        jmp_taken = 1'b1;
                        next_X = X - 1;
                    end
                end
                JMP_Y_EQ_ZERO: if (Y == 0) jmp_taken = 1'b1;
                JMP_Y_NE_ZERO: begin
                    if (Y != 0) begin
                        jmp_taken = 1'b1;
                        next_Y = Y - 1;
                    end
                end
                JMP_X_NE_Y: if (X != Y) jmp_taken = 1'b1;
                JMP_PIN: if (item.uio_in[item.jmp_pin]) jmp_taken = 1'b1;
                JMP_OSR: if (!osr_model.get_threshold_reached(item.osr_threshold)) jmp_taken = 1'b1;
            endcase
        end else if (is_wait) begin
            case (instr.operand.wt.src)
                WAIT_PIN_ABS: begin
                    if (item.uio_in[instr.operand.wt.index[2:0]] != instr.operand.wt.pol) begin
                        waiting = 1;
                    end
                end

                WAIT_PIN_MAP: begin
                    if (item.uio_in[(instr.operand.wt.index[2:0] + item.pin_in_base)] != instr.operand.wt.pol) begin
                        waiting = 1;
                    end
                end

                WAIT_IRQ: begin
                    if (item.irq_flags[instr.operand.wt.index[2:0]] != 1'b1) begin
                        waiting = 1'b1;
                    end else begin
                        irq_clr_req[instr.operand.wt.index[2:0]] = 1'b1;
                    end
                end

                WAIT_EDGE: begin
                    if (instr.operand.wt.pol) begin
                        if (!(rising_edge[instr.operand.wt.index[2:0]])) begin
                            waiting = 1'b1;
                        end
                    end else begin
                        if (!(falling_edge[instr.operand.wt.index[2:0]])) begin
                            waiting = 1'b1;
                        end
                    end
                end
            endcase
        end else if (is_in) begin
            case (instr.operand.in.src)
                IN_PINS: begin
                    logic [2:0] temp;
                    // in_count pins starting at in_base, wrapping.
                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_in_base + i;
                        isr_shift_data_in[i] = item.uio_in[temp];
                    end
                end

                IN_X: begin
                    // in_count low bits of X register
                    isr_shift_data_in = X;
                end

                IN_Y: begin
                    // in_count low bits of Y register
                    isr_shift_data_in = Y;
                end

                IN_NULL: begin
                    // in_count zeros
                    isr_shift_data_in = '0;
                end

                IN_ISR: begin
                    // isr rotation
                    isr_shift_data_in = isr_model.get_unload_data();
                end

                IN_OSR: begin
                    // load from osr
                    isr_shift_data_in = osr_model.get_unload_data();
                end

                IN_CAPTURE: begin
                    // capture, not yet implemented TODO
                end

                IN_CRC: begin
                    // crc, not yet implemented TODO
                end
            endcase
        end else if (is_out) begin
            // we dont have access to osr_shift_out yet, so to keep this clean we just rederive it
            logic [DATA_WIDTH-1:0] temp_shift_out = osr_model.get_shift_data_out(wrapped_out_count, item.osr_shiftdir);
            case (instr.operand.out.dst)
                OUT_PINS: begin
                    logic [2:0] temp;

                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_out_base + i;
                        if (i < item.pin_out_count) next_uio_out[temp] = temp_shift_out[i];
                    end
                end

                OUT_X: begin
                    next_X = temp_shift_out;
                end

                OUT_Y: begin
                    next_Y = temp_shift_out;
                end

                OUT_NULL: begin
                    // skip output
                end

                OUT_PINDIRS: begin
                    logic [2:0] temp;

                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_out_base + i;
                        if (i < item.pin_out_count) next_uio_oe[temp] = temp_shift_out[i];
                    end
                end

                OUT_PC: begin
                    pc_load_data = temp_shift_out[$clog2(SM_WINDOW)-1:0];
                end

                OUT_ISR: begin
                    isr_shift_data_in = temp_shift_out;
                end

                OUT_EXEC: begin
                    // not implemented
                end
            endcase
        end else if (is_mov) begin
            logic [DATA_WIDTH-1:0] temp_src;
            logic [DATA_WIDTH-1:0] temp_product;

            case (instr.operand.mov.src)
                MOV_SRC_PINS: begin
                    logic [2:0] temp;
                    temp_src = '0;
                    // in_count pins starting at in_base, wrapping.
                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_in_base + i;
                        temp_src[i] = item.uio_in[temp];
                    end
                end
                MOV_SRC_X: temp_src = X;
                MOV_SRC_Y: temp_src = Y;
                MOV_SRC_NULL: temp_src = '0;
                MOV_SRC_EXEC: temp_src = '0; // meaningless, copy dut
                MOV_SRC_PC: temp_src = pc_local;
                MOV_SRC_ISR: temp_src = isr_model.get_unload_data();
                MOV_SRC_OSR: temp_src = osr_model.get_unload_data();
            endcase

            case (instr.operand.mov.op)
                MOV_OP_NONE: temp_product = temp_src;
                MOV_OP_INVERT: temp_product = ~temp_src;
                MOV_OP_REVERSE: begin
                    for (int i = 0; i < DATA_WIDTH; i++) begin
                        temp_product[i] = temp_src[DATA_WIDTH-1-i];
                    end
                end
                MOV_OP_RESERVED: temp_product = temp_src; // nop, copy dut
            endcase

            // only include cases we need for derive stage
            case (instr.operand.mov.dst)
                MOV_DST_PINS: begin
                    // pins
                    logic [2:0] temp;

                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_out_base + i;
                        if (i < item.pin_out_count) next_uio_out[temp] = temp_product[i];
                    end              
                end
                MOV_DST_X: next_X = temp_product;
                MOV_DST_Y: next_Y = temp_product;
                MOV_DST_NULL: begin
                    // nop
                end
                MOV_DST_EXEC: begin
                    // not yet implemented
                end
                MOV_DST_PC: pc_load_data = temp_product[$clog2(SM_WINDOW)-1:0];
                MOV_DST_ISR: mov_isr_data = temp_product;
                MOV_DST_OSR: mov_osr_data = temp_product;
            endcase
        end else if (is_irq) begin
            case ({instr.operand.irq.clr, instr.operand.irq.wt})
                2'd0: begin
                    irq_set_req[instr.operand.irq.index] = 1'b1;
                end

                2'd1: begin
                    if (!irq_set_issued) begin
                        irq_set_req[instr.operand.irq.index] = 1'b1;
                        stall_irq = 1'b1;
                        next_irq_set_issued = 1'b1;
                    end else if (irq_set_issued & !item.irq_flags[instr.operand.irq.index]) begin
                        stall_irq = 1'b0;
                    end else begin
                        stall_irq = 1'b1;
                    end
                end

                2'd2: begin
                    irq_clr_req[instr.operand.irq.index] = 1'b1;
                end

                2'd3: begin // nop
                end
            endcase
        end else if (is_set) begin
            case (instr.operand.set.dst)
                SET_PINS: begin
                    // pins
                    logic [2:0] temp;

                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_set_base + i;
                        if (i < item.pin_set_count) begin
                            if (i < 5) next_uio_out[temp] = instr.operand.set.imm[i];
                            else next_uio_out[temp] = 1'b0;
                        end
                    end
                end

                SET_X: begin
                    // X
                    next_X = instr.operand.set.imm;
                end

                SET_Y: begin
                    // Y
                    next_Y = instr.operand.set.imm;
                end

                SET_PINDIRS: begin
                    // pindirs
                    logic [2:0] temp;

                    for (int i = 0; i < NUM_PINS; i++) begin
                        temp = item.pin_set_base + i;
                        if (i < item.pin_set_count) begin
                            if (i < 5) next_uio_oe[temp] = instr.operand.set.imm[i];
                            else next_uio_oe[temp] = 1'b0;
                        end
                    end
                end

                default: begin
                    // all else are no ops
                end
            endcase
        end

        tick = clkdiv_model.tick();

        stall_autopush = (is_in | (is_out & (instr.operand.out.dst == OUT_ISR)) | (is_mov & (instr.operand.mov.dst == MOV_DST_ISR))) & item.autopush & (isr_model.get_threshold_reached(item.isr_threshold));
        stall_autopull = is_out & item.autopull & (osr_model.get_threshold_reached(item.osr_threshold));
        stall_push = (is_push & (instr.operand.push_pull.block) & (item.full) & ((!instr.operand.push_pull.iffull_ifempty) | (isr_model.get_threshold_reached(item.isr_threshold))));
        stall_pull = (is_pull & (instr.operand.push_pull.block) & (item.empty) & ((!instr.operand.push_pull.iffull_ifempty) | (osr_model.get_threshold_reached(item.osr_threshold))));
        blocked = waiting | stall_autopush | stall_autopull | stall_push | stall_pull | stall_irq;
        advance = tick & (delay_count == 0) & ~blocked;
        datapath_reset_n = item.rst_n & !item.restart;
        
        // shift register comb
        isr_do_shift = advance & (is_in | (is_out & (instr.operand.out.dst == OUT_ISR)));
        osr_do_shift = advance & is_out;
        isr_shift_amt = (is_out & (instr.operand.out.dst == OUT_ISR)) ? wrapped_out_count : wrapped_in_count;
        osr_shift_amt = wrapped_out_count;

        // autopush/rx
        isr_autopush_fire = item.en & item.autopush & isr_model.get_threshold_reached(item.isr_threshold) & !item.full;
        isr_push_fire = advance & is_push & (~instr.operand.push_pull.iffull_ifempty | isr_model.get_threshold_reached(item.isr_threshold));
        isr_do_unload = isr_autopush_fire | isr_push_fire;
        rx_en = (isr_autopush_fire | isr_push_fire) & !item.full;
        rx_data = isr_model.get_unload_data();

        isr_do_load = advance & (is_mov & (instr.operand.mov.dst == MOV_DST_ISR));
        isr_load_data = mov_isr_data;

        osr_autopull_fire = item.en & item.autopull & osr_model.get_threshold_reached(item.osr_threshold) & !item.empty & !(is_mov & (instr.operand.mov.dst == MOV_DST_OSR));
        osr_pull_fire = advance & is_pull & (~instr.operand.push_pull.iffull_ifempty | osr_model.get_threshold_reached(item.osr_threshold));
        osr_do_load = (osr_autopull_fire | osr_pull_fire | (advance & (is_mov & (instr.operand.mov.dst == MOV_DST_OSR))));
        tx_en = (osr_autopull_fire | osr_pull_fire) & !item.empty;
        if (is_pull & ~instr.operand.push_pull.block & item.empty) begin
            osr_load_data = X;
        end else if (is_mov & (instr.operand.mov.dst == MOV_DST_OSR)) begin
            osr_load_data = mov_osr_data;
        end else begin
            osr_load_data = item.tx_data;
        end

        is_out_pc_load = (is_out & (instr.operand.out.dst == OUT_PC));
        is_mov_pc_load = (is_mov & (instr.operand.mov.dst == MOV_DST_PC));
        pc_load_req = jmp_taken | is_out_pc_load | is_mov_pc_load;

        for (int i = 0; i < NUM_IRQ; i++) begin
            if (is_irq & ({instr.operand.irq.clr, instr.operand.irq.wt} == 2'd1)) begin
                irq_clear[i] = item.en & irq_clr_req[i];
                irq_set[i] = item.en & irq_set_req[i];
            end else begin
                irq_clear[i] = advance & irq_clr_req[i];
                irq_set[i] = advance & irq_set_req[i];
            end
        end

        sideset_pin_count = item.sideset_opt ? item.sideset_count - 1 : item.sideset_count;
        if (sideset_valid) begin
            logic [2:0] temp;

            for (int i = 0; i < NUM_PINS; i++) begin
                temp = item.pin_sideset_base + i;
                if (i < sideset_pin_count) next_uio_out[temp] = sideset_data[i];
            end
        end
        // fill comb
        comb_output.next_X = next_X;
        comb_output.next_Y = next_Y;
        comb_output.next_uio_out = next_uio_out;
        comb_output.next_uio_oe = next_uio_oe;
        comb_output.pc_load_req = pc_load_req;
        comb_output.pc_load_data = pc_load_data;
        comb_output.delay = delay;
        comb_output.next_irq_set_issued = next_irq_set_issued;
        comb_output.isr_do_unload = isr_do_unload;
        comb_output.isr_do_load = isr_do_load;
        comb_output.isr_do_shift = isr_do_shift;
        comb_output.isr_load_data = isr_load_data;
        comb_output.isr_shift_amt = isr_shift_amt;
        comb_output.isr_shift_data_in = isr_shift_data_in;
        comb_output.osr_do_load = osr_do_load;
        comb_output.osr_do_shift = osr_do_shift;
        comb_output.osr_load_data = osr_load_data;
        comb_output.osr_shift_amt = osr_shift_amt;
        comb_output.tick = tick;
        comb_output.advance = advance;
        comb_output.blocked = blocked;
        comb_output.stall_autopush = stall_autopush;
        comb_output.stall_autopull = stall_autopull;
        comb_output.stall_push = stall_push;
        comb_output.stall_pull = stall_pull;
        comb_output.waiting = waiting;
        comb_output.stall_irq = stall_irq;
        comb_output.datapath_reset_n = datapath_reset_n;
        comb_output.tx_en = tx_en;
        comb_output.rx_en = rx_en;
        comb_output.rx_data = rx_data;
        comb_output.irq_set = irq_set;
        comb_output.irq_clear = irq_clear;
        return comb_output;
    endfunction

    function sm_model_predictions_t predict(sm_obs item);
        comb_t comb_signals = comb(item);

        sm_model_predictions_t predictions;
        predictions.pc_absolute = item.pc_base + pc_local;
        predictions.uio_out = uio_out;
        predictions.uio_oe = uio_oe;
        predictions.tx_en = comb_signals.tx_en;
        predictions.rx_en = comb_signals.rx_en;
        predictions.rx_data = comb_signals.rx_data;
        predictions.irq_set = comb_signals.irq_set;
        predictions.irq_clear = comb_signals.irq_clear;
        return predictions;
    endfunction

    // update model using derived combinational signals
    function void step(sm_obs item);
        comb_t comb_signals = comb(item);        

        // Apply: call submodel steps with derived control
        isr_model.step(comb_signals.datapath_reset_n, item.en, comb_signals.isr_do_unload, comb_signals.isr_do_load, comb_signals.isr_do_shift, item.isr_shiftdir, comb_signals.isr_load_data, comb_signals.isr_shift_amt, comb_signals.isr_shift_data_in);
        osr_model.step(comb_signals.datapath_reset_n, item.en, 1'b0, comb_signals.osr_do_load, comb_signals.osr_do_shift, item.osr_shiftdir, comb_signals.osr_load_data, comb_signals.osr_shift_amt, '0);
        clkdiv_model.step(comb_signals.datapath_reset_n, item.en, item.div_int, item.div_frac);

        // edge detection
        for (int i = 0; i < NUM_PINS; i++) begin
            if (prev_uio_in[i] == 1'b0 && item.uio_in[i] == 1'b1) begin
                rising_edge[i] = 1'b1;
            end else if (comb_signals.advance) begin
                rising_edge[i] = 1'b0;
            end
            
            if (prev_uio_in[i] == 1'b1 && item.uio_in[i] == 1'b0) begin
                falling_edge[i] = 1'b1;
            end else if (comb_signals.advance) begin
                falling_edge[i] = 1'b0;
            end
        end
        prev_uio_in = item.uio_in;

        // update registers
        irq_set_issued = comb_signals.next_irq_set_issued;

        if (!item.rst_n) begin
            reset(item.div_int);
        end else begin
            if (item.restart) begin
                X = '0;
                Y = '0;
                delay_count = '0;
                uio_oe = '0;
                uio_out = '0;
                irq_set_issued = '0;
                pc_local = '0;
                rising_edge = '0;
                falling_edge = '0;
                prev_uio_in = '0;
            end else if (comb_signals.advance) begin
                X = comb_signals.next_X;
                Y = comb_signals.next_Y;
                uio_oe = comb_signals.next_uio_oe;
                uio_out = comb_signals.next_uio_out;
                delay_count = comb_signals.delay;
                irq_set_issued = '0;
                pc_local = comb_signals.pc_load_req ? comb_signals.pc_load_data : (pc_local == item.wrap_top ? item.wrap_bottom : pc_local + 1); 
            end else if (comb_signals.tick && (delay_count != 0)) begin
                delay_count = delay_count - 1;
            end
        end
    endfunction
endclass