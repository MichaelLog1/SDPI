virtual class sm_program_sequence;
    pure virtual task body(mailbox #(sm_program) driver_mailbox);
endclass

class smoke_seq extends sm_program_sequence;
    task body(mailbox #(sm_program) driver_mailbox);
        sm_program item;
        item = new(5);
        // set config
        item.cfg.div_int = DIV_INT_WIDTH'(1);
        item.cfg.div_frac = '0;
        item.cfg.pc_base = '0;
        item.cfg.wrap_top = SM_WINDOW - 1;
        item.cfg.wrap_bottom = '0;
        item.cfg.jmp_pin = '0;
        item.cfg.sideset_count = '0;
        item.cfg.sideset_opt = '0;
        item.cfg.osr_shiftdir = '0;
        item.cfg.isr_shiftdir = '0;
        item.cfg.autopull = '0;
        item.cfg.autopush = '0;
        item.cfg.isr_threshold = '0;
        item.cfg.osr_threshold = '0;
        item.cfg.delay_from_y = '0;
        item.cfg.pin_out_base = '0;
        item.cfg.pin_out_count = '0;
        item.cfg.pin_set_base = '0;
        item.cfg.pin_set_count = 3;
        item.cfg.pin_in_base = '0;
        item.cfg.pin_sideset_base = '0;
        // build program
        item.instr[0].opcode = SET;
        item.instr[0].set_dst = SET_PINS;
        item.instr[0].set_imm = 1;

        item.instr[1].opcode = SET;
        item.instr[1].set_dst = SET_PINS;
        item.instr[1].set_imm = 2;

        item.instr[2].opcode = SET;
        item.instr[2].set_dst = SET_PINS;
        item.instr[2].set_imm = 3;

        item.instr[3].opcode = SET;
        item.instr[3].set_dst = SET_PINS;
        item.instr[3].set_imm = 4;

        item.instr[4].opcode = JMP;
        item.instr[4].jmp_cond = JMP_ALWAYS;
        item.instr[4].jmp_offset = 0;

        driver_mailbox.put(item);
    endtask
endclass
