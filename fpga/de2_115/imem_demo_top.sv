// =============================================================================
//  imem_demo_top.sv  --  DE2-115 board demo: the instruction memory, live
// -----------------------------------------------------------------------------
//  Brings up rtl/imem.sv on the DE2-115 as a "read the ROM with your fingers"
//  demo. Dial an address on the switches and the 16-bit instruction word stored
//  there appears instantly on the displays -- no clock, no button, because the
//  ROM read is COMBINATIONAL (assign instr = mem[addr]). That immediacy is the
//  whole point of an asynchronous read: change the address, the data follows.
//
//  The ROM holds the 7-word demo program baked into imem.sv:
//     addr 0: 0000   addr 1: 0112   addr 2: 0221   addr 3: 8312
//     addr 4: 9032   addr 5: 0240   addr 6: e003   addr 7..F: 0000 (empty)
//
//  BONUS -- the instruction FORMAT is visible for free. A 16-bit instruction is
//  four 4-bit fields [ OP | RD | RX | RY/I ], and each field is exactly one hex
//  digit. So the four right-hand displays line up one-to-one with the fields:
//     HEX3 = OP    HEX2 = RD    HEX1 = RX    HEX0 = RY/I
//
//  Controls:
//    SW[3:0]   -> address (0..F), shown on HEX7
//
//  Display / LEDs:
//    HEX7      -> the address being read
//    HEX3 HEX2 HEX1 HEX0 -> the 16-bit instruction word = OP RD RX RY/I
//    LEDR[15:0]-> the same instruction word, in binary
//    LEDG0     -> lit when this address holds a (non-zero) program word
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module imem_demo_top (
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
    logic [3:0]  addr;
    logic [15:0] instr;
    assign addr = SW[3:0];

    // The module under test: its initial-block program becomes the ROM's
    // power-on contents when Quartus builds the design.
    imem #(.AW(4), .DW(16)) u_imem (
        .addr (addr),
        .instr(instr)
    );

    // --- displays -----------------------------------------------------------
    hex7seg h7 (.digit(addr),         .seg(HEX7));  // which address we are reading
    // the 16-bit word, one hex digit per instruction field:
    hex7seg h3 (.digit(instr[15:12]), .seg(HEX3));  // OP
    hex7seg h2 (.digit(instr[11:8]),  .seg(HEX2));  // RD
    hex7seg h1 (.digit(instr[7:4]),   .seg(HEX1));  // RX
    hex7seg h0 (.digit(instr[3:0]),   .seg(HEX0));  // RY / I
    assign HEX4 = 7'b1111111;   // off (separator)
    assign HEX5 = 7'b1111111;   // off (separator)
    assign HEX6 = 7'b1111111;   // off (separator)

    assign LEDR = {2'b00, instr};        // instruction word in binary
    assign LEDG = {8'b0, |instr};        // LEDG0: this address holds a program word

    // CLOCK_50 / KEY unused (combinational demo)
    logic unused;
    assign unused = CLOCK_50 & (&KEY);
endmodule
