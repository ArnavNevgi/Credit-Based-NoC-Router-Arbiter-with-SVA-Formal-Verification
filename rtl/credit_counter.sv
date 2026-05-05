// -----------------------------------------------------------------------------
// File        : credit_counter.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Bounded credit counter for one virtual channel.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module credit_counter #(
    parameter int CREDIT_DEPTH = 4,
    parameter int CREDIT_W     = $clog2(CREDIT_DEPTH + 1)
) (
    input  logic               clk,
    input  logic               rst_n,

    // Increment when downstream returns one credit.
    input  logic               credit_inc,

    // Decrement when a flit is successfully sent using this VC.
    input  logic               credit_dec,

    // Current available credit count.
    output logic [CREDIT_W-1:0] credit_count,

    // Convenience status flags.
    output logic               credit_available,
    output logic               credit_full,
    output logic               credit_empty
);

    // -------------------------------------------------------------------------
    // Status flags
    // -------------------------------------------------------------------------
    assign credit_available = (credit_count != '0);
    assign credit_full      = (credit_count == CREDIT_DEPTH[CREDIT_W-1:0]);
    assign credit_empty     = (credit_count == '0);

    // -------------------------------------------------------------------------
    // Bounded credit counter
    //
    // Reset:
    //   credit_count = CREDIT_DEPTH
    //
    // Rules:
    //   inc only     -> increment if not full
    //   dec only     -> decrement if not empty
    //   inc and dec  -> no net change
    //   neither      -> hold
    //
    // Simultaneous inc/dec means one flit was accepted and one credit returned
    // in the same cycle, so the available-credit count remains unchanged.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            credit_count <= CREDIT_DEPTH[CREDIT_W-1:0];
        end else begin
            unique case ({credit_inc, credit_dec})
                2'b10: begin
                    if (!credit_full) begin
                        credit_count <= credit_count + 1'b1;
                    end
                end

                2'b01: begin
                    if (!credit_empty) begin
                        credit_count <= credit_count - 1'b1;
                    end
                end

                2'b11: begin
                    credit_count <= credit_count;
                end

                default: begin
                    credit_count <= credit_count;
                end
            endcase
        end
    end

endmodule