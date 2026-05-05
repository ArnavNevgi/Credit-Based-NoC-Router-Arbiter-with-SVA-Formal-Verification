# Limitations and Future Work

## Current Scope

This project implements and formally verifies a small credit-based NoC output-port arbiter.

The implemented scope is intentionally limited to:

- 4 input ports
- 1 output port
- 2 virtual channels
- Credit depth of 4
- Round-robin arbitration
- Per-VC credit tracking
- One-hot grant generation
- Backpressure-aware grant behavior
- SVA-based bounded formal verification

The project focuses on arbitration correctness, credit safety, bounded fairness, and formal counterexample debug.

## Limitations

### 1. Not a Full NoC Router

This project does not implement a complete NoC router. It only models the arbitration logic for one output port.

Not included:

- Full packet routing
- Routing-table lookup
- XY routing
- Multiple output ports
- Complete router pipeline
- Crossbar datapath
- Virtual-channel allocator
- Switch allocator across multiple outputs

### 2. Limited Topology Scope

The design models one shared output port with four input requesters. It does not model a mesh, torus, ring, or multi-router NoC topology.

### 3. Limited Virtual Channel Model

The design supports two virtual channels, but it does not implement full virtual-channel allocation or packet/flit buffering.

The VC ID is used only for credit checking and credit accounting.

### 4. Bounded Formal Verification

The formal verification is bounded and uses SymbiYosys/Yosys/SMTBMC with Z3.

The project proves safety and bounded fairness-style properties under configured proof depths. It does not claim complete unbounded industrial formal signoff.

### 5. Bounded Fairness, Not Full Liveness

The no-starvation checks are bounded checks under legal assumptions:

- requester remains active
- requested VC remains stable
- requested VC has available credit
- output remains ready
- reset is inactive

This is not a complete unbounded liveness proof.

### 6. No Full Deadlock-Freedom Proof

The project does not prove NoC-level deadlock freedom because it does not model a full network, routing dependencies, or cyclic channel dependencies.

### 7. No Timing Closure or Synthesis Report

The project focuses on RTL and formal verification. FPGA/ASIC synthesis, timing closure, area, and power analysis are not part of the current scope.

## Future Work

Possible extensions:

### 1. Multi-Output Router Arbiter

Extend the design from one output port to multiple output ports with independent arbitration per output.

### 2. Switch Allocator

Add a switch allocator that resolves conflicts across multiple input-output pairs.

### 3. Virtual-Channel Allocator

Add VC allocation logic for packet/flit-level virtual channel assignment.

### 4. Crossbar Datapath

Add a small crossbar datapath controlled by the grant logic.

### 5. Packet/Flit Modeling

Add flit metadata such as:

- head/body/tail flit type
- destination ID
- VC ID
- payload
- valid/ready handshake

### 6. QoS-Aware Arbitration

Extend round-robin arbitration with priority or weighted round-robin behavior.

### 7. Deadlock Checks

Model routing/resource dependencies and add formal checks for deadlock-related conditions.

### 8. Parameter Scaling

Evaluate formal proof convergence for larger configurations:

- 8 input ports
- 4 virtual channels
- deeper credit counters

### 9. Simulation Testbench

Add a lightweight self-checking SystemVerilog simulation testbench for waveform-based demonstration.

### 10. Synthesis and Timing

Run synthesis on an FPGA or ASIC-style flow to report:

- LUT/FF utilization
- maximum frequency
- critical path
- timing slack

## Final Note

The current project intentionally keeps the RTL small enough for formal verification to converge while still demonstrating realistic concepts used in NoC-style flow control and arbitration.