package sm_core_isa_pkg;
    // decode enums
    // JMP
    typedef enum logic [2:0] {
        JMP_ALWAYS = 3'd0,
        JMP_X_EQ_ZERO = 3'd1,
        JMP_X_NE_ZERO = 3'd2,
        JMP_Y_EQ_ZERO = 3'd3,
        JMP_Y_NE_ZERO = 3'd4,
        JMP_X_NE_Y = 3'd5,
        JMP_PIN = 3'd6,
        JMP_OSR = 3'd7
    } jmp_cond_t;

    typedef logic [4:0] jmp_offset_t;

    typedef struct packed {
        jmp_cond_t cond;
        jmp_offset_t offset;
    } jmp_operand_t;

    // WAIT
    typedef logic wait_pol_t;

    typedef enum logic [1:0] {
        WAIT_PIN_ABS = 2'd0,
        WAIT_PIN_MAP = 2'd1,
        WAIT_IRQ = 2'd2,
        WAIT_EDGE = 2'd3
    } wait_src_t;

    typedef logic [4:0] wait_index_t;

    typedef struct packed {
        wait_pol_t pol;
        wait_src_t src;
        wait_index_t index;
    } wait_operand_t;

    // IN
    typedef enum logic [2:0] {
        IN_PINS = 3'd0,
        IN_X = 3'd1,
        IN_Y = 3'd2,
        IN_NULL = 3'd3,
        IN_ISR = 3'd4,
        IN_OSR = 3'd5,
        IN_CAPTURE = 3'd6,
        IN_CRC = 3'd7
    } in_src_t;

    typedef logic in_crc_t;

    typedef logic [3:0] in_count_t;

    typedef struct packed {
        in_src_t src;
        in_crc_t crc_en;
        in_count_t count;
    } in_operand_t;

    // OUT
    typedef enum logic [2:0] {
        OUT_PINS = 3'd0,
        OUT_X = 3'd1,
        OUT_Y = 3'd2,
        OUT_NULL = 3'd3,
        OUT_PINDIRS = 3'd4,
        OUT_PC = 3'd5,
        OUT_ISR = 3'd6,
        OUT_EXEC = 3'd7
    } out_dst_t;

    typedef logic out_crc_t;

    typedef logic [3:0] out_count_t;

    typedef struct packed {
        out_dst_t dst;
        out_crc_t crc_en;
        out_count_t count;
    } out_operand_t;

    // PUSH/PULL
    typedef logic push_pull_switch_t;

    typedef logic push_pull_cond_t;

    typedef logic push_pull_block_t;

    typedef struct packed {
        push_pull_switch_t push_pull;
        push_pull_cond_t iffull_ifempty;
        push_pull_block_t block;
        logic [4:0] dont_care;
    } push_pull_operand_t;

    // MOV
    typedef enum logic [2:0] {
        MOV_SRC_PINS = 3'd0,
        MOV_SRC_X = 3'd1,
        MOV_SRC_Y = 3'd2,
        MOV_SRC_NULL = 3'd3,
        MOV_SRC_EXEC = 3'd4,
        MOV_SRC_PC = 3'd5,
        MOV_SRC_ISR = 3'd6,
        MOV_SRC_OSR = 3'd7
    } mov_src_t;

    typedef enum logic [1:0] {
        MOV_OP_NONE = 2'd0,
        MOV_OP_INVERT = 2'd1,
        MOV_OP_REVERSE = 2'd2,
        MOV_OP_RESERVED = 2'd3
    } mov_op_t;

    typedef enum logic [2:0] {
        MOV_DST_PINS = 3'd0,
        MOV_DST_X = 3'd1,
        MOV_DST_Y = 3'd2,
        MOV_DST_NULL = 3'd3,
        MOV_DST_EXEC = 3'd4,
        MOV_DST_PC = 3'd5,
        MOV_DST_ISR = 3'd6,
        MOV_DST_OSR = 3'd7
    } mov_dst_t;

    typedef struct packed {
        mov_dst_t dst;
        mov_op_t op;
        mov_src_t src;
    } mov_operand_t;

    // IRQ
    typedef logic irq_clr_t;

    typedef logic irq_wait_t;

    typedef logic [2:0] irq_index_t;

    typedef struct packed {
        irq_clr_t clr;
        irq_wait_t wt;
        logic [2:0] dont_care;
        irq_index_t index;
    } irq_operand_t;

    // SET
    typedef enum logic [2:0] {
        SET_PINS = 3'd0,
        SET_X = 3'd1,
        SET_Y = 3'd2,
        SET_NOP3 = 3'd3,
        SET_PINDIRS = 3'd4,
        SET_NOP5 = 3'd5,
        SET_NOP6 = 3'd6,
        SET_NOP7 = 3'd7
    } set_dst_t;

    typedef logic [4:0] set_imm_t;

    typedef struct packed {
        set_dst_t dst;
        set_imm_t imm;
    } set_operand_t;
    
    // outer word
    typedef enum logic [2:0] {
        JMP = 3'd0,
        WAIT = 3'd1,
        IN = 3'd2,
        OUT = 3'd3,
        PUSH_PULL = 3'd4,
        MOV = 3'd5,
        IRQ = 3'd6,
        SET = 3'd7
    } opcode_t;

    typedef logic [4:0] delay_sideset_t;

    typedef union packed {
        jmp_operand_t jmp;
        wait_operand_t wt;
        in_operand_t in;
        out_operand_t out;
        push_pull_operand_t push_pull;
        mov_operand_t mov;
        irq_operand_t irq;
        set_operand_t set;
        logic [7:0] raw;
    } operand_t;

    typedef struct packed {
        opcode_t opcode;
        delay_sideset_t delay_sideset;
        operand_t operand;
    } instruction_t;

    typedef struct {
        instruction_t instruction;
        logic [4:0] delay;
        logic [4:0] sideset_data;
        logic sideset_valid;
    } decoded_instruction_t;

    // encode functions
    function automatic delay_sideset_t delay_sideset_helper(input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        delay_sideset_t result = '0;
        // check for errors
        if (sideset_count > 5) begin
            
        end

        if (sideset_opt) begin
            result[4] = sideset_en;
            if (sideset_count == 0) begin
                result[3:0] = delay[3:0];
            end else if (sideset_count == 1) begin
                result[3:0] = delay[3:0]; 
            end else if (sideset_count == 2) begin
                result[3:0] = { sideset_data[0], delay[2:0] };
            end else if (sideset_count == 3) begin
                result[3:0] = { sideset_data[1:0], delay[1:0] };
            end else if (sideset_count == 4) begin
                result[3:0] = { sideset_data[2:0], delay[0] };
            end else if (sideset_count == 5) begin
                result[3:0] = sideset_data[3:0];
            end
        end else begin
            if (sideset_count == 0) begin
                result[4:0] = delay[4:0];
            end else if (sideset_count == 1) begin
                result[4:0] = { sideset_data[0], delay[3:0] }; 
            end else if (sideset_count == 2) begin
                result[4:0] = { sideset_data[1:0], delay[2:0] };
            end else if (sideset_count == 3) begin
                result[4:0] = { sideset_data[2:0], delay[1:0] };
            end else if (sideset_count == 4) begin
                result[4:0] = { sideset_data[3:0], delay[0] };
            end else if (sideset_count == 5) begin
                result[4:0] = sideset_data[4:0];
            end
        end
        return result;
    endfunction

    function automatic instruction_t assembler(input opcode_t opcode, input delay_sideset_t delay_sideset, input operand_t operand);
        return { opcode, delay_sideset, operand };
    endfunction

    function automatic instruction_t encode_jmp(input jmp_cond_t cond, input jmp_offset_t offset, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        jmp_operand_t operand = '{cond, offset};
        return assembler(JMP, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_wait(input wait_pol_t pol, input wait_src_t src, input wait_index_t index, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        wait_operand_t operand = '{pol, src, index};
        return assembler(WAIT, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_in(input in_src_t src, input in_crc_t crc_en, input in_count_t count, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        in_operand_t operand = '{src, crc_en, count};
        return assembler(IN, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_out(input out_dst_t dst, input out_crc_t crc_en, input out_count_t count, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        out_operand_t operand = '{dst, crc_en, count};
        return assembler(OUT, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_push_pull(input push_pull_switch_t switch, input push_pull_cond_t cond, input push_pull_block_t block, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        push_pull_operand_t operand = '{switch, cond, block, 5'd0};
        return assembler(PUSH_PULL, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_mov(input mov_dst_t dst, input mov_op_t op, input mov_src_t src, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        mov_operand_t operand = '{dst, op, src};
        return assembler(MOV, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_irq(input irq_clr_t clr, input irq_wait_t wt, input irq_index_t index, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        irq_operand_t operand = '{clr, wt, 3'd0, index};
        return assembler(IRQ, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    function automatic instruction_t encode_set(input set_dst_t dst, input set_imm_t imm, input int delay, input int sideset_data, input bit sideset_en, input int sideset_count, input bit sideset_opt);
        set_operand_t operand = '{dst, imm};
        return assembler(SET, delay_sideset_helper(delay, sideset_data, sideset_en, sideset_count, sideset_opt), operand);
    endfunction

    // decode
    function automatic decoded_instruction_t decode(input logic [15:0] data, input logic [4:0] sideset_count, input logic sideset_opt);
        instruction_t inst = instruction_t'(data);
        int delay;
        int sideset_data;
        logic valid;
        decoded_instruction_t result;
        if (sideset_opt) begin
            if (sideset_count == 0) begin
                sideset_data = 0;
                delay = inst.delay_sideset[4:0];
                valid = 0;
            end else if (sideset_count == 1) begin
                sideset_data = 0;
                delay = inst.delay_sideset[3:0];
                valid = inst.delay_sideset[4];
            end else if (sideset_count == 2) begin
                sideset_data = inst.delay_sideset[3];
                delay = inst.delay_sideset[2:0];
                valid = inst.delay_sideset[4];
            end else if (sideset_count == 3) begin
                sideset_data = inst.delay_sideset[3:2];
                delay = inst.delay_sideset[1:0];
                valid = inst.delay_sideset[4];
            end else if (sideset_count == 4) begin
                sideset_data = inst.delay_sideset[3:1];
                delay = inst.delay_sideset[0];
                valid = inst.delay_sideset[4];
            end else if (sideset_count == 5) begin
                sideset_data = inst.delay_sideset[3:0];
                delay = 0;
                valid = inst.delay_sideset[4];
            end else begin
                sideset_data = 0;
                delay = 0;
                valid = 0;
            end
        end else begin
            if (sideset_count == 0) begin
                sideset_data = 0;
                delay = inst.delay_sideset[4:0];
                valid = 1'b0;
            end else if (sideset_count == 1) begin
                sideset_data = inst.delay_sideset[4];
                delay = inst.delay_sideset[3:0];
                valid = 1'b1; 
            end else if (sideset_count == 2) begin
                sideset_data = inst.delay_sideset[4:3];
                delay = inst.delay_sideset[2:0];
                valid = 1'b1; 
            end else if (sideset_count == 3) begin
                sideset_data = inst.delay_sideset[4:2];
                delay = inst.delay_sideset[1:0];
                valid = 1'b1; 
            end else if (sideset_count == 4) begin
                sideset_data = inst.delay_sideset[4:1];
                delay = inst.delay_sideset[0];
                valid = 1'b1; 
            end else if (sideset_count == 5) begin
                sideset_data = inst.delay_sideset[4:0];
                delay = 0;
                valid = 1'b1; 
            end else begin
                sideset_data = 0;
                delay = 0;
                valid = 1'b0; 
            end
        end
        
        result = '{inst, delay, sideset_data, valid};
        return result;
    endfunction

    // TODO: Fininsh this exhaustively.
    function automatic string disassemble(input logic [15:0] data, input logic [4:0] sideset_count, input logic sideset_opt);
        decoded_instruction_t decoded_instr = decode(data, sideset_count, sideset_opt);
        opcode_t opcode = decoded_instr.instruction.opcode;
        operand_t operand = decoded_instr.instruction.operand;
        string result = "";

        int adjusted_count;

        case (opcode)
            JMP: begin // JMP
                case (operand.jmp.cond)
                    JMP_ALWAYS:    result = $sformatf("JMP %0d", operand.jmp.offset);
                    JMP_X_EQ_ZERO: result = $sformatf("JMP !X, %0d", operand.jmp.offset);
                    JMP_X_NE_ZERO: result = $sformatf("JMP X--, %0d", operand.jmp.offset);
                    JMP_Y_EQ_ZERO: result = $sformatf("JMP !Y, %0d", operand.jmp.offset);
                    JMP_Y_NE_ZERO: result = $sformatf("JMP Y--, %0d", operand.jmp.offset);
                    JMP_X_NE_Y:    result = $sformatf("JMP X!=Y, %0d", operand.jmp.offset);
                    JMP_PIN:       result = $sformatf("JMP PIN, %0d", operand.jmp.offset);
                    JMP_OSR:       result = $sformatf("JMP !OSRE, %0d", operand.jmp.offset);
                endcase
            end

            WAIT: begin // WAIT
                case (operand.wt.src)
                    WAIT_PIN_ABS: result = $sformatf("WAIT %0d GPIO, %0d", operand.wt.pol, operand.wt.index[2:0]);
                    WAIT_PIN_MAP: result = $sformatf("WAIT %0d PIN, %0d", operand.wt.pol, operand.wt.index[2:0]);
                    WAIT_IRQ:     result = $sformatf("WAIT %0d IRQ, %0d", operand.wt.pol, operand.wt.index[2:0]);
                    WAIT_EDGE:    result = $sformatf("WAIT %0d EDGE, %0d", operand.wt.pol, operand.wt.index[2:0]);
                endcase
            end

            IN: begin // IN
                adjusted_count = (operand.in.count == 0) ? 16 : operand.in.count;
                case (operand.in.src)
                    IN_PINS:    result = $sformatf("IN PINS, %0d", adjusted_count);
                    IN_X:       result = $sformatf("IN X, %0d", adjusted_count);
                    IN_Y:       result = $sformatf("IN Y, %0d", adjusted_count);
                    IN_NULL:    result = $sformatf("IN NULL, %0d", adjusted_count);
                    IN_ISR:     result = $sformatf("IN ISR, %0d", adjusted_count);
                    IN_OSR:     result = $sformatf("IN OSR, %0d", adjusted_count);
                    IN_CAPTURE: result = $sformatf("IN CAPTURE, %0d", adjusted_count); // unimplemented
                    IN_CRC:     result = $sformatf("IN CRC, %0d", adjusted_count); // unimplemented
                endcase

                if (operand.in.crc_en) begin
                    result = $sformatf("%s, crc", result);
                end
            end

            OUT: begin // OUT
                adjusted_count = (operand.out.count == 0) ? 16 : operand.out.count;
                case (operand.out.dst)
                    OUT_PINS:    result = $sformatf("OUT PINS, %0d", adjusted_count);
                    OUT_X:       result = $sformatf("OUT X, %0d", adjusted_count);
                    OUT_Y:       result = $sformatf("OUT Y, %0d", adjusted_count);
                    OUT_NULL:    result = $sformatf("OUT NULL, %0d", adjusted_count);
                    OUT_PINDIRS: result = $sformatf("OUT PINDIRS, %0d", adjusted_count);
                    OUT_PC:      result = $sformatf("OUT PC, %0d", adjusted_count);
                    OUT_ISR:     result = $sformatf("OUT ISR, %0d", adjusted_count);
                    OUT_EXEC:    result = $sformatf("OUT EXEC, %0d", adjusted_count);
                endcase

                if (operand.out.crc_en) begin
                    result = $sformatf("%s, crc", result);
                end
            end

            PUSH_PULL: begin // PUSH/PULL
                if (operand.push_pull.push_pull) begin // PULL
                    result = $sformatf("PULL");
                    if (operand.push_pull.iffull_ifempty) begin
                        result = $sformatf("%s IFEMPTY", result);
                    end

                    if (!operand.push_pull.block) begin
                        result = $sformatf("%s NOBLOCK", result);
                    end
                end else begin // PUSH
                    result = $sformatf("PUSH");
                    if (operand.push_pull.iffull_ifempty) begin
                        result = $sformatf("%s IFFULL", result);
                    end

                    if (!operand.push_pull.block) begin
                        result = $sformatf("%s NOBLOCK", result);
                    end
                end
            end

            MOV: begin // MOV
                case (operand.mov.dst)
                    MOV_DST_PINS: result = $sformatf("MOV PINS,");
                    MOV_DST_X:    result = $sformatf("MOV X,");
                    MOV_DST_Y:    result = $sformatf("MOV Y,");
                    MOV_DST_NULL: result = $sformatf("MOV NULL,"); // meaningless
                    MOV_DST_EXEC: result = $sformatf("MOV EXEC,");
                    MOV_DST_PC:   result = $sformatf("MOV PC,");
                    MOV_DST_ISR:  result = $sformatf("MOV ISR,");
                    MOV_DST_OSR:  result = $sformatf("MOV OSR,");
                endcase

                case (operand.mov.op)
                    MOV_OP_NONE:     result = $sformatf("%s ", result);
                    MOV_OP_INVERT:   result = $sformatf("%s ~", result);
                    MOV_OP_REVERSE:  result = $sformatf("%s ::", result);
                    MOV_OP_RESERVED: result = $sformatf("%s ==", result);
                endcase

                case (operand.mov.src)
                    MOV_SRC_PINS: result = $sformatf("%sPINS", result);
                    MOV_SRC_X:    result = $sformatf("%sX", result);
                    MOV_SRC_Y:    result = $sformatf("%sY", result);
                    MOV_SRC_NULL: result = $sformatf("%sNULL", result);
                    MOV_SRC_EXEC: result = $sformatf("%sEXEC", result);
                    MOV_SRC_PC:   result = $sformatf("%sPC", result);
                    MOV_SRC_ISR:  result = $sformatf("%sISR", result);
                    MOV_SRC_OSR:  result = $sformatf("%sOSR", result);
                endcase
            end

            IRQ: begin // IRQ
                result = $sformatf("IRQ");

                if (operand.irq.clr) begin
                    result = $sformatf("%s CLEAR", result);
                end

                if (operand.irq.wt) begin
                    result = $sformatf("%s WAIT", result);
                end

                result = $sformatf("%s %0d", result, operand.irq.index);

                // overwrite if nop
                if (operand.irq.clr && operand.irq.wt) begin
                    result = $sformatf("IRQ NOP %0d", operand.irq.index);
                end
            end

            SET: begin // SET
                case (operand.set.dst)
                    SET_PINS:    result = $sformatf("SET PINS, %0d", operand.set.imm);
                    SET_X:       result = $sformatf("SET X, %0d", operand.set.imm);
                    SET_Y:       result = $sformatf("SET Y, %0d", operand.set.imm);
                    SET_NOP3:    result = $sformatf("SET NOP3, %0d", operand.set.imm);
                    SET_PINDIRS: result = $sformatf("SET PINDIRS, %0d", operand.set.imm);
                    SET_NOP5:    result = $sformatf("SET NOP5, %0d", operand.set.imm);
                    SET_NOP6:    result = $sformatf("SET NOP6, %0d", operand.set.imm);
                    SET_NOP7:    result = $sformatf("SET NOP7, %0d", operand.set.imm);
                endcase
            end
        endcase

        // apply delay and sideset_data
        if ((!sideset_opt && sideset_count > 0) || (sideset_opt && decoded_instr.sideset_valid)) begin
            result = $sformatf("%s side %0d", result, decoded_instr.sideset_data);
        end

        if (decoded_instr.delay > 0) begin
            result = $sformatf("%s [%0d]", result, decoded_instr.delay);
        end

        return result;
    endfunction
endpackage
