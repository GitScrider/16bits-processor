// =============================================================================
//  sequencer.sv  --  5-phase clock sequencer (one-hot ring counter)
// -----------------------------------------------------------------------------
//  Module 3 of the module-by-module FPGA bring-up.
//
//  This is the little "conductor" that keeps the datapath in step. A classic
//  multi-cycle CPU splits every instruction into a fixed sequence of machine
//  phases; this counter walks through those 5 phases forever, one per clock:
//
//     phase[0] = PC            (compute / present the program counter)
//     phase[1] = Fetch/Decode  (fetch the instruction word, decode it)
//     phase[2] = Execute       (run the ALU / compute the address)
//     phase[3] = Memory        (data memory read or write)
//     phase[4] = Write-back    (store the result into the register file)
//
//  Exactly ONE phase is active at any time, and the active bit marches from
//  bit 0 up to bit 4 and then wraps back to bit 0:
//
//     00001 -> 00010 -> 00100 -> 01000 -> 10000 -> 00001 -> ...
//        PC     F/D      EX      MEM      WB       PC
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: ONE-HOT ENCODING and the RING COUNTER.
//
//   A state machine has to remember "which step am I on?". The obvious way is a
//   plain binary counter (000, 001, 010, ...) — that is exactly the hello-world
//   counter from the intro. Here we use a different encoding: ONE-HOT, where the
//   state is a bag of bits with exactly one of them set. State N is "bit N is 1,
//   all others 0".
//
//   Why bother? Because each bit IS a control signal. `phase[2]` can wire
//   straight to the "Execute enable" of the ALU — no decoder needed. With binary
//   encoding you would first have to decode "counter == 2" with an AND gate. One
//   register bit per phase costs a few extra flip-flops but buys you dead-simple,
//   glitch-free enables, which is why one-hot is a favourite for FPGA control.
//
//   The "ring counter" is the simplest possible state machine: we do not add 1,
//   we just ROTATE the bits by one position each clock. Feed the top bit back
//   into the bottom and the single 1 endlessly circles the register like runners
//   on a track — hence "ring". Same idea as the binary counter (state held in a
//   register, updated every edge), only the update rule and the encoding differ.
//
//  RESET defines the INITIAL state. On reset we load 5'b00001 so the machine
//  always starts a fresh instruction at phase PC. Like regfile.sv this is a
//  SYNCHRONOUS reset (tested inside the clocked block, so it acts on a clock
//  edge). A one-hot register also has illegal states (all-zero, or several bits
//  set); the extra `else if` below is a cheap self-correcting guard that steers
//  an all-zero glitch back to a valid state instead of getting stuck.
//
//  Compatibility: uses sized literals (5'b00001) instead of '0/'1 and no
//  type'() casts, so it also compiles on ModelSim ASE 10.1d (bundled with
//  Quartus II 13.1).
// =============================================================================

module sequencer (
    input  logic       clk,    // machine clock: one phase advance per rising edge
    input  logic       rst,    // synchronous reset: reload phase = PC (00001)
    output logic [4:0] phase   // one-hot: [0]=PC [1]=Fetch/Decode [2]=Execute
                               //          [3]=Memory [4]=Write-back
);

    // ---- SEQUENTIAL: the phase register advances once per clock edge ---------
    //  Everything the machine "remembers" between edges lives in `phase`. Inside
    //  a clocked block we use non-blocking `<=` so the right-hand sides are all
    //  sampled first and the register updates as one atomic step at the edge.
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset defines the starting state: begin at phase PC.
            phase <= 5'b00001;
        end else if (phase == 5'b00000) begin
            // Self-correct: a valid one-hot value can never be all-zero, so if we
            // ever observe it (power-up X resolved to 0, a glitch, etc.) snap back
            // to the known-good start state rather than latching a dead code.
            phase <= 5'b00001;
        end else begin
            // Rotate LEFT by one: the single active bit moves up one position and
            // the top bit (phase[4]) wraps around into the bottom. That is the
            // whole ring counter -- {upper-4-bits-shifted-up, old-top-bit}.
            phase <= {phase[3:0], phase[4]};
        end
    end

endmodule
