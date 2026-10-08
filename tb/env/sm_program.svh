class sm_program;
    rand sm_instruction instr[];
    rand sm_config cfg;

    function new(int size);
        if (size > SM_WINDOW) $fatal(1, "[SM_PROGRAM] program size: %d is greater than SM_WINDOW", size);
        instr = new[size];
        cfg = new();
        foreach (instr[i]) begin
            instr[i] = new();
            instr[i].cfg = cfg;
        end
    endfunction

    // cross constraints
    constraint c_jmp_bound {
        foreach (instr[i]) {
            instr[i].opcode == JMP -> instr[i].jmp_offset inside {[cfg.wrap_bottom:cfg.wrap_top]};
            instr[i].opcode == JMP -> instr[i].jmp_offset < instr.size();
        }
    }
endclass
