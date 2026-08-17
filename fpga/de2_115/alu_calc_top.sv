// =============================================================================
//  alu_calc_top.sv  --  DE2-115 board demo #1: interactive ALU calculator
// -----------------------------------------------------------------------------
//  App #1 from the roadmap. Brings up the ALU (rtl/alu.sv) as a standalone,
//  fully interactive block on the Altera/Intel DE2-115 (Cyclone IV E,
//  EP4CE115F29C7). No clock needed for the datapath -- the result is combinational
//  and updates live as you flip the switches.
//
//  Controls (all live):
//    SW[7:0]   -> operand A  (8-bit,  sign-extended to 16)
//    SW[14:8]  -> operand B  (7-bit,  sign-extended to 16)
//    SW[17:15] -> ULAOP      (000 add, 001 sub, 010 mul, 011 div, 100 slt, 101 sub/beqz)
//
//  Display:
//    HEX3..HEX0 -> 16-bit RESULT in hexadecimal
//    HEX5       -> current operation code (0..5)
//    HEX7,HEX6  -> blank
//    LEDR[15:0] -> RESULT bits (binary view)
//    LEDG[0]    -> ZERO flag
//    LEDG[8]    -> sign bit (RESULT[15], i.e. result is negative in two's complement)
//
//  Port names follow the Terasic DE2-115 convention so the board's official pin
//  assignment file (from the DE2-115 System CD, or via the Pin Planner) maps
//  directly. Do NOT hand-type pin numbers -- import the vendor .qsf/.csv.
//
//  KEY inputs are exposed but unused in this first demo (active-low on the board).
//  Suggested exercise: latch RESULT into a holding register on KEY[0] and show it
//  on HEX7..HEX4, so you can compute, change the switches, and compare.
// =============================================================================

module alu_calc_top (
    input  logic        CLOCK_50,
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,     // active-low push buttons (unused here)
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5,
    output logic [6:0]  HEX6,
    output logic [6:0]  HEX7
);
    // --- Gather inputs -------------------------------------------------------
    logic [2:0]  ulaop;
    logic [15:0] a, b, result;
    logic        zero;

    assign ulaop = SW[17:15];

    // Sign-extend the switch operands up to 16 bits.
    assign a = {{8{SW[7]}},  SW[7:0]};    // 8-bit signed A
    assign b = {{9{SW[14]}}, SW[14:8]};   // 7-bit signed B

    // --- ALU under test ------------------------------------------------------
    alu #(.WIDTH(16)) u_alu (
        .a(a), .b(b), .ulaop(ulaop), .result(result), .zero(zero)
    );

    // --- Displays ------------------------------------------------------------
    hex7seg h0 (.digit(result[3:0]),   .seg(HEX0));
    hex7seg h1 (.digit(result[7:4]),   .seg(HEX1));
    hex7seg h2 (.digit(result[11:8]),  .seg(HEX2));
    hex7seg h3 (.digit(result[15:12]), .seg(HEX3));
    hex7seg h4 (.digit(4'h0),          .seg(HEX4)); // blank-ish (shows 0)
    hex7seg h5 (.digit({1'b0, ulaop}), .seg(HEX5)); // operation code 0..5
    assign HEX6 = 7'b1111111; // off
    assign HEX7 = 7'b1111111; // off

    // --- LEDs ----------------------------------------------------------------
    // Drive LEDG in a SINGLE assignment (one net = one driver): bit 0 = ZERO flag,
    // bit 8 = sign bit, the middle bits off.
    assign LEDR = {2'b00, result};
    assign LEDG = {result[15], 7'b0000000, zero};

    // CLOCK_50 / KEY intentionally unused in this combinational demo.
    logic unused;
    assign unused = CLOCK_50 & (&KEY);

endmodule
