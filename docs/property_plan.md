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