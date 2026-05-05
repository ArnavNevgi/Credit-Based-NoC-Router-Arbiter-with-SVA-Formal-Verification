## Tool Flow

| Item | Tool |
|---|---|
| RTL language | SystemVerilog |
| Assertion language | SystemVerilog Assertions |
| Formal frontend | Yosys |
| Formal runner | SymbiYosys |
| Model checker | SMTBMC |
| Solver | Z3 |
| Prove config | `formal/noc_arbiter_prove.sby` |
| Cover config | `formal/noc_arbiter_cover.sby` |

## Proof Configuration

| Configuration | Value |
|---|---|
| Prove mode | `prove` |
| Prove depth | 20 |
| Cover mode | `cover` |
| Cover depth | 40 |
| Top module | `noc_arbiter_formal_top` |
| Ports | 4 |
| Virtual channels | 2 |
| Credit depth | 4 |

## Run Results

| Run | Command | Result |
|---|---|---|
| Prove | `sby -f noc_arbiter_prove.sby` | PASS: basecase PASS, induction PASS, successful proof by k-induction |
| Cover | `sby -f noc_arbiter_cover.sby` | PASS: cover properties reached |

## Property Group Results

| Property Group | Status | Notes |
|---|---|---|
| Reset safety | PASS | Reset properties passed after synchronous reset timing fix |
| Grant safety | PASS | One-hot grant, grant-implies-request, no-request/no-ready blocking proved |
| Credit safety | PASS | Credit upper-bound safety and zero-credit blocking proved |
| Credit accounting | PASS | Decrement, increment, same-cycle inc/dec, and hold behavior proved |
| Round-robin pointer | PASS | Pointer stability without fire and pointer update after fire proved |
| Bounded fairness | PASS | Bounded no-starvation checks passed under persistent request, available credit, and output-ready assumptions |
| Cover reachability | PASS | Port grants, VC grants, credit depletion/return, backpressure blocking, zero-credit blocking, mixed requests, pointer wraparound, and reset recovery covers passed |

## Notes on Bounded Proof Scope

These are bounded formal checks, not complete unbounded industrial proofs.

The fairness checks are bounded no-starvation checks under legal assumptions:

- requester remains active
- requested VC remains stable
- requested VC has available credit
- output remains ready
- reset is not active

The project does not claim full NoC-level deadlock freedom or complete unbounded liveness.