vlib work
vmap work work

vlog -sv ../rtl/credit_counter.sv
vlog -sv ../rtl/credit_rr_arbiter.sv
vlog -sv +define+FORMAL ../formal/noc_arbiter_sva.sv
vlog -sv +define+FORMAL ../formal/noc_arbiter_formal_top.sv

quit