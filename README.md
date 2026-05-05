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
