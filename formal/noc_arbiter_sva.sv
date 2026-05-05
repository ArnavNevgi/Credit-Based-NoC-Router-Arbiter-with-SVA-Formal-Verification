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
    // These are bounded liveness-style checks.
    //
    // Meaning:
    // If a requester keeps its request asserted, the output remains ready, and
    // the requested VC has credit available, the requester should be granted
    // within FAIR_BOUND cycles.
    //
    // This is not an unbounded industrial starvation proof. It is a bounded
    // formal fairness check under legal traffic assumptions.
    // -------------------------------------------------------------------------

    generate
        genvar fair_port;
        for (fair_port = 0; fair_port < NUM_PORTS; fair_port++) begin : gen_bounded_fairness_assert

            property p_bounded_no_starvation;
                @(posedge clk) disable iff (!rst_n)
                    (
                        req[fair_port] &&
                        out_ready &&
                        (credit_count_dbg[req_vc[fair_port]] > 0)
                    )
                    |->
                    (
                        grant[fair_port] or
                        ##1 grant[fair_port] or
                        ##2 grant[fair_port] or
                        ##3 grant[fair_port] or
                        ##4 grant[fair_port]
                    );
            endproperty

            assert property (p_bounded_no_starvation);

        end
    endgenerate

    // Stronger fairness check under all-ports-active traffic.
    // If all ports request continuously, output is ready, and both VCs have
    // credit available, then at least one grant must occur.
    property p_all_requests_make_progress;
        @(posedge clk) disable iff (!rst_n)
            ((req == {NUM_PORTS{1'b1}}) &&
             out_ready &&
             (credit_count_dbg[0] > 0) &&
             (credit_count_dbg[1] > 0))
            |->
            (|grant);
    endproperty

    assert property (p_all_requests_make_progress);

    // Under legal traffic, if the current priority port requests and its VC has
    // credit, it should be granted immediately.
    generate
        genvar pri_port;
        for (pri_port = 0; pri_port < NUM_PORTS; pri_port++) begin : gen_priority_port_immediate_grant
            property p_priority_port_grants_first;
                @(posedge clk) disable iff (!rst_n)
                    (
                        (rr_ptr_dbg == pri_port[PORT_W-1:0]) &&
                        req[pri_port] &&
                        out_ready &&
                        (credit_count_dbg[req_vc[pri_port]] > 0)
                    )
                    |->
                    grant[pri_port];
            endproperty

            assert property (p_priority_port_grants_first);
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Phase 6 cover sanity
    // Detailed cover plan remains Phase 7.
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

    always_ff @(posedge clk) begin
        cover(rst_n && fire);
    end

    always_ff @(posedge clk) begin
        cover(rst_n && (|credit_return));
    end

    always_ff @(posedge clk) begin
        cover(rst_n && fire && credit_return[grant_vc]);
    end

    // Cover that all ports request together and a grant occurs.
    always_ff @(posedge clk) begin
        cover(rst_n &&
              out_ready &&
              (req == {NUM_PORTS{1'b1}}) &&
              (credit_count_dbg[0] > 0) &&
              (credit_count_dbg[1] > 0) &&
              (|grant));
    end

`endif

endmodule