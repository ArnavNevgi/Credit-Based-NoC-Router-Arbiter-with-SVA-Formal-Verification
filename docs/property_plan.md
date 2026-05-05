# Formal Property Plan

## Property Plan Overview

This document lists the initial assumptions, assertions, and cover properties for the credit-based NoC router arbiter.

The properties are grouped into:

1. Environment assumptions
2. Grant safety assertions
3. Credit safety assertions
4. Reset assertions
5. Round-robin assertions
6. Bounded fairness/liveness-style assertions
7. Cover properties

## Property Table

| ID | Property Name | Type | Intent | Signals Involved | Expected Result | Why It Matters |
|---|---|---|---|---|---|---|
| A1 | Reset eventually deasserts | Assume | Constrain formal reset behavior | `rst_n` | Reset is active initially, then deasserts | Avoids meaningless always-reset proofs |
| A2 | Legal credit return | Assume | Prevent illegal credit overflow from environment | `credit_return`, `credit_count_dbg` | Credit return only when count is below `CREDIT_DEPTH` | Models legal downstream behavior |
| A3 | Stable request for bounded fairness | Assume | Used only for liveness-style checks | `req`, `req_vc`, `out_ready` | Request and credit remain valid during fairness window | Prevents false starvation failures |
| S1 | Grant one-hot or zero | Assert | Prove mutual exclusion | `grant` | `$onehot0(grant)` | Arbiter must not grant multiple ports |
| S2 | Grant implies request | Assert | Prove grant validity | `grant`, `req` | `grant[i] -> req[i]` | Prevents granting inactive requester |
| S3 | Grant implies available credit | Assert | Prove credit-aware behavior | `grant`, `req_vc`, `credit_count_dbg` | Grant only if requested VC credit > 0 | Core credit-flow correctness |
| S4 | No grant when no request | Assert | Prove idle safety | `req`, `grant` | `req == 0 -> grant == 0` | Avoids spurious transfers |
| S5 | No grant when all credits zero | Assert | Prove zero-credit blocking | `credit_count_dbg`, `grant` | If all credits are zero, grant is zero | Prevents buffer overflow downstream |
| S6 | Output valid matches grant | Assert | Prove output consistency | `out_valid`, `grant` | `out_valid == (|grant)` | Keeps control signals consistent |
| C1 | Credit never underflows | Assert | Prove credit count lower bound | `credit_count_dbg` | `credit_count >= 0` | Prevents invalid credit accounting |
| C2 | Credit never overflows | Assert | Prove credit count upper bound | `credit_count_dbg` | `credit_count <= CREDIT_DEPTH` | Prevents impossible downstream capacity |
| C3 | Credit decrements on fire | Assert | Prove send accounting | `grant`, `out_valid`, `out_ready`, `credit_count_dbg` | Successful send reduces selected VC credit | Ensures transfer consumes credit |
| C4 | Credit increments on return | Assert | Prove return accounting | `credit_return`, `credit_count_dbg` | Legal return increases credit | Ensures returned buffers are tracked |
| R1 | Reset clears grants | Assert | Prove clean reset output | `rst_n`, `grant`, `out_valid` | During reset, grant and out_valid are zero | Avoids invalid reset-time transfer |
| R2 | Reset initializes pointer | Assert | Prove known priority state | `rst_n`, `rr_ptr_dbg` | During reset, pointer is zero | Makes arbitration deterministic |
| R3 | Reset initializes credits | Assert | Prove known credit state | `rst_n`, `credit_count_dbg` | Credits initialize to `CREDIT_DEPTH` | Models empty downstream buffers |
| RR1 | Pointer changes only after fire | Assert | Prove fair priority update | `rr_ptr_dbg`, `out_valid`, `out_ready` | No fire means pointer stable | Prevents unfair pointer movement |
| RR2 | Pointer updates to granted port + 1 | Assert | Prove round-robin update rule | `rr_ptr_dbg`, `grant` | After fire, pointer advances after granted port | Core round-robin correctness |
| F1 | Bounded no-starvation for port 0 | Assert | Bounded liveness-style check | `req[0]`, `req_vc[0]`, `credit_count_dbg`, `grant[0]` | Persistent legal request gets grant within N cycles | Shows fairness under legal conditions |
| F2 | Bounded no-starvation for port 1 | Assert | Bounded liveness-style check | `req[1]`, `req_vc[1]`, `credit_count_dbg`, `grant[1]` | Persistent legal request gets grant within N cycles | Shows fairness under legal conditions |
| F3 | Bounded no-starvation for port 2 | Assert | Bounded liveness-style check | `req[2]`, `req_vc[2]`, `credit_count_dbg`, `grant[2]` | Persistent legal request gets grant within N cycles | Shows fairness under legal conditions |
| F4 | Bounded no-starvation for port 3 | Assert | Bounded liveness-style check | `req[3]`, `req_vc[3]`, `credit_count_dbg`, `grant[3]` | Persistent legal request gets grant within N cycles | Shows fairness under legal conditions |
| CV1 | Cover port 0 grant | Cover | Show reachability | `grant[0]` | Port 0 receives grant | Confirms reachable grant scenario |
| CV2 | Cover port 1 grant | Cover | Show reachability | `grant[1]` | Port 1 receives grant | Confirms reachable grant scenario |
| CV3 | Cover port 2 grant | Cover | Show reachability | `grant[2]` | Port 2 receives grant | Confirms reachable grant scenario |
| CV4 | Cover port 3 grant | Cover | Show reachability | `grant[3]` | Port 3 receives grant | Confirms reachable grant scenario |
| CV5 | Cover all ports granted | Cover | Show arbitration rotation | `grant`, `rr_ptr_dbg` | All ports receive grants over time | Demonstrates round-robin behavior |
| CV6 | Cover credit depletion | Cover | Show credit count can reduce to zero | `credit_count_dbg` | Some VC reaches zero credit | Demonstrates credit-flow behavior |
| CV7 | Cover credit return after depletion | Cover | Show credit recovery | `credit_return`, `credit_count_dbg` | Depleted VC receives returned credit | Demonstrates buffer return modeling |
| CV8 | Cover priority wraparound | Cover | Show pointer wraparound | `rr_ptr_dbg` | Pointer moves from last port to port 0 | Demonstrates round-robin wrap |
| CV9 | Cover no-grant due to zero credit | Cover | Show blocked transfer scenario | `req`, `credit_count_dbg`, `grant` | Request exists but grant is blocked | Demonstrates credit protection |
| CV10 | Cover reset recovery grant | Cover | Show post-reset operation | `rst_n`, `grant` | Valid grant occurs after reset | Confirms reset recovery |

