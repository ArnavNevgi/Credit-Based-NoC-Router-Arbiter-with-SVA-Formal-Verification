// -----------------------------------------------------------------------------
// File        : noc_arbiter_sva.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Safety assertions for credit-based NoC arbiter.
// Phase       : Phase 4 - Core safety properties.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module noc_arbiter_sva #(
    parameter int NUM_PORTS    = 4,
    parameter int NUM_VCS      = 2,
    parameter int CREDIT_DEPTH = 4,
    parameter int PORT_W       = $clog2(NUM_PORTS),
    parameter int VC_W         = $clog2(NUM_VCS),
    parameter int CREDIT_W     = $clog2(CREDIT_DEPTH + 1)
) (
    input logic                              clk,
    input logic                              rst_n,

    input logic [NUM_PORTS-1:0]              req,
    input var logic [NUM_PORTS-1:0][VC_W-1:0]    req_vc,
    input logic                              out_ready,
    input logic [NUM_VCS-1:0]                credit_return,

    input logic [NUM_PORTS-1:0]              grant,
    input logic                              out_valid,
    input logic [VC_W-1:0]                   grant_vc,

    input logic [PORT_W-1:0]                 rr_ptr_dbg,
    input var logic [NUM_VCS-1:0][CREDIT_W-1:0]  credit_count_dbg
);

`ifdef FORMAL

    // -------------------------------------------------------------------------
    // Formal reset modeling
    // -------------------------------------------------------------------------
    logic past_valid;

    initial begin
        assume(!rst_n);
    end

    // Keep reset asserted during the first formal cycle.
    always_ff @(posedge clk) begin
        if (!past_valid) begin
            assume(!rst_n);
        end
        past_valid <= 1'b1;
    end

    // -------------------------------------------------------------------------
    // Environment assumptions
    // -------------------------------------------------------------------------

    // Requested VC must be legal.
    // With NUM_VCS = 2 and VC_W = 1, this is naturally true, but this assumption
    // keeps the property module scalable.
    generate
        genvar a_port;
        for (a_port = 0; a_port < NUM_PORTS; a_port++) begin : gen_req_vc_legal_assume
            always_ff @(posedge clk) begin
                assume(req_vc[a_port] < NUM_VCS);
            end
        end
    endgenerate

    // Credit return must be legal.
    // The environment cannot return credit to a VC that is already full unless
    // the same cycle also consumes one credit from that VC.
    //
    // Phase 5 will make this tighter using explicit credit decrement reasoning.
    generate
        genvar a_vc;
        for (a_vc = 0; a_vc < NUM_VCS; a_vc++) begin : gen_credit_return_legal_assume
            always_ff @(posedge clk) begin
                if (rst_n && credit_return[a_vc] && (credit_count_dbg[a_vc] == CREDIT_DEPTH)) begin
                    assume(1'b0);
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Reset safety assertions
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            assert(grant == '0);
            assert(out_valid == 1'b0);
            assert(grant_vc == '0);
            assert(rr_ptr_dbg == '0);
        end
    end

    generate
        genvar r_vc;
        for (r_vc = 0; r_vc < NUM_VCS; r_vc++) begin : gen_reset_credit_assert
            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    assert(credit_count_dbg[r_vc] == CREDIT_DEPTH);
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Grant safety assertions
    // -------------------------------------------------------------------------

    // S1: Grant must be one-hot or zero.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert($onehot0(grant));
        end
    end

    // S2: out_valid must match whether any grant is active.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert(out_valid == (|grant));
        end
    end

    // S3: No grant when no request is active.
    always_ff @(posedge clk) begin
        if (rst_n && (req == '0)) begin
            assert(grant == '0);
            assert(out_valid == 1'b0);
        end
    end

    // S4: No grant when output is not ready.
    // This matches the current RTL architecture, where grant is issued only when
    // a transfer can fire.
    always_ff @(posedge clk) begin
        if (rst_n && !out_ready) begin
            assert(grant == '0);
            assert(out_valid == 1'b0);
        end
    end

    // S5: Each grant bit must imply the corresponding request bit.
    generate
        genvar g_port;
        for (g_port = 0; g_port < NUM_PORTS; g_port++) begin : gen_grant_implies_req_assert
            always_ff @(posedge clk) begin
                if (rst_n && grant[g_port]) begin
                    assert(req[g_port]);
                end
            end
        end
    endgenerate

    // S6: Grant must imply available credit for the requested VC.
    generate
        genvar c_port;
        for (c_port = 0; c_port < NUM_PORTS; c_port++) begin : gen_grant_implies_credit_assert
            always_ff @(posedge clk) begin
                if (rst_n && grant[c_port]) begin
                    assert(credit_count_dbg[req_vc[c_port]] > 0);
                end
            end
        end
    endgenerate

    // S7: grant_vc must match the VC requested by the granted port.
    generate
        genvar vc_port;
        for (vc_port = 0; vc_port < NUM_PORTS; vc_port++) begin : gen_grant_vc_match_assert
            always_ff @(posedge clk) begin
                if (rst_n && grant[vc_port]) begin
                    assert(grant_vc == req_vc[vc_port]);
                end
            end
        end
    endgenerate

    // S8: If all credits are zero, there must be no grant.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if ((credit_count_dbg[0] == '0) && (credit_count_dbg[1] == '0)) begin
                assert(grant == '0);
                assert(out_valid == 1'b0);
            end
        end
    end

    // S9: If there is a grant, the selected grant_vc must have nonzero credit.
    always_ff @(posedge clk) begin
        if (rst_n && out_valid) begin
            assert(credit_count_dbg[grant_vc] > 0);
        end
    end

    // -------------------------------------------------------------------------
    // Basic credit range safety
    // -------------------------------------------------------------------------

    generate
        genvar cr_vc;
        for (cr_vc = 0; cr_vc < NUM_VCS; cr_vc++) begin : gen_credit_range_assert
            always_ff @(posedge clk) begin
                if (rst_n) begin
                    assert(credit_count_dbg[cr_vc] <= CREDIT_DEPTH);
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Basic round-robin pointer range safety
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert(rr_ptr_dbg < NUM_PORTS);
        end
    end

    // -------------------------------------------------------------------------
    // Phase 4 cover sanity
    // -------------------------------------------------------------------------

    // Environment can leave reset.
    always_ff @(posedge clk) begin
        cover(rst_n);
    end

    // At least one request can occur.
    always_ff @(posedge clk) begin
        cover(rst_n && out_ready && (|req));
    end

    // At least one grant can occur.
    always_ff @(posedge clk) begin
        cover(rst_n && out_ready && (|req) && (|grant));
    end

`endif

endmodule
