# Counterexample Debug Notes

## Phase 8 reset credit basecase failure

- Failure: reset credit initialization assertion at `noc_arbiter_sva.sv` line 121 failed in basecase step 1.
- Root cause: the assertion checked the synchronous reset effect too early, as a current-cycle reset value, instead of checking a later sampled state after a clock edge where reset was low.
- Fix: kept combinational reset output checks under current `!rst_n`, and converted sequential reset pointer and credit initialization assertions to `$past(!rst_n)` checks guarded by two valid sampled states.
- Result: rerun SymbiYosys prove after patch.

## Phase 8 credit hold basecase failure

- Failure: credit hold assertion at `noc_arbiter_sva.sv` line 288 failed in basecase step 3.
- Root cause: the formal reset environment allowed `rst_n` to reassert after it had already been released, creating a reset-glitch trace at the same boundary where credit-accounting assertions were active.
- Fix: added a reset monotonicity assumption so reset starts asserted and, once `rst_n` is high, remains high.
- Result: rerun SymbiYosys prove after patch.

## Phase 8 credit hold basecase failure after reset monotonicity

- Failure: credit hold assertion at `noc_arbiter_sva.sv` line 291 still failed in basecase step 3.
- Root cause: the assertion inferred credit decrement from the derived `grant_vc_decoded` helper under `$past`, while the RTL credit counter is driven by the direct `fire` and `grant_vc` condition.
- Fix: rewrote credit-accounting assertions to use `$past(fire)` and `$past(grant_vc)` directly for decrement detection.
- Result: rerun SymbiYosys prove after patch.

## Phase 8 credit hold basecase failure after direct decrement detection

- Failure: credit hold assertion at `noc_arbiter_sva.sv` line 295 still failed in basecase step 3.
- Root cause: the VCD showed the RTL credit counters holding, so the remaining failure was a checker modeling issue around `$past()` of generated unpacked-array credit elements.
- Fix: added explicit sampled history signals for credit counts, credit returns, `fire`, `grant_vc`, and `rst_n`, then rewrote credit-accounting assertions to compare against those sampled values.
- Result: rerun SymbiYosys prove after patch.

## Phase 8 bounded fairness failure

- Failure: bounded fairness assertion at `noc_arbiter_sva.sv` line 425 failed in induction step 0 and basecase step 11.
- Root cause: the visible basecase trace did not show a continuously eligible ungranted requester; the property used nested dynamic `$past()` indexing of `credit_count_dbg` by historical `req_vc`, which is fragile for Yosys/SymbiYosys.
- Fix: rewrote bounded fairness as explicit per-VC generated checks using static `credit_count_dbg[fair_vc]` indexing at each sampled cycle.
- Result: rerun SymbiYosys prove after patch.


## Counterexample 1: Synchronous Reset Assertion Timing

| Field | Detail |
|---|---|
| Property | Reset credit initialization |
| Run | `noc_arbiter_prove.sby` |
| Initial Result | FAIL in basecase step 1 |
| Trace file | `formal/noc_arbiter_prove/engine_0/trace.vcd` |
| Root cause | The assertion checked reset-initialized credit state in the same sampled cycle as reset, while the DUT uses synchronous reset inside `always_ff @(posedge clk)`. |
| Fix | Rewrote reset checks to use `$past(!rst_n)` so reset effects are checked after a clock edge where reset was active. |
| Final Result | PASS: basecase and induction both passed after the property timing fix |

## Debug Method

1. Ran `sby -f noc_arbiter_prove.sby`.
2. Observed basecase failure in step 1.
3. Located failing assertion in `noc_arbiter_sva.sv`.
4. Identified that the failing check was a reset credit initialization property.
5. Compared the property timing against synchronous reset RTL behavior.
6. Determined that the assertion was checking reset effects too early.
7. Updated reset assertions to check behavior after a clock edge where reset was active.
8. Reran SymbiYosys prove.
9. Confirmed PASS for basecase and induction.

## Lesson Learned

For synchronous-reset RTL, formal properties should check reset effects after a clock edge where reset was active. Current-cycle reset assertions can create false failures because sequential assignments are observed after the sampled clock edge.

## Signals Inspected

| Signal | Purpose |
|---|---|
| `rst_n` | Reset sequencing |
| `credit_count_dbg` | Credit counter reset state |
| `grant` | Reset output behavior |
| `out_valid` | Reset output-valid behavior |
| `rr_ptr_dbg` | Round-robin pointer reset state |

## Final Phase 8 Result

| Run | Result |
|---|---|
| Prove | PASS |
| Cover | PASS |