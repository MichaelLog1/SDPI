class sm_program;
    rand sm_instruction instr[];
    rand sm_config cfg;
    int program_size;

    function new(int size);
        if (size > SM_WINDOW) $fatal(1, "[SM_PROGRAM] program size: %d is greater than SM_WINDOW", size);
        instr = new[size];
        cfg = new();
        foreach (instr[i]) begin
            instr[i] = new();
            instr[i].cfg = cfg;
        end
        program_size = size;
    endfunction

    function void to_string();
        for (int i = 0; i < instr.size(); i++) begin
            $display("%s", disassemble(instr[i].encode(), cfg.sideset_count, cfg.sideset_opt));
        end
        $display("\n");
    endfunction

    // cross constraints
    constraint c_jmp_bound {
        foreach (instr[i]) {
            instr[i].opcode == JMP -> instr[i].jmp_offset inside {[cfg.wrap_bottom:cfg.wrap_top]};
            instr[i].opcode == JMP -> instr[i].jmp_offset < instr.size();
        }
    }

    constraint c_program_size {
        instr.size() == program_size;
        cfg.pc_base + program_size <= IMEM_DEPTH;
    }

    constraint c_wrap_window {
        cfg.wrap_bottom <= cfg.wrap_top;
        cfg.wrap_top < program_size;
    }
endclass
