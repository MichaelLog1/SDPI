build:
	source /apps/reconfig/enable && \
	vlog -sv -lint +incdir+tb/env \
		tb/sm_core_if_pkg.sv \
		tb/sm_core_isa_pkg.sv \
		tb/sm_core_if.sv \
		tb/sm_core_env_pkg.sv \
		rtl/clkdiv.sv \
		rtl/fifo.sv \
		rtl/shift_reg.sv \
		rtl/sm_decode.sv \
		rtl/sm_pc.sv \
		rtl/sm_core.sv \
		tb/sm_core_tb.sv

run:
	source /apps/reconfig/enable && \
	vsim -c sm_core_tb -do "run -all; quit"