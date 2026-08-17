// =============================================================================
//  pc.sv  --  program counter ("PC") for the 16-bit RISC processor
// -----------------------------------------------------------------------------
//  Module 3 of the module-by-module FPGA bring-up.
//
//  The program counter is the instruction-address register: it holds the address
//  of the instruction currently being fetched from the 16-word instruction
//  memory. On each PC-update step it does exactly ONE of three things:
//
//     * LOAD  a branch/jump target  (control asserts `load`)   -- highest priority
//     * ADVANCE by +1 to the next sequential instruction (`en`)
//     * HOLD  its current value     (neither load nor en)
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: this is a REGISTER WITH ENABLE + LOAD, and it shows off two
//  ideas that come up everywhere in sequential logic.
//
//   1. IT REMEMBERS. Unlike the ALU (pure combinational — output follows input
//      immediately), the PC stores a value that persists between clock edges.
//      Anything that must be remembered lives in an `always_ff @(posedge clk)`
//      block and updates with the non-blocking assignment `<=`.
//
//   2. PRIORITY. The behaviour is written as an if / else-if CHAIN, and the
//      order matters. `rst` beats everything; `load` beats `en`; `en` is the
//      normal case; and if none of them is asserted the register simply keeps
//      its old value (the "hold" case is the implicit `else` — we write no
//      assignment, so the flip-flops re-load themselves unchanged). Because the
//      cases are checked top-to-bottom, only the first matching branch fires:
//      that is exactly what "load takes priority over en" means in hardware.
//
//  This is really the humble "counter" from a hello-world blink demo, dressed up
//  with an enable (so it only counts during the PC-update phase) and a load port
//  (so jumps and taken branches can redirect the fetch address).
//
//  RESET: SYNCHRONOUS. `rst` is tested INSIDE the clocked block, so a reset only
//  takes effect on a rising clock edge. This is the safe FPGA default (same
//  convention as regfile.sv). The asynchronous alternative would list the reset
//  in the sensitivity list: `always_ff @(posedge clk or posedge rst)`.
//
//  WIDTH: W defaults to 4, which addresses the 16-word (2**4) instruction
//  memory. The counter is a plain unsigned adder, so it WRAPS naturally: from
//  the top value (all ones) a +1 rolls over back to 0 at 2**W. No special
//  wrap logic is needed — the modulo behaviour of fixed-width arithmetic gives
//  it to us for free.
//
//  Compatibility: uses sized literals ({W{1'b0}}, 1'b1) instead of '0 / '1 and
//  avoids type'() casts, so it compiles on ModelSim ASE 10.1d (bundled with
//  Quartus II 13.1).
// =============================================================================

module pc #(
    parameter int W = 4          // PC width in bits; 2**W = size of instr. memory
) (
    input  logic         clk,    // fetch clock
    input  logic         rst,    // synchronous reset: forces PC back to 0
    input  logic         en,     // advance enable: +1 during the PC-update phase
    input  logic         load,   // load `target` (jump / branch-taken); beats `en`
    input  logic [W-1:0] target, // branch/jump destination address
    output logic [W-1:0] pc_out  // current instruction address
);

    // ---- SEQUENTIAL: the PC only changes on a rising clock edge -------------
    // The if / else-if chain encodes the priority order:
    //   rst  >  load  >  en  >  (hold).
    // Whichever condition is true FIRST wins; the rest are ignored this edge.
    always_ff @(posedge clk) begin
        if (rst)
            pc_out <= {W{1'b0}};        // synchronous clear to address 0
        else if (load)
            pc_out <= target;           // jump / taken branch: redirect fetch
        else if (en)
            pc_out <= pc_out + 1'b1;     // normal advance; wraps at 2**W
        // else: neither load nor en -> HOLD (no assignment => keep old value)
    end

endmodule
