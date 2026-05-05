// -----------------------------------------------------------------------------
// File        : credit_rr_arbiter.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Skeleton for credit-aware round-robin NoC output-port arbiter.
// Phase       : Phase 1 - Skeleton only, full RTL implementation later.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module credit_rr_arbiter #(
    parameter int NUM_PORTS    = 4,
    parameter int NUM_VCS      = 2,
    parameter int CREDIT_DEPTH = 4,
    parameter int PORT_W       = $clog2(NUM_PORTS),
    parameter int VC_W         = $clog2(NUM_VCS),
    parameter int CREDIT_W     = $clog2(CREDIT_DEPTH + 1)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    // Request interface from input ports.
    input  logic [NUM_PORTS-1:0]          req,
    input  logic [NUM_PORTS-1:0][VC_W-1:0] req_vc,

    // Downstream/output backpressure.
    input  logic                         out_ready,

    // Credit return from downstream buffer, one bit per VC.
    input  logic [NUM_VCS-1:0]            credit_return,

    // Grant/output interface.
    output logic [NUM_PORTS-1:0]          grant,
    output logic                         out_valid,
    output logic [VC_W-1:0]               grant_vc,

    // Debug/formal visibility.
    output logic [PORT_W-1:0]             rr_ptr_dbg,
    output logic [NUM_VCS-1:0][CREDIT_W-1:0] credit_count_dbg
);

    // -------------------------------------------------------------------------
    // Internal state planned for Phase 2:
    //
    // logic [PORT_W-1:0] rr_ptr;
    // logic [NUM_PORTS-1:0] grant_comb;
    // logic [VC_W-1:0] grant_vc_comb;
    // logic fire;
    //
    // Per-VC credit counters:
    // credit_counter vc0_counter (...);
    // credit_counter vc1_counter (...);
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Phase 2 TODO:
    // 1. Instantiate one credit_counter per VC.
    // 2. Build combinational round-robin grant logic.
    // 3. Check ports in order starting from rr_ptr.
    // 4. Grant only if:
    //      req[i] == 1
    //      credit_count[req_vc[i]] > 0
    //      out_ready == 1
    // 5. Generate one-hot grant.
    // 6. Generate out_valid.
    // 7. Generate grant_vc.
    // 8. Decrement selected VC credit only on successful fire.
    // 9. Increment VC credit on credit_return[vc].
    // 10. Update rr_ptr only after successful fire.
    // -------------------------------------------------------------------------

endmodule