## Phase 4 Implemented Properties

| ID | Property Name | Type | Status |
|---|---|---|
| S1 | Grant one-hot or zero | Assert | Implemented |
| S2 | Output valid matches grant | Assert | Implemented |
| S3 | No grant when no request | Assert | Implemented |
| S4 | No grant when output not ready | Assert | Implemented |
| S5 | Grant implies request | Assert | Implemented |
| S6 | Grant implies available credit | Assert | Implemented |
| S7 | Grant VC matches requested VC | Assert | Implemented |
| S8 | No grant when all credits are zero | Assert | Implemented |
| S9 | Selected grant VC has nonzero credit | Assert | Implemented |
| R1 | Reset clears grants/output valid | Assert | Implemented |
| R2 | Reset initializes pointer | Assert | Implemented |
| R3 | Reset initializes credits | Assert | Implemented |
| C1 | Credit count does not exceed depth | Assert | Implemented |
| RR0 | Round-robin pointer remains in range | Assert | Implemented |

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


## Phase 6 Implemented Bounded Fairness Properties

| ID | Property Name | Type | Status | Purpose |
|---|---|---|---|---|
| F1 | Bounded no-starvation for port 0 | Assert | Implemented | Persistent legal request from port 0 should receive grant within bounded cycles |
| F2 | Bounded no-starvation for port 1 | Assert | Implemented | Persistent legal request from port 1 should receive grant within bounded cycles |
| F3 | Bounded no-starvation for port 2 | Assert | Implemented | Persistent legal request from port 2 should receive grant within bounded cycles |
| F4 | Bounded no-starvation for port 3 | Assert | Implemented | Persistent legal request from port 3 should receive grant within bounded cycles |
| F5 | All-requests progress | Assert | Implemented | If all ports request and credits are available, some grant must occur |
| F6 | Priority-port immediate grant | Assert | Implemented | If current priority port has legal request, it is granted immediately |

