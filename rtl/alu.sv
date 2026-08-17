// =============================================================================
//  alu.sv  --  16-bit ALU ("ULA") for the 16-bit RISC processor
// -----------------------------------------------------------------------------
//  Module 1 of the module-by-module FPGA bring-up.
//
//  Mirrors the Logisim "ULA" sub-circuit: two 16-bit operands, a 3-bit ULAOP
//  select, a 16-bit RESULT and a ZERO flag.
//
//  ULAOP encoding (from the design brief):
//    000 = add           (add,  addi)
//    001 = subtract      (sub,  subi)
//    010 = multiply      (mul,  muli)   -> lower WIDTH bits of the product
//    011 = divide        (div,  divi)   -> integer quotient (div-by-0 guarded)
//    100 = set-less-than (slt)          -> 1 if a <  b (signed), else 0
//    101 = subtract      (beqz)         -> same as 001; ZERO flag drives beqz
//
//  ZERO is asserted when RESULT == 0 (used by the branch unit for beqz).
//
//  Notes for the FPGA / synthesis:
//   * add/sub/slt are cheap combinational logic.
//   * multiply infers a DSP block on the Cyclone IV E -- fine combinationally.
//   * divide here is COMBINATIONAL and will be slow / limit fMAX. This matches
//     the "division cannot really happen in one clock" caveat in the design
//     brief. A later revision can replace it with an iterative multi-cycle
//     divider. Kept combinational for now so this first module is easy to test.
//
//  Signedness: arithmetic is two's-complement; slt and divide are SIGNED, which
//  matches the "A<Y" comparator (with sign-extend) drawn in the schematic.
// =============================================================================

module alu #(
    parameter int WIDTH = 16
) (
    input  logic [WIDTH-1:0] a,      // Dado1
    input  logic [WIDTH-1:0] b,      // Dado2
    input  logic [2:0]       ulaop,  // operation select
    output logic [WIDTH-1:0] result, // ULA RESULT
    output logic             zero    // ZERO flag (result == 0)
);

    // ULAOP opcodes -- keep in sync with docs/isa.md and the control unit.
    localparam logic [2:0] OP_ADD  = 3'b000;
    localparam logic [2:0] OP_SUB  = 3'b001;
    localparam logic [2:0] OP_MUL  = 3'b010;
    localparam logic [2:0] OP_DIV  = 3'b011;
    localparam logic [2:0] OP_SLT  = 3'b100;
    localparam logic [2:0] OP_BEQZ = 3'b101; // subtract; ZERO used by beqz

    // Signed views of the operands for slt / div.
    logic signed [WIDTH-1:0] sa, sb;
    assign sa = a;
    assign sb = b;

    // Sized literals (no unsized '0 / type'() casts) keep this compatible with
    // ModelSim ASE 10.1d, the simulator bundled with Quartus II 13.1.
    localparam logic [WIDTH-1:0] ZERO16 = {WIDTH{1'b0}};

    always_comb begin
        unique case (ulaop)
            OP_ADD  : result = a + b;
            OP_SUB  : result = a - b;
            OP_BEQZ : result = a - b;                        // same datapath as SUB
            OP_MUL  : result = a * b;                        // lower WIDTH bits
            OP_DIV  : result = (b == ZERO16) ? ZERO16 : (sa / sb); // signed, guard /0
            OP_SLT  : result = (sa < sb) ? {{(WIDTH-1){1'b0}}, 1'b1} : ZERO16;
            default : result = ZERO16;                       // reserved codes
        endcase
    end

    assign zero = (result == ZERO16);

endmodule
