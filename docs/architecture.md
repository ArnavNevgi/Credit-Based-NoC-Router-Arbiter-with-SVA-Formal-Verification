```markdown
# Architecture: Credit-Based NoC Router Arbiter

## 1. Project Goal

The goal is to design and formally verify a small credit-based NoC router output-port arbiter.

The arbiter receives requests from four input ports. Each input port requests access to one shared output port and specifies a virtual channel. The arbiter grants one requester per cycle using round-robin arbitration, but only if the requested virtual channel has available downstream credit.

## 2. Scope

This project models only one part of a NoC router:

```text
Input request arbitration for one output port

This project does not implement currently:

Full packet routing
Multiple output ports
Complete router pipeline
Routing-table lookup
Virtual-channel allocation
Switch allocation across multiple outputs
Deadlock-freedom proof for a complete NoC

## 3. Parameters    

| Parameter      |                      Value | Meaning                                  |
| -------------- | -------------------------: | ---------------------------------------- |
| `NUM_PORTS`    |                          4 | Number of input requesters               |
| `NUM_VCS`      |                          2 | Number of virtual channels               |
| `CREDIT_DEPTH` |                          4 | Maximum downstream buffer credits per VC |
| `PORT_W`       |        `$clog2(NUM_PORTS)` | Width needed to index ports              |
| `VC_W`         |          `$clog2(NUM_VCS)` | Width needed to index virtual channels   |
| `CREDIT_W`     | `$clog2(CREDIT_DEPTH + 1)` | Width needed to store credit count       |

## 4. Signal List
| Signal  | Direction | Width | Description                  |
| ------- | --------- | ----: | ---------------------------- |
| `clk`   | input     |     1 | Clock                        |
| `rst_n` | input     |     1 | Active-low synchronous reset |

| Signal   | Direction |              Width | Description                      |
| -------- | --------- | -----------------: | -------------------------------- |
| `req`    | input     |        `NUM_PORTS` | Request from each input port     |
| `req_vc` | input     | `NUM_PORTS * VC_W` | Requested VC for each input port |


| Signal      | Direction |       Width | Description                          |
| ----------- | --------- | ----------: | ------------------------------------ |
| `grant`     | output    | `NUM_PORTS` | One-hot grant vector                 |
| `out_valid` | output    |           1 | Indicates a valid output transfer    |
| `grant_vc`  | output    |      `VC_W` | VC selected by the granted requester |

| Signal      | Direction | Width | Description                     |
| ----------- | --------- | ----: | ------------------------------- |
| `out_ready` | input     |     1 | Downstream/output accept signal |


| Signal             | Direction |                Width | Description                      |
| `rr_ptr_dbg`       | output    |             `PORT_W` | Current round-robin priority ptr |
| `credit_count_dbg` | output    | `NUM_VCS * CREDIT_W` | Current credit count per VC      |

| Signal          | Direction |     Width | Description                |
| --------------- | --------- | --------: | -------------------------- |
| `credit_return` | input     | `NUM_VCS` | Credit return pulse per VC |

## 5. Credit Model

The design uses one credit counter per virtual channel.

credit_count[0] = available downstream credits for VC0
credit_count[1] = available downstream credits for VC1

Initial reset value:

credit_count[vc] = CREDIT_DEPTH

This models an initially empty downstream buffer with all credits available.

Credit decrement rule:

If a grant fires for VCx:
    credit_count[VCx] = credit_count[VCx] - 1

Credit increment rule:

If credit_return[VCx] is high:
    credit_count[VCx] = credit_count[VCx] + 1

The credit counter must never become less than 0 or greater than CREDIT_DEPTH.

## 6. Round Robin Arbitration Policy

The arbiter maintains a round-robin pointer called rr_ptr.
The pointer indicates the first port checked in the current cycle.

The round-robin pointer updates only after a successful grant/fire event.

if out_valid && out_ready:
    rr_ptr <= granted_port + 1
else:
    rr_ptr <= rr_ptr

This prevents unfair priority movement when no actual transfer occurred.

## 7. Reset Behaviour

On reset:

grant = 0
out_valid = 0
grant_vc = 0
rr_ptr = 0
credit_count[0] = CREDIT_DEPTH
credit_count[1] = CREDIT_DEPTH

Reset behavior will be formally verified.