## Phase 6 Fairness Scope

The bounded no-starvation checks are not unbounded liveness proofs. They are bounded formal checks under legal conditions:

- requester remains active
- output remains ready
- requested VC has available credit
- arbitration state is legal

These checks are sufficient for this student portfolio project and should be described as bounded fairness or bounded no-starvation checks.


## Phase 7 Implemented Cover Properties

| ID | Cover Name | Type | Status | Purpose |
|---|---|---|---|---|
| CV0 | Reset deassertion | Cover | Implemented | Shows environment can leave reset |
| CV1 | Port 0 grant | Cover | Implemented | Shows port 0 can receive a grant |
| CV2 | Port 1 grant | Cover | Implemented | Shows port 1 can receive a grant |
| CV3 | Port 2 grant | Cover | Implemented | Shows port 2 can receive a grant |
| CV4 | Port 3 grant | Cover | Implemented | Shows port 3 can receive a grant |
| CV5 | Request to grant | Cover | Implemented | Shows a legal request can produce grant |
| CV6 | All ports request | Cover | Implemented | Shows arbitration under full contention |
| CV7 | Back-to-back grants | Cover | Implemented | Shows consecutive transfer behavior |
| CV8 | Back-to-back different grants | Cover | Implemented | Shows grant rotation behavior |
| CV9 | Credit return | Cover | Implemented | Shows downstream credit return event |
| CV10 | Credit consume | Cover | Implemented | Shows grant/fire credit consumption |
| CV11 | Same-cycle consume and return | Cover | Implemented | Shows simultaneous credit accounting scenario |
| CV12 | VC0 grant | Cover | Implemented | Shows VC0 can be selected |
| CV13 | VC1 grant | Cover | Implemented | Shows VC1 can be selected |
| CV14 | VC0 depletion | Cover | Implemented | Shows VC0 can reach zero credit |
| CV15 | VC1 depletion | Cover | Implemented | Shows VC1 can reach zero credit |
| CV16 | VC0 return after depletion | Cover | Implemented | Shows credit recovery for VC0 |
| CV17 | VC1 return after depletion | Cover | Implemented | Shows credit recovery for VC1 |
| CV18 | Backpressure no-grant | Cover | Implemented | Shows request blocked by `out_ready == 0` |
| CV19 | Zero-credit no-grant | Cover | Implemented | Shows request blocked by unavailable credit |
| CV20 | Mixed request 1010 | Cover | Implemented | Shows arbitration with nontrivial request pattern |
| CV21 | Mixed request 0101 | Cover | Implemented | Shows arbitration with alternate request pattern |
| CV22 | Pointer values | Cover | Implemented | Shows each round-robin pointer state is reachable |
| CV23 | Pointer wraparound | Cover | Implemented | Shows pointer wraps from last port to 0 |
| CV24 | Reset recovery grant | Cover | Implemented | Shows valid operation after reset |
| CV25 | All ports grant sequence | Cover | Implemented | Shows grant rotation over time |
| CV26 | VC0 deplete-return-grant | Cover | Implemented | Shows full credit-flow lifecycle for VC0 |
| CV27 | VC1 deplete-return-grant | Cover | Implemented | Shows full credit-flow lifecycle for VC1 |