// -----------------------------------------------------------------------------
// File        : credit_rr_arbiter.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Credit-aware round-robin NoC output-port arbiter.
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
    input  logic                              clk,
    input  logic                              rst_n,

    // Request interface from input ports.
    input  logic [NUM_PORTS-1:0]              req,
    input  logic [NUM_PORTS-1:0][VC_W-1:0]    req_vc,

    // Downstream/output backpressure.
    input  logic                              out_ready,

    // Credit return from downstream buffer, one bit per VC.
    input  logic [NUM_VCS-1:0]                credit_return,

    // Grant/output interface.
    output logic [NUM_PORTS-1:0]              grant,
    output logic                              out_valid,
    output logic [VC_W-1:0]                   grant_vc,

    // Debug/formal visibility.
    output logic [PORT_W-1:0]                 rr_ptr_dbg,
    output logic [NUM_VCS-1:0][CREDIT_W-1:0]  credit_count_dbg
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [PORT_W-1:0] rr_ptr;

    logic [NUM_PORTS-1:0] grant_comb;
    logic [VC_W-1:0]      grant_vc_comb;
    logic [PORT_W-1:0]    grant_port_comb;
    logic                 grant_found_comb;

    logic [NUM_VCS-1:0]   credit_dec;
    logic [NUM_VCS-1:0]   credit_available;
    logic [NUM_VCS-1:0]   credit_full;
    logic [NUM_VCS-1:0]   credit_empty;

    logic                 fire;

    // -------------------------------------------------------------------------
    // Debug assignments
    // -------------------------------------------------------------------------
    assign rr_ptr_dbg = rr_ptr;

    // A successful transfer occurs when the arbiter grants a requester and the
    // downstream side can accept the transfer.
    //
    // In this implementation, grant generation already checks out_ready.
    // Therefore, fire is equivalent to any grant being issued.
    assign fire = out_valid && out_ready;

    // -------------------------------------------------------------------------
    // Per-VC credit counters
    // -------------------------------------------------------------------------
    genvar vc;

    generate
        for (vc = 0; vc < NUM_VCS; vc++) begin : gen_credit_counters
            credit_counter #(
                .CREDIT_DEPTH(CREDIT_DEPTH),
                .CREDIT_W(CREDIT_W)
            ) u_credit_counter (
                .clk(clk),
                .rst_n(rst_n),
                .credit_inc(credit_return[vc]),
                .credit_dec(credit_dec[vc]),
                .credit_count(credit_count_dbg[vc]),
                .credit_available(credit_available[vc]),
                .credit_full(credit_full[vc]),
                .credit_empty(credit_empty[vc])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Credit decrement decode
    //
    // Only the VC used by the granted requester is decremented.
    // -------------------------------------------------------------------------
    always_comb begin
        credit_dec = '0;

        if (fire) begin
            credit_dec[grant_vc] = 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Combinational round-robin arbitration
    //
    // Search order starts from rr_ptr.
    //
    // Example:
    //   rr_ptr = 2
    //   search order = 2, 3, 0, 1
    //
    // A requester is eligible only if:
    //   1. req[port] is high
    //   2. requested VC has available credit
    //   3. out_ready is high
    // -------------------------------------------------------------------------
    always_comb begin
        grant_comb       = '0;
        grant_vc_comb    = '0;
        grant_port_comb  = '0;
        grant_found_comb = 1'b0;

        if (rst_n && out_ready) begin
            for (int offset = 0; offset < NUM_PORTS; offset++) begin
                int port_idx;
                port_idx = (rr_ptr + offset) % NUM_PORTS;

                if (!grant_found_comb &&
                    req[port_idx] &&
                    credit_available[req_vc[port_idx]]) begin

                    grant_comb[port_idx] = 1'b1;
                    grant_vc_comb        = req_vc[port_idx];
                    grant_port_comb      = port_idx[PORT_W-1:0];
                    grant_found_comb     = 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Output control
    // -------------------------------------------------------------------------
    always_comb begin
        if (!rst_n) begin
            grant     = '0;
            out_valid = 1'b0;
            grant_vc  = '0;
        end else begin
            grant     = grant_comb;
            out_valid = |grant_comb;
            grant_vc  = grant_vc_comb;
        end
    end

    // -------------------------------------------------------------------------
    // Round-robin pointer update
    //
    // Pointer updates only after a successful transfer.
    // If port i wins, next priority starts at i + 1.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rr_ptr <= '0;
        end else if (fire) begin
            if (grant_port_comb == NUM_PORTS - 1) begin
                rr_ptr <= '0;
            end else begin
                rr_ptr <= grant_port_comb + 1'b1;
            end
        end
    end

endmodule