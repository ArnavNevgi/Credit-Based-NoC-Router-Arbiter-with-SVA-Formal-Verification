# Credit-Based NoC Router Arbiter with SVA Formal Verification

## Project Overview

This project implements and formally verifies a small credit-based Network-on-Chip router output-port arbiter.

The design models one output port shared by four input ports. Each requester can request access to the output port with a selected virtual channel. The arbiter grants access using round-robin arbitration, but only when the requested virtual channel has downstream credit available.

This is not a full NoC router. The scope is intentionally limited to keep the design focused, formally verifiable, and interview-explainable.

## Design Scope

| Feature | Scope |
|---|---|
| Input ports | 4 |
| Output ports | 1 |
| Virtual channels | 2 |
| Credit depth | 4 |
| Arbitration policy | Round-robin |
| Grant encoding | One-hot |
| Credit model | Per-VC downstream credit counters |
| Verification focus | SVA-based formal verification |
| Formal tool target | SymbiYosys / Yosys / SMTBMC |

## High-Level Block Diagram

```text
              req[0], vc[0]
Input Port 0  ----------\
                         \
              req[1], vc[1] \
Input Port 1  ------------->  Credit-Aware Round-Robin Arbiter  ---> grant[3:0]
                           ->  Per-VC Credit Check                 ---> out_valid
              req[2], vc[2] /   Credit Update Logic                ---> grant_vc
Input Port 2  ------------/
                         /
              req[3], vc[3]
Input Port 3  ----------/

Credit Return[VC0/VC1] ---> Per-VC Credit Counters

| File                               | Purpose                                           |
| ---------------------------------- | ------------------------------------------------- |
| `rtl/credit_rr_arbiter.sv`         | Top-level credit-aware round-robin arbiter        |
| `rtl/credit_counter.sv`            | Reusable bounded credit counter                   |
| `formal/noc_arbiter_formal_top.sv` | Formal harness for unconstrained input stimulus   |
| `formal/noc_arbiter_sva.sv`        | SVA assumptions, assertions, and cover properties |

Key Design Rules
Grant must be one-hot or zero.
Grant can only occur when the corresponding request is active.
Grant can only occur when the requested VC has credit available.
Credit decrements only after a successful grant/fire event.
Credit increments only on legal credit return.
Credit counters must never underflow.
Credit counters must never overflow.
Round-robin pointer updates only after a successful grant.
Reset initializes the design to a clean known state.
Formal verification will use bounded safety and liveness-style properties.
Formal Verification Plan

The project will verify:

Mutual exclusion
Grant validity
Credit validity
No zero-credit grant
No grant without request
Credit underflow protection
Credit overflow protection
Reset behavior
Round-robin pointer behavior
Bounded no-starvation under legal traffic
Cover reachability for key arbitration and credit scenarios

| Phase                                    | Status      |
| ---------------------------------------- | ----------- |
| Phase 1: Architecture and skeleton files | In progress |
| Phase 2: RTL implementation              | Not started |
| Phase 3: Formal harness                  | Not started |
| Phase 4: Safety assertions               | Not started |
| Phase 5: Credit properties               | Not started |
| Phase 6: Bounded fairness checks         | Not started |
| Phase 7: Cover properties                | Not started |
| Phase 8: Counterexample debug            | Not started |
| Phase 9: Documentation                   | Not started |
| Phase 10: Resume bullets                 | Not started |


Phase 4 Safety Assertions

Implemented SVA safety checks for:

- One-hot-or-zero grant behavior
- Grant implies active request
- Grant implies available VC credit
- No grant when no request is active
- No grant when output is not ready
- No grant when all VC credits are zero
- `out_valid` consistency with grant
- `grant_vc` consistency with selected requester
- Reset behavior for grant, output-valid, pointer, and credit state
- Round-robin pointer range safety
- Credit count range safety

## Phase 5 Implemented Credit Accounting Properties

| ID | Property Name | Type | Status | Purpose |
|---|---|---|---|---|
| C1 | Credit upper-bound safety | Assert | Implemented | Ensures credit count never exceeds `CREDIT_DEPTH` |
| C2 | Credit underflow-wrap protection | Assert | Implemented | Unsigned underflow would wrap above valid range, caught by upper-bound check |
| C3 | Credit decrements on VC consume | Assert | Implemented | Ensures successful grant/fire consumes one credit from selected VC |
| C4 | Credit increments on legal return | Assert | Implemented | Ensures downstream credit return restores one credit |
| C5 | Simultaneous consume and return preserves count | Assert | Implemented | Ensures same-cycle inc/dec has zero net effect |
| C6 | Credit holds when no event occurs | Assert | Implemented | Ensures credit count is stable without return or consume |
| C7 | Zero-credit VC cannot be consumed | Assert | Implemented | Prevents grant/fire from using unavailable downstream buffer |
| C8 | Full-credit return requires same-cycle consume | Assert/Assume-supported | Implemented | Prevents illegal overflow from environment credit return |
| RR1 | Pointer stable without fire | Assert | Implemented | Ensures arbitration priority changes only after successful transfer |
| RR2 | Pointer advances after granted port | Assert | Implemented | Ensures round-robin pointer updates correctly after fire |

## Phase 6 Bounded Fairness Checks

Implemented bounded no-starvation checks for the 4-port round-robin arbiter.

The properties check that when a requester keeps requesting under legal conditions, the arbiter grants that requester within a bounded number of cycles.

Legal conditions include:

- requester remains active
- output remains ready
- requested VC has available credit
- round-robin pointer remains inside the legal range

The project intentionally describes these as bounded fairness checks, not complete unbounded starvation-freedom proofs. 

## Phase 7 Cover Properties

Added cover properties to demonstrate reachability of important arbitration and credit-flow scenarios.

| Cover Group | Description |
|---|---|
| Per-port grant reachability | Covers grant occurrence for ports 0, 1, 2, and 3 |
| Per-VC grant reachability | Covers grant/fire for VC0 and VC1 |
| Back-to-back grants | Covers consecutive grant cycles |
| Different-port rotation | Covers consecutive grants to different ports |
| Credit depletion | Covers VC credit count reaching zero |
| Credit return | Covers credit return events and return after depletion |
| Same-cycle consume/return | Covers simultaneous grant/fire and credit return for the selected VC |
| Backpressure blocking | Covers request with `out_ready` low and no grant |
| Zero-credit blocking | Covers request with all credits depleted and no grant |
| Mixed request patterns | Covers nontrivial request vectors such as `1010` and `0101` |
| Priority pointer coverage | Covers all round-robin pointer values |
| Pointer wraparound | Covers priority wrap from last port back to port 0 |
| Reset recovery | Covers reset deassertion followed by a valid grant |