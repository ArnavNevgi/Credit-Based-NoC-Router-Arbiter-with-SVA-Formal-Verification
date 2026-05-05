// -----------------------------------------------------------------------------
// File        : noc_arbiter_sva.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Safety, credit-accounting, and bounded fairness assertions.
// Phase       : Phase 6 - Bounded no-starvation checks.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module noc_arbiter_sva #(
    parameter int NUM_PORTS    = 4,
    parameter int NUM_VCS      = 2,
    parameter int CREDIT_DEPTH = 4,
    parameter int PORT_W       = $clog2(NUM_PORTS),
    parameter int VC_W         = $clog2(NUM_VCS),
    parameter int CREDIT_W     = $clog2(CREDIT_DEPTH + 1),

    // Bounded fairness window.
    // For 4 ports, a legal persistent requester should be served within 4 cycles
    // when all required assumptions hold.
    parameter int FAIR_BOUND   = NUM_PORTS
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
    logic history_valid;

    initial begin
        assume(!rst_n);
        assume(!past_valid);
        assume(!history_valid);
    end

    always_ff @(posedge clk) begin
        if (!past_valid) begin
            assume(!rst_n);
        end else if ($past(rst_n)) begin
            // Model a single initial reset pulse: once released, reset stays high.
            assume(rst_n);
        end
        past_valid <= 1'b1;
    end

    // -------------------------------------------------------------------------
    // Helper signals
    // -------------------------------------------------------------------------

    logic fire;
    assign fire = out_valid && out_ready;

    logic                              rst_n_q;
    logic                              fire_q;
    logic [VC_W-1:0]                   grant_vc_q;
    logic [NUM_VCS-1:0]                credit_return_q;
    logic [NUM_VCS-1:0][CREDIT_W-1:0]  credit_count_dbg_q;

    always_ff @(posedge clk) begin
        history_valid      <= 1'b1;
        rst_n_q            <= rst_n;
        fire_q             <= fire;
        grant_vc_q         <= grant_vc;
        credit_return_q    <= credit_return;
        credit_count_dbg_q <= credit_count_dbg;
    end

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

    generate
        genvar a_port;
        for (a_port = 0; a_port < NUM_PORTS; a_port++) begin : gen_req_vc_legal_assume
            always_ff @(posedge clk) begin
                assume(req_vc[a_port] < NUM_VCS);
            end
        end
    endgenerate

    // Credit return legality:
    // Returning credit to a full VC is legal only if the same VC is consumed in
    // the same cycle.
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
        end
    end

    always_ff @(posedge clk) begin
        if (past_valid && $past(past_valid) && $past(!rst_n)) begin
            assert(rr_ptr_dbg == '0);
        end
    end

    generate
        genvar r_vc;
        for (r_vc = 0; r_vc < NUM_VCS; r_vc++) begin : gen_reset_credit_assert
            always_ff @(posedge clk) begin
                if (past_valid && $past(past_valid) && $past(!rst_n)) begin
                    assert(credit_count_dbg[r_vc] == CREDIT_DEPTH);
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Grant safety assertions
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert($onehot0(grant));
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert(out_valid == (|grant));
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && (req == '0)) begin
            assert(grant == '0);
            assert(out_valid == 1'b0);
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && !out_ready) begin
            assert(grant == '0);
            assert(out_valid == 1'b0);
        end
    end

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

    always_ff @(posedge clk) begin
        if (rst_n) begin
            if ((credit_count_dbg[0] == '0) && (credit_count_dbg[1] == '0)) begin
                assert(grant == '0);
                assert(out_valid == 1'b0);
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && out_valid) begin
            assert(credit_count_dbg[grant_vc] > 0);
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && (|grant)) begin
            assert(out_ready);
        end
    end

    // -------------------------------------------------------------------------
    // Credit range safety
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
    // Credit-accounting assertions
    // -------------------------------------------------------------------------

    generate
        genvar dec_vc;
        for (dec_vc = 0; dec_vc < NUM_VCS; dec_vc++) begin : gen_credit_decrement_assert
            always_ff @(posedge clk) begin
                if (history_valid && rst_n_q && rst_n) begin
                    if (fire_q &&
                        (grant_vc_q == dec_vc[VC_W-1:0]) &&
                        !credit_return_q[dec_vc]) begin
                        assert(credit_count_dbg[dec_vc] ==
                               (credit_count_dbg_q[dec_vc] - 1'b1));
                    end
                end
            end
        end
    endgenerate

    generate
        genvar inc_vc;
        for (inc_vc = 0; inc_vc < NUM_VCS; inc_vc++) begin : gen_credit_increment_assert
            always_ff @(posedge clk) begin
                if (history_valid && rst_n_q && rst_n) begin
                    if (credit_return_q[inc_vc] &&
                        !(fire_q &&
                          (grant_vc_q == inc_vc[VC_W-1:0]))) begin
                        assert(credit_count_dbg[inc_vc] ==
                               (credit_count_dbg_q[inc_vc] + 1'b1));
                    end
                end
            end
        end
    endgenerate

    generate
        genvar same_vc;
        for (same_vc = 0; same_vc < NUM_VCS; same_vc++) begin : gen_credit_inc_dec_same_cycle_assert
            always_ff @(posedge clk) begin
                if (history_valid && rst_n_q && rst_n) begin
                    if (credit_return_q[same_vc] &&
                        fire_q &&
                        (grant_vc_q == same_vc[VC_W-1:0])) begin
                        assert(credit_count_dbg[same_vc] ==
                               credit_count_dbg_q[same_vc]);
                    end
                end
            end
        end
    endgenerate

    generate
        genvar hold_vc;
        for (hold_vc = 0; hold_vc < NUM_VCS; hold_vc++) begin : gen_credit_hold_assert
            always_ff @(posedge clk) begin
                if (history_valid && rst_n_q && rst_n) begin
                    if (!credit_return_q[hold_vc] &&
                        !(fire_q &&
                          (grant_vc_q == hold_vc[VC_W-1:0]))) begin
                        assert(credit_count_dbg[hold_vc] ==
                               credit_count_dbg_q[hold_vc]);
                    end
                end
            end
        end
    endgenerate

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
    // Round-robin pointer safety
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert(rr_ptr_dbg < NUM_PORTS);
        end
    end

    always_ff @(posedge clk) begin
        if (past_valid && $past(rst_n) && rst_n) begin
            if (!$past(fire)) begin
                assert(rr_ptr_dbg == $past(rr_ptr_dbg));
            end
        end
    end

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
    // Phase 6 bounded fairness / no-starvation checks
    //
    // Yosys-compatible procedural version.
    //
    // If a requester remains active, output remains ready, and its requested VC
    // remains credited over a bounded window, then the requester should have
    // received a grant within that window.
    //
    // This is a bounded fairness check, not an unbounded liveness proof.
    // -------------------------------------------------------------------------

    generate
        genvar fair_port;
        for (fair_port = 0; fair_port < NUM_PORTS; fair_port++) begin : gen_bounded_fairness_assert
            genvar fair_vc;
            for (fair_vc = 0; fair_vc < NUM_VCS; fair_vc++) begin : gen_bounded_fairness_vc_assert

                always_ff @(posedge clk) begin
                    if (past_valid && rst_n &&
                        $past(rst_n, 4) &&
                        $past(rst_n, 3) &&
                        $past(rst_n, 2) &&
                        $past(rst_n, 1) &&

                        $past(req[fair_port], 4) &&
                        $past(req[fair_port], 3) &&
                        $past(req[fair_port], 2) &&
                        $past(req[fair_port], 1) &&
                        req[fair_port] &&

                        $past(out_ready, 4) &&
                        $past(out_ready, 3) &&
                        $past(out_ready, 2) &&
                        $past(out_ready, 1) &&
                        out_ready &&

                        ($past(req_vc[fair_port], 4) == fair_vc[VC_W-1:0]) &&
                        ($past(req_vc[fair_port], 3) == fair_vc[VC_W-1:0]) &&
                        ($past(req_vc[fair_port], 2) == fair_vc[VC_W-1:0]) &&
                        ($past(req_vc[fair_port], 1) == fair_vc[VC_W-1:0]) &&
                        (req_vc[fair_port] == fair_vc[VC_W-1:0]) &&

                        ($past(credit_count_dbg[fair_vc], 4) > 0) &&
                        ($past(credit_count_dbg[fair_vc], 3) > 0) &&
                        ($past(credit_count_dbg[fair_vc], 2) > 0) &&
                        ($past(credit_count_dbg[fair_vc], 1) > 0) &&
                        (credit_count_dbg[fair_vc] > 0)) begin

                        assert($past(grant[fair_port], 4) ||
                               $past(grant[fair_port], 3) ||
                               $past(grant[fair_port], 2) ||
                               $past(grant[fair_port], 1) ||
                               grant[fair_port]);
                    end
                end

            end
        end
    endgenerate

    // If all ports request, output is ready, and both VCs have credit,
    // at least one grant must occur.
    always_ff @(posedge clk) begin
        if (rst_n &&
            (req == {NUM_PORTS{1'b1}}) &&
            out_ready &&
            (credit_count_dbg[0] > 0) &&
            (credit_count_dbg[1] > 0)) begin
            assert(|grant);
        end
    end

    // If the current priority port requests and its VC has credit,
    // it should be granted immediately.
    generate
        genvar pri_port;
        for (pri_port = 0; pri_port < NUM_PORTS; pri_port++) begin : gen_priority_port_immediate_grant
            always_ff @(posedge clk) begin
                if (rst_n &&
                    (rr_ptr_dbg == pri_port[PORT_W-1:0]) &&
                    req[pri_port] &&
                    out_ready &&
                    (credit_count_dbg[req_vc[pri_port]] > 0)) begin
                    assert(grant[pri_port]);
                end
            end
        end
    endgenerate

        // -------------------------------------------------------------------------
    // Phase 7 cover properties
    //
    // These covers are used to demonstrate reachability of important arbitration,
    // credit, reset, and backpressure scenarios. They are not safety proofs by
    // themselves; they provide evidence that the formal environment can exercise
    // meaningful design behavior.
    // -------------------------------------------------------------------------

    // CV0: Environment can leave reset.
    always_ff @(posedge clk) begin
        cover(rst_n);
    end

    // CV1-CV4: Each port can receive a grant.
    generate
        genvar cover_port;
        for (cover_port = 0; cover_port < NUM_PORTS; cover_port++) begin : gen_cover_each_port_grant
            always_ff @(posedge clk) begin
                cover(rst_n && grant[cover_port]);
            end
        end
    endgenerate

    // CV5: A valid request can produce a grant.
    always_ff @(posedge clk) begin
        cover(rst_n && out_ready && (|req) && (|grant));
    end

    // CV6: All ports request at the same time and one grant is issued.
    always_ff @(posedge clk) begin
        cover(rst_n &&
              out_ready &&
              (req == {NUM_PORTS{1'b1}}) &&
              (credit_count_dbg[0] > 0) &&
              (credit_count_dbg[1] > 0) &&
              (|grant));
    end

    // CV7: Back-to-back grants occur.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n)) begin
            cover($past(|grant) && (|grant));
        end
    end

    // CV8: Back-to-back grants to different ports occur.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n)) begin
            cover($past(|grant) &&
                  (|grant) &&
                  ($past(grant) != grant));
        end
    end

    // CV9: Credit return occurs.
    always_ff @(posedge clk) begin
        cover(rst_n && (|credit_return));
    end

    // CV10: Grant/fire consumes a credit.
    always_ff @(posedge clk) begin
        cover(rst_n && fire);
    end

    // CV11: Simultaneous grant/fire and credit return for selected VC.
    always_ff @(posedge clk) begin
        cover(rst_n && fire && credit_return[grant_vc]);
    end

    // CV12-CV13: Each VC can be selected by a grant.
    generate
        genvar cover_vc_grant;
        for (cover_vc_grant = 0; cover_vc_grant < NUM_VCS; cover_vc_grant++) begin : gen_cover_each_vc_grant
            always_ff @(posedge clk) begin
                cover(rst_n && fire && (grant_vc == cover_vc_grant[VC_W-1:0]));
            end
        end
    endgenerate

    // CV14-CV15: Each VC can deplete to zero credit.
    generate
        genvar cover_deplete_vc;
        for (cover_deplete_vc = 0; cover_deplete_vc < NUM_VCS; cover_deplete_vc++) begin : gen_cover_credit_depletion
            always_ff @(posedge clk) begin
                cover(rst_n && (credit_count_dbg[cover_deplete_vc] == '0));
            end
        end
    endgenerate

    // CV16-CV17: Credit return after depletion.
    generate
        genvar cover_return_vc;
        for (cover_return_vc = 0; cover_return_vc < NUM_VCS; cover_return_vc++) begin : gen_cover_credit_return_after_depletion
            always_ff @(posedge clk) begin
                if (past_valid && rst_n && $past(rst_n)) begin
                    cover(($past(credit_count_dbg[cover_return_vc]) == '0) &&
                          credit_return[cover_return_vc] &&
                          (credit_count_dbg[cover_return_vc] > '0));
                end
            end
        end
    endgenerate

    // CV18: No grant due to output backpressure.
    always_ff @(posedge clk) begin
        cover(rst_n &&
              (|req) &&
              !out_ready &&
              (grant == '0) &&
              !out_valid);
    end

    // CV19: No grant due to all credits being zero.
    always_ff @(posedge clk) begin
        cover(rst_n &&
              out_ready &&
              (|req) &&
              (credit_count_dbg[0] == '0) &&
              (credit_count_dbg[1] == '0) &&
              (grant == '0));
    end

    // CV20: Mixed request pattern.
    always_ff @(posedge clk) begin
        cover(rst_n &&
              out_ready &&
              (req == 4'b1010) &&
              (|grant));
    end

    // CV21: Another mixed request pattern.
    always_ff @(posedge clk) begin
        cover(rst_n &&
              out_ready &&
              (req == 4'b0101) &&
              (|grant));
    end

    // CV22: Priority pointer reaches each value.
    generate
        genvar cover_ptr;
        for (cover_ptr = 0; cover_ptr < NUM_PORTS; cover_ptr++) begin : gen_cover_rr_ptr_values
            always_ff @(posedge clk) begin
                cover(rst_n && (rr_ptr_dbg == cover_ptr[PORT_W-1:0]));
            end
        end
    endgenerate

    // CV23: Priority pointer wraparound from last port back to 0.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n)) begin
            cover(($past(rr_ptr_dbg) == (NUM_PORTS - 1)) &&
                  (rr_ptr_dbg == '0));
        end
    end

    // CV24: Reset recovery followed by a valid grant.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n && !$past(rst_n)) begin
            cover(out_ready && (|req) && (|grant));
        end
    end

        // CV25 alternative: observe all four ports granted within recent history.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n &&
            $past(rst_n, 4) &&
            $past(rst_n, 3) &&
            $past(rst_n, 2) &&
            $past(rst_n, 1)) begin

            cover(($past(grant[0], 4) || $past(grant[0], 3) || $past(grant[0], 2) || $past(grant[0], 1) || grant[0]) &&
                  ($past(grant[1], 4) || $past(grant[1], 3) || $past(grant[1], 2) || $past(grant[1], 1) || grant[1]) &&
                  ($past(grant[2], 4) || $past(grant[2], 3) || $past(grant[2], 2) || $past(grant[2], 1) || grant[2]) &&
                  ($past(grant[3], 4) || $past(grant[3], 3) || $past(grant[3], 2) || $past(grant[3], 1) || grant[3]));
        end
    end

    // CV26 alternative: VC0 depletion followed by later nonzero credit.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n &&
            $past(rst_n, 4) &&
            $past(rst_n, 3) &&
            $past(rst_n, 2) &&
            $past(rst_n, 1)) begin

            cover(($past(credit_count_dbg[0], 4) == '0) &&
                  (credit_count_dbg[0] > '0));
        end
    end

    // CV27 alternative: VC1 depletion followed by later nonzero credit.
    always_ff @(posedge clk) begin
        if (past_valid && rst_n &&
            $past(rst_n, 4) &&
            $past(rst_n, 3) &&
            $past(rst_n, 2) &&
            $past(rst_n, 1)) begin

            cover(($past(credit_count_dbg[1], 4) == '0) &&
                  (credit_count_dbg[1] > '0));
        end
    end


`endif

endmodule
