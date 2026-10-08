// define config object
import sm_core_if_pkg::*;

class sm_config;
    rand logic [DIV_INT_WIDTH-1:0] div_int;
    rand logic [DIV_FRAC_WIDTH-1:0] div_frac;
    rand logic [$clog2(IMEM_DEPTH)-1:0] pc_base;
    rand logic [$clog2(SM_WINDOW)-1:0] wrap_top;
    rand logic [$clog2(SM_WINDOW)-1:0] wrap_bottom;
    rand logic [2:0] jmp_pin;
    rand logic [$clog2(6)-1:0] sideset_count;
    rand logic sideset_opt;
    rand logic osr_shiftdir;
    rand logic isr_shiftdir;
    rand logic autopull;
    rand logic autopush;
    rand logic [4:0] isr_threshold;
    rand logic [4:0] osr_threshold;
    rand logic delay_from_y;
    rand logic [2:0] pin_out_base;
    rand logic [3:0] pin_out_count;
    rand logic [2:0] pin_set_base;
    rand logic [2:0] pin_set_count;
    rand logic [2:0] pin_in_base;
    rand logic [2:0] pin_sideset_base;

    // constraints
    constraint c_wrap_bounds {
        wrap_bottom <= wrap_top;
    }

    constraint c_sideset_count {
        sideset_count <= 5;
    }

    constraint c_thresholds {
        isr_threshold <= DATA_WIDTH;
        osr_threshold <= DATA_WIDTH;
    }

    constraint c_pins {
        int'(pin_out_base) + int'(pin_out_count) <= 8;
        int'(pin_set_base) + int'(pin_set_count) <= 8;
        int'(pin_sideset_base) + int'(sideset_count) <= 8;
    }

    constraint c_clk_div {
        div_int dist {
            1 :/ 50,
            2 :/ 20,
            3 :/ 20, 
            4 :/ 10
        };
    }

    // constraints of deferred work
    constraint c_delay_from_y {
        delay_from_y == 0;
    }

    constraint c_div_frac {
        div_frac == 0;
    }
endclass