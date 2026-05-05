// -----------------------------------------------------------------------------
// File        : noc_arbiter_sva.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Safety and credit-accounting assertions for credit-based NoC arbiter.
// Phase       : Phase 5 - Credit accounting properties.
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
    input logic [NUM_PORTS-1:0][VC_W-1:0]    req_vc,
    input logic                              out_ready,
    input logic [NUM_VCS-1:0]                credit_return,

    input logic [NUM_PORTS-1:0]              grant,
    input logic                              out_valid,
    input logic [VC_W-1:0]                   grant_vc,

    input logic [PORT_W-1:0]                 rr_ptr_dbg,
    input logic [NUM_VCS-1:0][CREDIT_W-1:0]  credit_count_dbg
);

`ifdef FORMAL

    // -------------------------------------------------------------------------
    // Formal reset modeling
    // -------------------------------------------------------------------------
    logic past_valid;

    initial begin
        assume(!rst_n);
    end

    always_ff @(posedge clk) begin
        if (!past_valid) begin
            assume(!rst_n);
        end
        past_valid <= 1'b1;
    end

    // -------------------------------------------------------------------------
    // Helper signals
    // -------------------------------------------------------------------------

    logic fire;

    assign fire = out_valid && out_ready;

    // Decode which VC is consumed by the current grant.
    logic [NUM_VCS-1:0] grant_vc_decoded;

    always_comb begin
        grant_vc_decoded = '0;

        if (fire) begin
            grant_vc_decoded[grant_vc] = 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Environment assumptions
    // -------------------------------------------------------------------------

    // Requested VC must be legal.
    // With NUM_VCS = 2 and VC_W = 1, this is naturally true.
    // This assumption keeps the property module parameter-scalable.
    generate
        genvar a_port;
        for (a_port = 0; a_port < NUM_PORTS; a_port++) begin : gen_req_vc_legal_assume
            always_ff @(posedge clk) begin
                assume(req_vc[a_port] < NUM_VCS);
            end
        end
    endgenerate

    // Credit return legality:
    // The environment cannot return credit to a full VC unless the same cycle
    // also consumes one credit from that same VC.
    //
    // This is more precise than the Phase 4 assumption.
    // Legal cases:
    // - count < CREDIT_DEPTH and credit_return = 1
    // - count == CREDIT_DEPTH, credit_return = 1, and same VC is also decremented
    //
    // Illegal case:
    // - count == CREDIT_DEPTH, credit_return = 1, and no same-cycle decrement
    generate
        genvar a_vc;
        for (a_vc = 0; a_vc < NUM_VCS; a_vc++) begin : gen_credit_return_legal_assume
            always_ff @(posedge clk) begin
                if (rst_n && credit_return[a_vc] &&
                    (credit_count_dbg[a_vc] == CREDIT_DEPTH) &&
                    !grant_vc_decoded[a_vc]) begin
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

    // S10: A grant can only happen when out_ready is high.
    always_ff @(posedge clk) begin
        if (rst_n && (|grant)) begin
            assert(out_ready);
        end
    end

    // -------------------------------------------------------------------------
    // Credit range safety
    // -------------------------------------------------------------------------

    // C1/C2: Credit count must always stay between 0 and CREDIT_DEPTH.
    // Since credit_count_dbg is unsigned, underflow manifests as wraparound above
    // CREDIT_DEPTH. Therefore, the upper-bound assertion catches both overflow
    // and underflow-wrap behavior.
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
    // Phase 5 credit-accounting assertions
    // -------------------------------------------------------------------------

    // C3: Credit decrements by one when a VC is consumed and no credit returns
    // for that VC in the same cycle.
    generate
        genvar dec_vc;
        for (dec_vc = 0; dec_vc < NUM_VCS; dec_vc++) begin : gen_credit_decrement_assert
            always_ff @(posedge clk) begin
                if (past_valid && $past(rst_n) && rst_n) begin
                    if ($past(grant_vc_decoded[dec_vc]) &&
                        !$past(credit_return[dec_vc])) begin
                        assert(credit_count_dbg[dec_vc] ==
                               ($past(credit_count_dbg[dec_vc]) - 1'b1));
                    end
                end
            end
        end
    endgenerate

    // C4: Credit increments by one when a credit returns and no grant consumes
    // that same VC in the same cycle.
    generate
        genvar inc_vc;
        for (inc_vc = 0; inc_vc < NUM_VCS; inc_vc++) begin : gen_credit_increment_assert
            always_ff @(posedge clk) begin
                if (past_valid && $past(rst_n) && rst_n) begin
                    if ($past(credit_return[inc_vc]) &&
                        !$past(grant_vc_decoded[inc_vc])) begin
                        assert(credit_count_dbg[inc_vc] ==
                               ($past(credit_count_dbg[inc_vc]) + 1'b1));
                    end
                end
            end
        end
    endgenerate

    // C5: If credit return and credit consume happen for the same VC in the same
    // cycle, the net available credit count remains unchanged.
    generate
        genvar same_vc;
        for (same_vc = 0; same_vc < NUM_VCS; same_vc++) begin : gen_credit_inc_dec_same_cycle_assert
            always_ff @(posedge clk) begin
                if (past_valid && $past(rst_n) && rst_n) begin
                    if ($past(credit_return[same_vc]) &&
                        $past(grant_vc_decoded[same_vc])) begin
                        assert(credit_count_dbg[same_vc] ==
                               $past(credit_count_dbg[same_vc]));
                    end
                end
            end
        end
    endgenerate

    // C6: If neither credit return nor grant consume occurs for a VC, credit count
    // must remain stable.
    generate
        genvar hold_vc;
        for (hold_vc = 0; hold_vc < NUM_VCS; hold_vc++) begin : gen_credit_hold_assert
            always_ff @(posedge clk) begin
                if (past_valid && $past(rst_n) && rst_n) begin
                    if (!$past(credit_return[hold_vc]) &&
                        !$past(grant_vc_decoded[hold_vc])) begin
                        assert(credit_count_dbg[hold_vc] ==
                               $past(credit_count_dbg[hold_vc]));
                    end
                end
            end
        end
    endgenerate

    // C7: A VC at zero credit cannot be consumed.
    generate
        genvar zero_vc;
        for (zero_vc = 0; zero_vc < NUM_VCS; zero_vc++) begin : gen_zero_credit_no_consume_assert
            always_ff @(posedge clk) begin
                if (rst_n && (credit_count_dbg[zero_vc] == '0)) begin
                    assert(!grant_vc_decoded[zero_vc]);
                end
            end
        end
    endgenerate

    // C8: If a VC is full, credit_return without same-cycle consume is illegal
    // due to environment assumption. This assertion documents the expected
    // safe behavior visible at the design boundary.
    generate
        genvar full_vc;
        for (full_vc = 0; full_vc < NUM_VCS; full_vc++) begin : gen_full_credit_return_assert
            always_ff @(posedge clk) begin
                if (rst_n &&
                    (credit_count_dbg[full_vc] == CREDIT_DEPTH) &&
                    credit_return[full_vc]) begin
                    assert(grant_vc_decoded[full_vc]);
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

    // RR1: Pointer must remain stable if no fire occurred in the previous cycle.
    always_ff @(posedge clk) begin
        if (past_valid && $past(rst_n) && rst_n) begin
            if (!$past(fire)) begin
                assert(rr_ptr_dbg == $past(rr_ptr_dbg));
            end
        end
    end

    // RR2: Pointer should advance to granted port + 1 after a fire.
    generate
        genvar rr_port;
        for (rr_port = 0; rr_port < NUM_PORTS; rr_port++) begin : gen_rr_ptr_update_assert
            always_ff @(posedge clk) begin
                if (past_valid && $past(rst_n) && rst_n) begin
                    if ($past(fire) && $past(grant[rr_port])) begin
                        if (rr_port == NUM_PORTS - 1) begin
                            assert(rr_ptr_dbg == '0);
                        end else begin
                            assert(rr_ptr_dbg == rr_port + 1);
                        end
                    end
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Phase 5 cover sanity
    // More detailed cover properties will be added in Phase 7.
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        cover(rst_n);
    end

    always_ff @(posedge clk) begin
        cover(rst_n && out_ready && (|req));
    end

    always_ff @(posedge clk) begin
        cover(rst_n && out_ready && (|req) && (|grant));
    end

    // See at least one credit decrement event.
    always_ff @(posedge clk) begin
        cover(rst_n && fire);
    end

    // See at least one credit return event.
    always_ff @(posedge clk) begin
        cover(rst_n && (|credit_return));
    end

    // See a simultaneous credit return and grant consume.
    always_ff @(posedge clk) begin
        cover(rst_n && fire && credit_return[grant_vc]);
    end

`endif

endmodule