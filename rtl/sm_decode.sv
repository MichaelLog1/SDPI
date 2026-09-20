module sm_decode (
    input logic [15:0] instruction,
    input logic [$clog2(6)-1:0] sideset_count,
    input logic sideset_opt,
    // instruction bools
    output logic is_jmp,
    output logic is_wait,
    output logic is_in, 
    output logic is_out,
    output logic is_push,
    output logic is_pull,
    output logic is_mov,
    output logic is_irq,
    output logic is_set,
    // operand signals
    output logic [2:0] jmp_cond,
    output logic [4:0] jmp_offset,
    output logic wait_pol,
    output logic [1:0] wait_src,
    output logic [4:0] wait_index,
    output logic [2:0] in_src,
    output logic in_crc,
    output logic [4:0] in_count,
    output logic [2:0] out_dst,
    output logic out_crc,
    output logic [4:0] out_count,
    output logic p_iffull,
    output logic p_block,
    output logic [2:0] mov_dst,
    output logic [1:0] mov_op,
    output logic [2:0] mov_src,
    output logic irq_clr,
    output logic irq_wait,
    output logic [2:0] irq_index,
    output logic [2:0] set_dst,
    output logic [4:0] set_imm,
    // timing/sideset signals
    output logic [4:0] delay,
    output logic [4:0] sideset_data,
    output logic sideset_valid
);

    logic [2:0] opcode;
    logic [4:0] delay_sideset;
    logic [7:0] operand;

    assign opcode = instruction[15:13];
    assign delay_sideset = instruction[12:8];
    assign operand = instruction[7:0];
    
    always_comb begin
        is_jmp = 1'b0;
        is_wait = 1'b0;
        is_in = 1'b0;
        is_out = 1'b0;
        is_pull = 1'b0;
        is_push = 1'b0;
        is_mov = 1'b0;
        is_irq = 1'b0;
        is_set = 1'b0;

        jmp_cond = '0;
        jmp_offset = '0;
        wait_pol = '0;
        wait_src = '0;
        wait_index = '0;
        in_src = '0;
        in_crc = '0;
        in_count = '0;
        out_dst = '0;
        out_crc = '0;
        out_count = '0;
        p_iffull = '0;
        p_block = '0;
        mov_dst = '0;
        mov_op = '0;
        mov_src = '0;
        irq_clr = '0;
        irq_wait = '0;
        irq_index = '0;
        set_dst = '0;
        set_imm = '0;

        case (opcode)
            3'b000: begin
                is_jmp = 1'b1;
                jmp_cond = operand[7:5];
                jmp_offset = operand[4:0];
            end

            3'b001: begin
                is_wait = 1'b1;
                wait_pol = operand[7];
                wait_src = operand[6:5];
                wait_index = operand[4:0];
            end

            3'b010: begin
                is_in = 1'b1;
                in_src = operand[7:5];
                in_crc = operand[4];
                if (operand[3:0] == 0) begin
                    in_count = 5'd16;
                end else begin
                    in_count = { 1'b0, operand[3:0] };
                end
            end

            3'b011: begin
                is_out = 1'b1;
                out_dst = operand[7:5];
                out_crc = operand[4];
                if (operand[3:0] == 0) begin
                    out_count = 5'd16;
                end else begin
                    out_count = { 1'b0, operand[3:0] };
                end
            end

            3'b100: begin
                is_pull = operand[7];
                is_push = !operand[7];
                p_iffull = operand[6];
                p_block = operand[5];
            end

            3'b101: begin
                is_mov = 1'b1;
                mov_dst = operand[7:5];
                mov_op = operand[4:3];
                mov_src = operand[2:0];
            end

            3'b110: begin
                is_irq = 1'b1;
                irq_clr = operand[7];
                irq_wait = operand[6];
                irq_index = operand[2:0];
            end

            3'b111: begin
                is_set = 1'b1;
                set_dst = operand[7:5];
                set_imm = operand[4:0];
            end
        endcase

        if (sideset_opt) begin
            if (sideset_count == 0 ) begin
                sideset_valid = 1'b0;
                sideset_data = '0;
                delay = delay_sideset[4:0];
            end else if (sideset_count == 1) begin
                sideset_valid = delay_sideset[4];
                sideset_data = '0;
                delay = delay_sideset[3:0];
            end else begin
                sideset_valid = delay_sideset[4] && (sideset_count != 6 && sideset_count != 7);
                sideset_data = delay_sideset[3:0] >> (5 - sideset_count);
                delay = delay_sideset & ((5'b1 << (5 - sideset_count)) - 1);
            end
        end else begin
            sideset_valid = (sideset_count != 0 && sideset_count != 6 && sideset_count != 7);
            sideset_data = delay_sideset >> (5 - sideset_count);
            delay = delay_sideset & ((5'b1 << (5 - sideset_count)) - 1);

        end
    end

endmodule