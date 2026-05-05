# Credit-Based NoC Router Arbiter with SVA Formal Verification

## Project Overview

This project implements and formally verifies a small credit-based Network-on-Chip router output-port arbiter.

The design models one output port shared by four input ports. Each requester can request access to the output port with a selected virtual channel. The arbiter grants access using round-robin arbitration, but only when the requested virtual channel has downstream credit available.

This is not a full NoC router. The scope is intentionally limited to keep the design focused, formally verifiable, and interview-explainable.

## Why This Project Matters

Modern SoCs often use Network-on-Chip fabrics or router-like interconnect structures to move traffic between IP blocks. Arbitration and flow control are critical because incorrect grants or credit accounting can cause dropped data, buffer overflow, unfair access, or deadlock-like behavior.

This project focuses on a small but realistic part of that problem: a credit-aware output-port arbiter. The arbiter grants one requester at a time using round-robin priority, but only if the selected virtual channel has downstream credit available.

The main value of this project is not RTL size. The value is the formal verification flow:

- safety assertions
- credit accounting properties
- bounded fairness checks
- cover reachability
- counterexample debug
- proof result documentation

## Formal Results Summary

| Run | Tool Flow | Result |
|---|---|---|
| Prove | SymbiYosys + Yosys + SMTBMC + Z3 | PASS |
| Cover | SymbiYosys + Yosys + SMTBMC + Z3 | PASS |

The prove run completed with:

- basecase PASS
- induction PASS
- successful proof by k-induction

The cover run completed successfully and reached the planned cover properties.

Detailed results are documented in:

- `docs/proof_results.md`
- `docs/counterexample_debug.md`
- `regressions/formal/phase8_prove_log.txt`
- `regressions/formal/phase8_cover_log.txt`

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

## How to Run

### QuestaSim Compile Check

From QuestaSim Transcript:

```tcl
cd C:/credit_based_NOC/credit-based-noc-arbiter-formal/sim
do compile.do

### Yosys Elaboration Check

```wsl
cd /mnt/c/credit_based_NOC/credit-based-noc-arbiter-formal/formal

yosys -p "read -formal -sv ../rtl/credit_counter.sv; read -formal -sv ../rtl/credit_rr_arbiter.sv; read -formal -sv noc_arbiter_sva.sv; read -formal -sv noc_arbiter_formal_top.sv; prep -top noc_arbiter_formal_top"

### SymbiYosys Prove Run

```wsl

cd /mnt/c/credit_based_NOC/credit-based-noc-arbiter-formal/formal

rm -rf noc_arbiter_prove
sby -f noc_arbiter_prove.sby

### SymbiYosys Cover Run

```wsl
cd /mnt/c/credit_based_NOC/credit-based-noc-arbiter-formal/formal

rm -rf noc_arbiter_prove
sby -f noc_arbiter_prove.sby

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

## File Description

| File                                  | Purpose                                        |
| ------------------------------------- | ---------------------------------------------- |
| `rtl/credit_counter.sv`               | Bounded credit counter for one virtual channel |
| `rtl/credit_rr_arbiter.sv`            | Credit-aware round-robin arbiter               |
| `formal/noc_arbiter_formal_top.sv`    | Formal top-level harness                       |
| `formal/noc_arbiter_sva.sv`           | Assumptions, assertions, and cover properties  |
| `formal/noc_arbiter_prove.sby`        | SymbiYosys prove configuration                 |
| `formal/noc_arbiter_cover.sby`        | SymbiYosys cover configuration                 |
| `sim/compile.do`                      | QuestaSim compile script                       |
| `docs/architecture.md`                | Design architecture and transaction behavior   |
| `docs/property_plan.md`               | Formal property plan                           |
| `docs/proof_results.md`               | Proof and cover run results                    |
| `docs/counterexample_debug.md`        | Counterexample debug notes                     |
| `docs/limitations_and_future_work.md` | Scope limitations and future extensions        |


## Formal Verification Methodology

The formal verification flow uses a small harness around the RTL. Inputs such as requests, requested virtual channels, output readiness, and credit returns are treated as symbolic formal inputs.

The property set includes:

### Environment Assumptions

- Requested VC values remain legal.
- Credit return behavior does not illegally overflow a full credit counter.
- Bounded fairness checks assume persistent legal request conditions.

### Safety Assertions

- Grant is one-hot or zero.
- Grant implies active request.
- Grant implies available credit.
- No grant occurs when all requests are low.
- No grant occurs when output is not ready.
- No grant occurs when all VC credits are zero.
- `out_valid` matches the grant vector.
- `grant_vc` matches the granted requester.

### Credit Accounting Assertions

- Credit count never exceeds `CREDIT_DEPTH`.
- Credit decrements on successful grant/fire.
- Credit increments on legal credit return.
- Same-cycle consume and return preserves credit count.
- Credit count holds when no consume/return occurs.
- Zero-credit VC cannot be consumed.

### Round-Robin Assertions

- Round-robin pointer remains in range.
- Pointer stays stable when no transfer fires.
- Pointer advances to the port after the granted requester.

### Bounded Fairness Checks

The project includes bounded no-starvation checks. These prove that a persistent legal requester receives a grant within a bounded window when output remains ready and credit remains available.

These are bounded formal checks, not complete unbounded liveness proofs.

### Cover Properties

Cover properties demonstrate reachability of key scenarios:

- each port receives a grant
- each VC is selected
- back-to-back grants occur
- credits deplete and return
- backpressure blocks grants
- zero-credit state blocks grants
- round-robin pointer wraps around
- reset recovery leads to a valid grant


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

## Phase 8 Formal Run Results

Formal verification was run using SymbiYosys/Yosys/SMTBMC with Z3.

| Run | Result |
|---|---|
| Prove | PASS: basecase and induction passed |
| Cover | PASS: cover properties reached |

A reset-related counterexample was debugged during Phase 8. The issue was caused by a synchronous reset assertion being sampled too early. The property was fixed using `$past(!rst_n)`-based reset checks, after which the prove run passed.