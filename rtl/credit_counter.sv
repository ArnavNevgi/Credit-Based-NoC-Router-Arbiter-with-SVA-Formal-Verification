// -----------------------------------------------------------------------------
// File        : credit_counter.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Skeleton for bounded per-VC credit counter.
// Phase       : Phase 1 - Skeleton only, full RTL implementation later.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module credit_counter #(
    parameter int CREDIT_DEPTH = 4,
    parameter int CREDIT_W     = $clog2(CREDIT_DEPTH + 1)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Increment when downstream returns one credit.
    input  logic                  credit_inc,

    // Decrement when a flit is successfully sent using this VC.
    input  logic                  credit_dec,

    // Current available credit count.
    output logic [CREDIT_W-1:0]    credit_count,

    // Convenience status flags.
    output logic                  credit_available,
    output logic                  credit_full,
    output logic                  credit_empty
);

    // -------------------------------------------------------------------------
    // Phase 2 TODO:
    // Implement bounded credit update logic.
    //
    // Reset behavior:
    //   credit_count <= CREDIT_DEPTH
    //
    // Increment rule:
    //   credit_count increments on legal credit_inc
    //
    // Decrement rule:
    //   credit_count decrements on legal credit_dec
    //
    // Safety:
    //   credit_count must never underflow below 0
    //   credit_count must never overflow above CREDIT_DEPTH
    // -------------------------------------------------------------------------

endmodule