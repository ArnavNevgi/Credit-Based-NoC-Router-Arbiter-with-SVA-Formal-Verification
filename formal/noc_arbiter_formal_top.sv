// -----------------------------------------------------------------------------
// File        : noc_arbiter_formal_top.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Formal harness skeleton for credit-based NoC arbiter.
// Phase       : Phase 1 - Skeleton only, full formal harness later.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module noc_arbiter_formal_top;

    localparam int NUM_PORTS    = 4;
    localparam int NUM_VCS      = 2;
    localparam int CREDIT_DEPTH = 4;
    localparam int PORT_W       = $clog2(NUM_PORTS);
    localparam int VC_W         = $clog2(NUM_VCS);
    localparam int CREDIT_W     = $clog2(CREDIT_DEPTH + 1);

    logic clk;
    logic rst_n;

    logic [NUM_PORTS-1:0] req;
    logic [NUM_PORTS-1:0][VC_W-1:0] req_vc;
    logic out_ready;
    logic [NUM_VCS-1:0] credit_return;

    logic [NUM_PORTS-1:0] grant;
    logic out_valid;
    logic [VC_W-1:0] grant_vc;

    logic [PORT_W-1:0] rr_ptr_dbg;
    logic [NUM_VCS-1:0][CREDIT_W-1:0] credit_count_dbg;

    // -------------------------------------------------------------------------
    // Clock generation for formal tools.
    // In SymbiYosys, clk is often driven by the formal engine.
    // This skeleton keeps the signal explicit for later tool configuration.
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // DUT instance.
    // -------------------------------------------------------------------------
    credit_rr_arbiter #(
        .NUM_PORTS(NUM_PORTS),
        .NUM_VCS(NUM_VCS),
        .CREDIT_DEPTH(CREDIT_DEPTH),
        .PORT_W(PORT_W),
        .VC_W(VC_W),
        .CREDIT_W(CREDIT_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .req_vc(req_vc),
        .out_ready(out_ready),
        .credit_return(credit_return),
        .grant(grant),
        .out_valid(out_valid),
        .grant_vc(grant_vc),
        .rr_ptr_dbg(rr_ptr_dbg),
        .credit_count_dbg(credit_count_dbg)
    );

    // -------------------------------------------------------------------------
    // SVA binding/instantiation planned for Phase 3/4.
    // -------------------------------------------------------------------------
    noc_arbiter_sva #(
        .NUM_PORTS(NUM_PORTS),
        .NUM_VCS(NUM_VCS),
        .CREDIT_DEPTH(CREDIT_DEPTH),
        .PORT_W(PORT_W),
        .VC_W(VC_W),
        .CREDIT_W(CREDIT_W)
    ) sva_inst (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .req_vc(req_vc),
        .out_ready(out_ready),
        .credit_return(credit_return),
        .grant(grant),
        .out_valid(out_valid),
        .grant_vc(grant_vc),
        .rr_ptr_dbg(rr_ptr_dbg),
        .credit_count_dbg(credit_count_dbg)
    );

endmodule