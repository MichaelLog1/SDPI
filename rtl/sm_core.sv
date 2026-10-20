module sm_core #(
    parameter int unsigned INSTRUCTION_WIDTH = 16,
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned IMEM_DEPTH = 64,
    parameter int unsigned SM_WINDOW = 32,
    parameter int unsigned NUM_PINS = 8,
    parameter bit USE_FRAC_DIV = 0,
    parameter int unsigned DIV_INT_WIDTH = 16,
    parameter int unsigned DIV_FRAC_WIDTH = 8,
    parameter int unsigned NUM_IRQ = 8
) (
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic restart,
    // instruction
    input logic [INSTRUCTION_WIDTH-1:0] instruction,
    output logic [$clog2(IMEM_DEPTH)-1:0] pc_absolute,
    // FIFO
    output logic tx_en,
    input logic [DATA_WIDTH-1:0] tx_data,
    output logic rx_en,
    output logic [DATA_WIDTH-1:0] rx_data,
    input logic empty,
    input logic full,
    // Pins
    input logic [NUM_PINS-1:0] uio_in,
    output logic [NUM_PINS-1:0] uio_out,
    output logic [NUM_PINS-1:0] uio_oe,
    // CLKDIV
    input logic [DIV_INT_WIDTH-1:0] div_int,
    input logic [DIV_FRAC_WIDTH-1:0] div_frac,
    // EXECCTRL
    input logic [$clog2(IMEM_DEPTH)-1:0] pc_base,
    input logic [$clog2(SM_WINDOW)-1:0] wrap_top,
    input logic [$clog2(SM_WINDOW)-1:0] wrap_bottom,
    input logic [2:0] jmp_pin,
    input logic [$clog2(6)-1:0] sideset_count,
    input logic sideset_opt,
    // SHIFTCTRL
    input logic osr_shiftdir,
    input logic isr_shiftdir,
    input logic autopull,
    input logic autopush,
    input logic [4:0] isr_threshold,
    input logic [4:0] osr_threshold,
    input logic delay_from_y,
    // PINCTRL
    input logic [2:0] pin_out_base,
    input logic [3:0] pin_out_count,
    input logic [2:0] pin_set_base,
    input logic [2:0] pin_set_count,
    input logic [2:0] pin_in_base,
    input logic [2:0] pin_sideset_base,
    // IRQ
    input logic [NUM_IRQ-1:0] irq_flags,
    output logic [NUM_IRQ-1:0] irq_clear,
    output logic [NUM_IRQ-1:0] irq_set
);

    // control signals
    logic advance;
    logic tick;
    logic blocked;
    logic waiting;
    logic [4:0] delay_count_r;
    logic datapath_reset_n;

    // decode outputs
    logic is_jmp;
    logic is_wait;
    logic is_in;
    logic is_out;
    logic is_push;
    logic is_pull;
    logic is_mov;
    logic is_irq;
    logic is_set;
    logic [2:0] jmp_cond;
    logic [4:0] jmp_offset;
    logic wait_pol;
    logic [1:0] wait_src;
    logic [4:0] wait_index;
    logic [2:0] in_src;
    logic in_crc;
    logic [4:0] in_count;
    logic [2:0] out_dst;
    logic out_crc;
    logic [4:0] out_count;
    logic p_iffull;
    logic p_block;
    logic [2:0] mov_dst;
    logic [1:0] mov_op;
    logic [2:0] mov_src;
    logic irq_clr;
    logic irq_wait;
    logic [2:0] irq_index;
    logic [2:0] set_dst;
    logic [4:0] set_imm;
    logic [4:0] delay;
    logic [4:0] sideset_data;
    logic sideset_valid;

    // ISR interface
    logic isr_do_shift;
    logic [$clog2(DATA_WIDTH):0] isr_shift_amt;
    logic [DATA_WIDTH-1:0] isr_shift_data_in;
    logic isr_do_load;
    logic [DATA_WIDTH-1:0] isr_load_data;
    logic isr_do_unload;
    logic [DATA_WIDTH-1:0] isr_unload_data;
    logic [$clog2(DATA_WIDTH):0] isr_count_out;
    logic isr_threshold_reached;
    

    // OSR interface
    logic osr_do_shift;
    logic [$clog2(DATA_WIDTH):0] osr_shift_amt;
    logic [DATA_WIDTH-1:0] osr_shift_data_out;
    logic osr_do_load;
    logic [DATA_WIDTH-1:0] osr_load_data;
    logic [DATA_WIDTH-1:0] osr_unload_data;
    logic [$clog2(DATA_WIDTH):0] osr_count_out;
    logic osr_threshold_reached;
    logic [DATA_WIDTH-1:0] osr_shift_data_in_UNUSED; // not used
    logic osr_do_unload_UNUSED; // not used
    
    // architectural state
    logic [DATA_WIDTH-1:0] X_r, next_X;
    logic [DATA_WIDTH-1:0] Y_r, next_Y;
    logic [NUM_PINS-1:0] uio_oe_r, next_uio_oe;
    logic [NUM_PINS-1:0] uio_out_r, next_uio_out;
    logic irq_set_issued_r, next_irq_set_issued;

    // pin sampling
    logic [NUM_PINS-1:0] uio_in_delay_r;
    logic [NUM_PINS-1:0] rising_edge_seen_r;
    logic [NUM_PINS-1:0] falling_edge_seen_r;

    // IRQ and PC
    logic [NUM_IRQ-1:0] irq_set_req;
    logic [NUM_IRQ-1:0] irq_clear_req;
    logic [$clog2(SM_WINDOW)-1:0] pc_local;
    logic pc_load_req;
    logic [$clog2(SM_WINDOW)-1:0] pc_load_data;
    logic is_out_pc_load;
    logic is_mov_pc_load;
    logic jmp_taken;

    // simplification signals
    logic stall_autopush;
    logic stall_autopull;
    logic stall_push;
    logic stall_pull;
    logic isr_autopush_fire;
    logic osr_autopull_fire;
    logic isr_push_fire;
    logic osr_pull_fire;
    logic [DATA_WIDTH-1:0] mov_osr_data; // for osr load data mux
    logic [DATA_WIDTH-1:0] mov_isr_data;
    logic [$clog2(6)-1:0] sideset_pin_count;

    logic stall_irq;

    // port maps
    clkdiv #(
        .USE_FRAC_DIV(USE_FRAC_DIV),
        .DIV_INT_WIDTH(DIV_INT_WIDTH),
        .DIV_FRAC_WIDTH(DIV_FRAC_WIDTH)
    ) u_clkdiv (
        .clk(clk),
        .rst_n(datapath_reset_n),
        .en(en),
        .div_int(div_int),
        .div_frac(div_frac),
        .tick(tick)
    );

    sm_pc #(
        .SM_WINDOW(SM_WINDOW),
        .IMEM_DEPTH(IMEM_DEPTH)
    ) u_sm_pc (
        .clk(clk),
        .rst_n(rst_n),
        .restart(restart),
        .advance(advance),
        .load_req(pc_load_req),
        .load_data(pc_load_data),
        .pc_base(pc_base),
        .wrap_top(wrap_top),
        .wrap_bottom(wrap_bottom),
        .pc_absolute(pc_absolute),
        .pc_local(pc_local)
    );

    sm_decode u_sm_decode (
        .instruction(instruction),
        .sideset_count(sideset_count),
        .sideset_opt(sideset_opt),
        .is_jmp(is_jmp),
        .is_wait(is_wait),
        .is_in(is_in), 
        .is_out(is_out),
        .is_push(is_push),
        .is_pull(is_pull),
        .is_mov(is_mov),
        .is_irq(is_irq),
        .is_set(is_set),
        .jmp_cond(jmp_cond),
        .jmp_offset(jmp_offset),
        .wait_pol(wait_pol),
        .wait_src(wait_src),
        .wait_index(wait_index),
        .in_src(in_src),
        .in_crc(in_crc),
        .in_count(in_count),
        .out_dst(out_dst),
        .out_crc(out_crc),
        .out_count(out_count),
        .p_iffull(p_iffull),
        .p_block(p_block),
        .mov_dst(mov_dst),
        .mov_op(mov_op),
        .mov_src(mov_src),
        .irq_clr(irq_clr),
        .irq_wait(irq_wait),
        .irq_index(irq_index),
        .set_dst(set_dst),
        .set_imm(set_imm),
        .delay(delay),
        .sideset_data(sideset_data),
        .sideset_valid(sideset_valid)
    );

    shift_reg #(
        .IS_INPUT(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_shift_reg_in (
        .clk(clk),
        .rst_n(datapath_reset_n),
        .en(en),
        .shift_dir(isr_shiftdir),
        .threshold(isr_threshold),
        .do_shift(isr_do_shift),
        .shift_amt(isr_shift_amt),
        .shift_data_in(isr_shift_data_in),
        .shift_data_out(),
        .do_load(isr_do_load),
        .load_data(isr_load_data),
        .do_unload(isr_do_unload),
        .unload_data(isr_unload_data),
        .count_out(isr_count_out),
        .threshold_reached(isr_threshold_reached)
    );

    shift_reg #(
        .IS_INPUT(0),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_shift_reg_out (
        .clk(clk),
        .rst_n(datapath_reset_n),
        .en(en),
        .shift_dir(osr_shiftdir),
        .threshold(osr_threshold),
        .do_shift(osr_do_shift),
        .shift_amt(osr_shift_amt),
        .shift_data_in(osr_shift_data_in_UNUSED),
        .shift_data_out(osr_shift_data_out),
        .do_load(osr_do_load),
        .load_data(osr_load_data),
        .do_unload(osr_do_unload_UNUSED),
        .unload_data(osr_unload_data),
        .count_out(osr_count_out),
        .threshold_reached(osr_threshold_reached)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // internal state
            X_r <= '0;
            Y_r <= '0;
            delay_count_r <= '0;
            irq_set_issued_r <= '0;
            // outputs
            uio_oe_r <= '0;
            uio_out_r <= '0;
        end else begin
            irq_set_issued_r <= next_irq_set_issued;

            if (restart) begin
                X_r <= '0;
                Y_r <= '0;
                delay_count_r <= '0;
                uio_oe_r <= '0;
                uio_out_r <= '0;
                irq_set_issued_r <= '0;
            end else if (advance) begin
                X_r <= next_X;
                Y_r <= next_Y;
                uio_oe_r <= next_uio_oe;
                uio_out_r <= next_uio_out;
                delay_count_r <= delay;
                irq_set_issued_r <= '0;
            end else if (tick && (delay_count_r != 0)) begin
                delay_count_r <= delay_count_r - 1;
            end
        end
    end

    // instruction logic
    always_comb begin
        // defaults
        jmp_taken = 1'b0;
        waiting = 1'b0;
        isr_shift_data_in = '0;
        pc_load_data = '0;
        is_out_pc_load = 1'b0;
        is_mov_pc_load = 1'b0;
        irq_clear_req = '0;
        irq_set_req = '0;
        mov_osr_data = '0;
        mov_isr_data = '0;
        stall_irq = '0;

        // register next
        next_X = X_r;
        next_Y = Y_r;
        next_uio_oe = uio_oe_r;
        next_uio_out = uio_out_r;
        next_irq_set_issued = irq_set_issued_r;

        unique0 case (1'b1)
            is_jmp: begin
                pc_load_data = jmp_offset;
                case (jmp_cond)
                    3'd0: begin
                        jmp_taken = 1'b1;
                    end

                    3'd1: begin
                        if (X_r == 0) begin
                            jmp_taken = 1'b1;
                        end
                    end

                    3'd2: begin
                        if (X_r != 0) begin
                            jmp_taken = 1'b1;
                            // this is post decrement
                            next_X = X_r - 1;
                        end
                    end

                    3'd3: begin
                        if (Y_r == 0) begin
                            jmp_taken = 1'b1;
                        end
                    end

                    3'd4: begin
                        if (Y_r != 0) begin
                            jmp_taken = 1'b1;
                            // this is post decrement
                            next_Y = Y_r - 1;
                        end
                    end

                    3'd5: begin
                        if (X_r != Y_r) begin
                            jmp_taken = 1'b1;
                        end
                    end

                    3'd6: begin
                        if (uio_in[jmp_pin]) begin
                            jmp_taken = 1'b1;
                        end
                    end

                    3'd7: begin
                        if (!osr_threshold_reached) begin
                            jmp_taken = 1'b1;
                        end
                    end
                endcase
            end
            
            is_wait: begin
                case (wait_src)
                    2'd0: begin
                        if (uio_in[wait_index[2:0]] != wait_pol) begin
                            waiting = 1'b1;
                        end
                    end

                    2'd1: begin
                        if (uio_in[(wait_index[2:0] + pin_in_base)] != wait_pol) begin
                            waiting = 1'b1;
                        end
                    end

                    2'd2: begin
                        if (irq_flags[wait_index[2:0]] != 1'b1) begin
                            waiting = 1'b1;
                        end else begin
                            irq_clear_req[wait_index[2:0]] = 1'b1;
                        end
                    end

                    2'd3: begin
                        if (wait_pol) begin
                            // wait until rising edge
                            if (!rising_edge_seen_r[wait_index[2:0]]) begin
                                waiting = 1'b1;
                            end
                        end else begin
                            // wait until falling edge
                            if (!falling_edge_seen_r[wait_index[2:0]]) begin
                                waiting = 1'b1;
                            end
                        end
                    end
                endcase
            end
            
            is_in: begin
                case (in_src)
                    3'd0: begin
                        logic [2:0] temp;
                        // in_count pins starting at in_base, wrapping.
                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_in_base + i;
                            isr_shift_data_in[i] = uio_in[temp];
                        end
                    end

                    3'd1: begin
                        // in_count low bits of X register
                        isr_shift_data_in = X_r;
                    end

                    3'd2: begin
                        // in_count low bits of Y register
                        isr_shift_data_in = Y_r;
                    end

                    3'd3: begin
                        // in_count zeros
                        isr_shift_data_in = '0;
                    end

                    3'd4: begin
                        // isr rotation
                        isr_shift_data_in = isr_unload_data;
                    end

                    3'd5: begin
                        // load from osr
                        isr_shift_data_in = osr_unload_data;
                    end

                    3'd6: begin
                        // capture
                    end

                    3'd7: begin
                        // crc
                    end
                endcase
            end
            
            is_out: begin
                case (out_dst)
                    3'd0: begin
                        logic [2:0] temp;

                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_out_base + i;
                            if (i < pin_out_count) next_uio_out[temp] = osr_shift_data_out[i];
                        end
                    end

                    3'd1: begin
                        next_X = osr_shift_data_out;
                    end

                    3'd2: begin
                        next_Y = osr_shift_data_out;
                    end

                    3'd3: begin
                        // skip output
                    end

                    3'd4: begin
                        logic [2:0] temp;

                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_out_base + i;
                            if (i < pin_out_count) next_uio_oe[temp] = osr_shift_data_out[i];
                        end
                    end

                    3'd5: begin
                        is_out_pc_load = 1'b1;
                        pc_load_data = osr_shift_data_out[$clog2(SM_WINDOW)-1:0];
                    end

                    3'd6: begin
                        isr_shift_data_in = osr_shift_data_out;
                    end

                    3'd7: begin

                    end
                endcase
            end
            
            is_mov: begin
                logic [DATA_WIDTH-1:0] temp_src;
                logic [DATA_WIDTH-1:0] temp_product;

                case (mov_src)
                    3'd0: begin
                        // pins, start at pin_in_base and wrap if needed
                        logic [2:0] temp;
                        temp_src = '0;
                        // in_count pins starting at in_base, wrapping.
                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_in_base + i;
                            temp_src[i] = uio_in[temp];
                        end
                    end

                    3'd1: begin
                        // X
                        temp_src = X_r;
                    end

                    3'd2: begin
                        // Y
                        temp_src = Y_r;
                    end
            
                    3'd3: begin
                        // null
                        temp_src = '0;
                    end

                    3'd4: begin
                        // exec (meaningless as src)
                        temp_src = '0;
                    end

                    3'd5: begin
                        // pc
                        temp_src = pc_local;
                    end

                    3'd6: begin
                        // isr
                        temp_src = isr_unload_data;
                    end

                    3'd7: begin
                        // osr
                        temp_src = osr_unload_data;
                    end
                endcase

                case (mov_op)
                    2'd0: begin
                        // no change
                        temp_product = temp_src;
                    end

                    2'd1: begin
                        // bitwise invert
                        temp_product = ~temp_src;
                    end
                    
                    2'd2: begin
                        // bit reverse
                        for (int i = 0; i < DATA_WIDTH; i++) begin
                            temp_product[i] = temp_src[DATA_WIDTH-1-i];
                        end
                    end

                    2'd3: begin
                        // nothing assigned, treat as no change
                        temp_product = temp_src;
                    end
                endcase

                case (mov_dst)
                    3'd0: begin
                        // pins
                        logic [2:0] temp;

                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_out_base + i;
                            if (i < pin_out_count) next_uio_out[temp] = temp_product[i];
                        end              
                    end

                    3'd1: begin
                        // X
                        next_X = temp_product;
                    end

                    3'd2: begin
                        // Y
                        next_Y = temp_product;
                    end
            
                    3'd3: begin
                        // null (N/A for dst)
                    end

                    3'd4: begin
                        // exec
                        // TODO: exec paths
                    end

                    3'd5: begin
                        // pc
                        is_mov_pc_load = 1'b1;
                        pc_load_data = temp_product[$clog2(SM_WINDOW)-1:0];
                    end

                    3'd6: begin
                        // isr
                        mov_isr_data = temp_product;
                    end

                    3'd7: begin
                        // osr
                        mov_osr_data = temp_product;
                    end
                endcase
            end
            
            is_irq: begin
                case ({irq_clr, irq_wait})
                    2'd0: begin
                        // set flag and continue
                        irq_set_req[irq_index] = 1'b1;
                    end

                    2'd1: begin
                        // set flag and wait for clear
                        if (!irq_set_issued_r) begin
                            irq_set_req[irq_index] = 1'b1;
                            next_irq_set_issued = 1'b1;
                            stall_irq = 1'b1;
                        end else if (irq_set_issued_r & !irq_flags[irq_index]) begin
                            // irq_set_issued_r gets cleared on advance
                            stall_irq = 1'b0;
                        end else begin
                            // assert something that contributes to blocked
                            stall_irq = 1'b1;
                        end
                    end

                    2'd2: begin
                        // clear flag and continue
                        irq_clear_req[irq_index] = 1'b1;
                    end

                    2'd3: begin
                        // no op
                    end
                endcase
            end
            
            is_set: begin
                case (set_dst)
                    3'd0: begin
                        // pins
                        logic [2:0] temp;

                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_set_base + i;
                            if (i < pin_set_count) begin
                                if (i < 5) next_uio_out[temp] = set_imm[i];
                                else next_uio_out[temp] = 1'b0;
                            end
                        end
                    end

                    3'd1: begin
                        // X
                        next_X = set_imm;
                    end

                    3'd2: begin
                        // Y
                        next_Y = set_imm;
                    end

                    3'd4: begin
                        // pindirs
                        logic [2:0] temp;

                        for (int i = 0; i < NUM_PINS; i++) begin
                            temp = pin_set_base + i;
                            if (i < pin_set_count) begin
                                if (i < 5) next_uio_oe[temp] = set_imm[i];
                                else next_uio_oe[temp] = 1'b0;
                            end
                        end
                    end

                    default: begin
                        // all else are no ops
                    end
                endcase
            end
        endcase

        // sideset logic, applied orthagonally
        if (sideset_valid) begin
            logic [2:0] temp;

            for (int i = 0; i < NUM_PINS; i++) begin
                temp = pin_sideset_base + i;
                if (i < sideset_pin_count) next_uio_out[temp] = sideset_data[i];
            end
        end
    end

    // control comb
    assign advance = tick & (delay_count_r == 0) & ~blocked;
    assign stall_push = is_push & p_block & full & (~p_iffull | isr_threshold_reached);
    assign stall_pull = is_pull & p_block & empty & (~p_iffull | osr_threshold_reached);
    assign stall_autopush = (is_in | (is_out & (out_dst == 3'd6)) | (is_mov & (mov_dst == 3'd6))) & autopush & isr_threshold_reached;
    assign stall_autopull = is_out & autopull & osr_threshold_reached;
    assign blocked = waiting | stall_autopush | stall_autopull | stall_push | stall_pull | stall_irq;
    assign datapath_reset_n = rst_n & !restart;

    // shift registers
    assign isr_do_shift = advance & (is_in | (is_out & (out_dst == 3'd6)));
    assign osr_do_shift = advance & is_out;
    assign isr_shift_amt = (is_out & (out_dst == 3'd6)) ? out_count : in_count;
    assign osr_shift_amt = out_count;

    // autopush/rx
    assign isr_autopush_fire = en & autopush & isr_threshold_reached & !full;
    assign isr_push_fire = advance & is_push & (~p_iffull | isr_threshold_reached);
    assign isr_do_unload = isr_autopush_fire | isr_push_fire;
    assign rx_en = (isr_autopush_fire | isr_push_fire) & !full;
    assign rx_data = isr_unload_data;

    assign isr_do_load = advance & (is_mov & (mov_dst == 3'd6));
    assign isr_load_data = mov_isr_data;

    // autopull/tx
    assign osr_autopull_fire = en & autopull & osr_threshold_reached & !empty & !(is_mov & (mov_dst == 3'd7));
    assign osr_pull_fire = advance & is_pull & (~p_iffull | osr_threshold_reached);
    assign osr_do_load = (osr_autopull_fire | osr_pull_fire | (advance & (is_mov & (mov_dst == 3'd7))));
    assign tx_en = (osr_autopull_fire | osr_pull_fire) & !empty;
    assign osr_load_data = (is_pull & ~p_block & empty) ? X_r : 
                           (is_mov & (mov_dst == 3'd7)) ? mov_osr_data :
                           tx_data;
    
    // pc
    assign pc_load_req = jmp_taken | is_out_pc_load | is_mov_pc_load;

    // register outputs
    assign uio_oe = uio_oe_r;
    assign uio_out = uio_out_r;
    assign irq_clear = (is_irq & ({irq_clr, irq_wait} == 2'd1)) ? {NUM_IRQ{en}} & irq_clear_req : {NUM_IRQ{advance}} & irq_clear_req;
    assign irq_set = (is_irq & ({irq_clr, irq_wait} == 2'd1)) ? {NUM_IRQ{en}} & irq_set_req : {NUM_IRQ{advance}} & irq_set_req;

    // sideset
    assign sideset_pin_count = sideset_opt ? sideset_count - 1 : sideset_count;

    // unused inputs
    assign osr_shift_data_in_UNUSED = '0;
    assign osr_do_unload_UNUSED = 1'b0;

    // uio_in delay for edge transition detection
    always_ff @(posedge clk) begin
        if (!datapath_reset_n) begin
          uio_in_delay_r <= '0;
          rising_edge_seen_r <= '0;
          falling_edge_seen_r <= '0; 
        end else begin
            uio_in_delay_r <= uio_in;

            for (int i = 0; i < NUM_PINS; i++) begin
                if (uio_in[i] == 1'b1 && uio_in_delay_r[i] == 1'b0) begin
                    rising_edge_seen_r[i] <= 1'b1;
                end else if (advance) begin
                    rising_edge_seen_r[i] <= 1'b0;
                end

                if (uio_in[i] == 1'b0 && uio_in_delay_r[i] == 1'b1) begin
                    falling_edge_seen_r[i] <= 1'b1;
                end else if (advance) begin
                    falling_edge_seen_r[i] <= 1'b0;
                end
            end
        end
    end
    
endmodule