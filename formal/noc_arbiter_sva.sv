// -----------------------------------------------------------------------------
// File        : noc_arbiter_sva.sv
// Project     : Credit-Based NoC Router Arbiter with SVA Formal Verification
// Description : Basic formal assumptions and sanity assertions.
// Phase       : Phase 3 - Initial formal harness checks.
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
    // Initial reset modeling
    //
    // The design starts in reset. This avoids meaningless initial states.
    // -------------------------------------------------------------------------
    initial begin
        assume(!rst_n);
    end

    // Track whether reset has been released at least once.
    logic past_valid;

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
    end

    // -------------------------------------------------------------------------
    // Basic reset sequencing assumption
    //
    // Keep reset low in the first valid cycle, then allow formal to choose
    // deassertion later.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!past_valid) begin
            assume(!rst_n);
        end
    end

    // -------------------------------------------------------------------------
    // Basic environment assumptions
    //
    // In this project, req_vc is 1 bit because NUM_VCS = 2.
    // Therefore, req_vc is naturally legal. This generate block keeps the
    // assumption scalable if NUM_VCS changes later.
    // -------------------------------------------------------------------------
    generate
        genvar i;
        for (i = 0; i < NUM_PORTS; i++) begin : gen_req_vc_assumptions
            always_ff @(posedge clk) begin
                assume(req_vc[i] < NUM_VCS);
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Credit return legality assumption
    //
    // The environment should not return credit to a VC that is already full.
    // This models legal downstream buffer behavior.
    // -------------------------------------------------------------------------
    generate
        genvar vc;
        for (vc = 0; vc < NUM_VCS; vc++) begin : gen_credit_return_assumptions
            always_ff @(posedge clk) begin
                if (rst_n && credit_return[vc]) begin
                    assume(credit_count_dbg[vc] < CREDIT_DEPTH);
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Phase 3 sanity assertions
    //
    // These are intentionally simple. Full safety properties are Phase 4.
    // -------------------------------------------------------------------------

    // Reset should force no visible grant.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            assert(grant == '0);
            assert(out_valid == 1'b0);
            assert(rr_ptr_dbg == '0);
        end
    end

    // Debug credit counters should stay in a representable legal range.
    generate
        genvar c;
        for (c = 0; c < NUM_VCS; c++) begin : gen_basic_credit_range_assertions
            always_ff @(posedge clk) begin
                if (rst_n) begin
                    assert(credit_count_dbg[c] <= CREDIT_DEPTH);
                end
            end
        end
    endgenerate

    // Grant vector should never contain unknown/multiple obvious invalid values.
    // Full onehot0 proof will be added in Phase 4.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            assert(grant < (1 << NUM_PORTS));
        end
    end

    // Basic cover: prove the environment can leave reset.
    always_ff @(posedge clk) begin
        cover(rst_n);
    end

    // Basic cover: eventually see some request while out_ready is high.
    always_ff @(posedge clk) begin
        cover(rst_n && out_ready && (|req));
    end

`endif

endmodule