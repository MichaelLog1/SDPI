import sm_core_isa_pkg::*;

class sm_instruction;
    // opcode
    rand opcode_t opcode;
    // jmp
    rand jmp_cond_t jmp_cond;
    rand jmp_offset_t jmp_offset;
    // wait
    rand wait_pol_t wait_pol;
    rand wait_src_t wait_src;
    rand wait_index_t wait_index;
    // in
    rand in_src_t in_src;
    rand in_crc_t in_crc;
    rand in_count_t in_count;
    // out
    rand out_dst_t out_dst;
    rand out_crc_t out_crc;
    rand out_count_t out_count;
    // push/pull
    rand push_pull_switch_t push_pull_switch;
    rand push_pull_cond_t push_pull_cond;
    rand push_pull_block_t push_pull_block;
    rand logic [4:0] push_pull_dont_care;
    // mov
    rand mov_dst_t mov_dst;
    rand mov_op_t mov_op;
    rand mov_src_t mov_src;
    // irq
    rand irq_clr_t irq_clr;
    rand irq_wait_t irq_wait;
    rand logic [2:0] irq_dont_care;
    rand irq_index_t irq_index;
    // set
    rand set_dst_t set_dst;
    rand set_imm_t set_imm;
    // delay
    rand logic [4:0] delay;
    // sideset data
    rand logic [4:0] sideset_data;
    // sideset valid
    rand logic sideset_valid;
    // need a cfg handle for encode function
    sm_config cfg;

    // constraints
    constraint c_mov_reserved {
        mov_op != MOV_OP_RESERVED;
    }

    constraint c_in_count {
        in_count dist {
            0 :/ 40,
            [1:15] :/ 60 
        };
    }

    constraint c_out_count {
        out_count dist {
            0 :/ 10,
            [1:15] :/ 90
        };
    }

    constraint c_set_dst {
        set_dst dist {
            SET_PINS :/ 24,
            SET_X :/ 24,
            SET_Y :/ 24,
            SET_PINDIRS :/ 24,
            SET_NOP3 :/ 1,
            SET_NOP5 :/ 1,
            SET_NOP6 :/ 1,
            SET_NOP7 :/ 1
        };
    }

    // TEMPORARY CONSTRAINTS FOR DEFERRED FUNCTIONALITY
    constraint c_out_exec {
        out_dst != OUT_EXEC;
    }

    constraint c_mov_dst_exec {
        mov_dst != MOV_DST_EXEC;
    }

    constraint c_in_capture {
        in_src != IN_CAPTURE;
    }

    constraint c_crc {
        in_src != IN_CRC;
        in_crc == 1'b0;
        out_crc == 1'b0;
    }

    // intentional NOP, defer for potential definition later
    constraint c_mov_src_exec {
        mov_src != MOV_SRC_EXEC;
    }

    constraint c_wait_irq {
        wait_src != WAIT_IRQ;
    }

    // zero every field so manual programs won't explode
    function new();
        opcode = JMP;
        jmp_cond = JMP_ALWAYS;
        jmp_offset = '0;
        wait_pol = '0;
        wait_src = WAIT_PIN_ABS;
        wait_index = '0;
        in_src = IN_PINS;
        in_crc = '0;
        in_count = '0;
        out_dst = OUT_PINS;
        out_crc = '0;
        out_count = '0;
        push_pull_switch = '0;
        push_pull_cond = '0;
        push_pull_block = '0;
        push_pull_dont_care = '0;
        mov_dst = MOV_DST_PINS;
        mov_op = MOV_OP_NONE;
        mov_src = MOV_SRC_PINS;
        irq_clr = '0;
        irq_wait = '0;
        irq_dont_care = '0;
        irq_index = '0;
        set_dst = SET_PINS;
        set_imm = '0;
        delay = '0;
        sideset_data = '0;
        sideset_valid = '0;
    endfunction

    function instruction_t encode();
        case (opcode)
            JMP:       return encode_jmp(jmp_cond, jmp_offset, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            WAIT:      return encode_wait(wait_pol, wait_src, wait_index, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            IN:        return encode_in(in_src, in_crc, in_count, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            OUT:       return encode_out(out_dst, out_crc, out_count, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            PUSH_PULL: return encode_push_pull(push_pull_switch, push_pull_cond, push_pull_block, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            MOV:       return encode_mov(mov_dst, mov_op, mov_src, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            IRQ:       return encode_irq(irq_clr, irq_wait, irq_index, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            SET:       return encode_set(set_dst, set_imm, delay, sideset_data, sideset_valid, cfg.sideset_count, cfg.sideset_opt);
            default: $fatal(1, "[SM_INSTRUCTION] invalid opcode: %s in encode()", opcode.name);
        endcase
    endfunction
endclass