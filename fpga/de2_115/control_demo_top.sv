// =============================================================================
//  control_demo_top.sv  --  DE2-115 board demo: the control unit, live decode
// -----------------------------------------------------------------------------
//  Brings up rtl/control.sv on the DE2-115 as a live decoder: dial the 4-bit
//  opcode on the switches and watch exactly which control lines light up — a
//  "truth table you can flip through". Pure combinational, no clock.
//
//  Controls:
//    SW[3:0]  -> opcode (0..F)  -> shown on HEX7
//
//  Display / LEDs (each green LED = one control line, lit = asserted):
//    HEX7        -> opcode
//    HEX5        -> ULAOP (the ALU operation this opcode selects, 0..5)
//    LEDG6 = Jump      LEDG5 = Branch    LEDG4 = MemWrite   LEDG3 = MemULA
//    LEDG2 = ALUadr    LEDG1 = RegWrite  LEDG0 = ALUsrc
//    LEDR[3:0]   -> the opcode in binary
//
//  Try: addi (0) -> RegWrite+ALUsrc; add (4) -> RegWrite; slt (8) -> RegWrite;
//  beqz (9) -> Branch+ALUadr; sw (C) -> MemWrite+ALUadr; lw (D) ->
//  MemULA+ALUadr+RegWrite; j (E) -> Jump; A/B/F -> all quiet.
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module control_demo_top (
    input  logic        CLOCK_50,
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,
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
    logic [3:0] op;
    assign op = SW[3:0];

    logic       jump, branch, memwrite, memula, aluadr, regwrite, alusrc;
    logic [2:0] ulaop;

    control u_ctrl (
        .op(op), .jump(jump), .branch(branch), .memwrite(memwrite),
        .memula(memula), .aluadr(aluadr), .ulaop(ulaop),
        .regwrite(regwrite), .alusrc(alusrc)
    );

    // --- displays ------------------------------------------------------------
    hex7seg h7 (.digit(op),            .seg(HEX7));  // opcode
    hex7seg h5 (.digit({1'b0, ulaop}), .seg(HEX5));  // ALU operation selected
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX6 = 7'b1111111;

    // --- control lines on the green LEDs ------------------------------------
    assign LEDG = {2'b00, jump, branch, memwrite, memula, aluadr, regwrite, alusrc};
    assign LEDR = {14'b0, op};

    // CLOCK_50 / KEY unused (combinational demo)
    logic unused;
    assign unused = CLOCK_50 & (&KEY);
endmodule
