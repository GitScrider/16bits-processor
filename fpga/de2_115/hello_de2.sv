// =============================================================================
//  hello_de2.sv  --  DE2-115 "hello world" / board smoke test
// -----------------------------------------------------------------------------
//  Proves the whole toolchain end to end: synthesis, pin assignment, JTAG
//  programming, plus the board's clock and basic I/O. No CPU involved.
//
//  What you should see on a working board:
//    * "HELLO" spelled across the 7-segment displays HEX4..HEX0.
//    * A green LED (LEDG) "marching" pattern -- proves CLOCK_50 is alive.
//    * Every red LED (LEDR) mirrors the slide switch below it -- flip a switch,
//      its LED turns on. Proves combinational I/O and pin mapping.
//    * KEY[0] (active-low) freezes the marching LEDs while held.
//
//  Target: Altera/Intel DE2-115, Cyclone IV E, EP4CE115F29C7.
//  Port names follow the Terasic DE2-115 convention so the board pin
//  assignment file maps directly.
// =============================================================================

module hello_de2 (
    input  logic        CLOCK_50,
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,       // active-low push buttons
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
    // --- Switches mirror to the red LEDs (combinational I/O test) ------------
    assign LEDR = SW;

    // --- Free-running counter off the 50 MHz clock (clock/sequential test) ---
    logic [31:0] count = 32'd0;
    always_ff @(posedge CLOCK_50) begin
        if (KEY[0]) count <= count + 32'd1;  // KEY[0] released (=1): keep counting
        // KEY[0] pressed (=0): freeze, so you can confirm it's really the clock
    end

    // Marching pattern on the 9 green LEDs, driven by high counter bits so it is
    // visible to the eye (~a few Hz).
    assign LEDG = count[26:18];

    // --- Spell "HELLO" on HEX4..HEX0 -----------------------------------------
    //  DE2-115 7-seg is ACTIVE-LOW; bit order seg[6:0] = { g,f,e,d,c,b,a }.
    localparam logic [6:0] CH_H = 7'b0001001; // b,c,e,f,g
    localparam logic [6:0] CH_E = 7'b0000110; // a,d,e,f,g
    localparam logic [6:0] CH_L = 7'b1000111; // d,e,f
    localparam logic [6:0] CH_O = 7'b1000000; // a,b,c,d,e,f  (same shape as 0)
    localparam logic [6:0] BLANK = 7'b1111111; // all segments off

    assign HEX4 = CH_H;
    assign HEX3 = CH_E;
    assign HEX2 = CH_L;
    assign HEX1 = CH_L;
    assign HEX0 = CH_O;
    assign HEX5 = BLANK;
    assign HEX6 = BLANK;
    assign HEX7 = BLANK;

endmodule
