// =============================================================================
//  regfile_demo_top.sv  --  DE2-115 board demo: the register file, interactive
// -----------------------------------------------------------------------------
//  Brings up rtl/regfile.sv on the DE2-115. Dial a value and a destination
//  register, press KEY0 to write; pick a read register and the stored value
//  shows up live on the displays. Great for seeing the 16 independent registers
//  and the write (clocked) vs read (combinational) behaviour.
//
//  Controls:
//    SW[7:0]    -> write DATA  (8-bit, zero-extended to 16)
//    SW[11:8]   -> write register RD   (0..F, shown on HEX7)
//    SW[15:12]  -> read  register RX   (0..F, shown on HEX5)
//    KEY[0]     -> WRITE  (one clean write pulse per press; LEDG0 lights while held)
//    KEY[3]     -> reset (clears all 16 registers)
//
//  Display:
//    HEX3..HEX0 -> value stored in the read register RX (16-bit, hex)
//    HEX5       -> RX (which register is being read)
//    HEX7       -> RD (which register a write would target)
//    HEX6, HEX4 -> blank
//    LEDR[15:0] -> the read value in binary
//    LEDG0      -> write button pressed
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module regfile_demo_top (
    input  logic        CLOCK_50,
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,          // active-low
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
    // --- inputs from the switches -------------------------------------------
    logic [3:0]  rd, rx;
    logic [15:0] wdata;
    assign rd    = SW[11:8];
    assign rx    = SW[15:12];
    assign wdata = {8'b00000000, SW[7:0]};

    // --- one clean write pulse per KEY0 press (falling edge, active-low) -----
    logic s0, s1, s2;
    always_ff @(posedge CLOCK_50) begin
        s0 <= KEY[0];
        s1 <= s0;
        s2 <= s1;
    end
    logic we;
    assign we = s2 & ~s1;   // KEY0 went 1 -> 0 : a press

    // --- register file under test -------------------------------------------
    logic [15:0] rx_data, ry_data;
    regfile #(.WIDTH(16), .NREG(16), .SEL(4)) u_rf (
        .clk    (CLOCK_50),
        .rst    (~KEY[3]),        // press KEY3 to clear all registers
        .we     (we),
        .rd     (rd),
        .wdata  (wdata),
        .rx     (rx),
        .ry     (4'd0),
        .rx_data(rx_data),
        .ry_data(ry_data)
    );

    // --- displays -----------------------------------------------------------
    // Right pair (HEX1-HEX0): the DATA you are dialing on SW7-0 -- updates LIVE.
    hex7seg h0 (.digit(SW[3:0]),        .seg(HEX0));
    hex7seg h1 (.digit(SW[7:4]),        .seg(HEX1));
    // Next pair (HEX3-HEX2): the value STORED in the read register RX.
    hex7seg h2 (.digit(rx_data[3:0]),   .seg(HEX2));
    hex7seg h3 (.digit(rx_data[7:4]),   .seg(HEX3));
    hex7seg h5 (.digit(rx),             .seg(HEX5));  // read register #
    hex7seg h7 (.digit(rd),             .seg(HEX7));  // write register #
    assign HEX4 = 7'b1111111;   // off (separator)
    assign HEX6 = 7'b1111111;   // off (separator)

    assign LEDR = {10'b0, SW[7:0]};   // echo the write data -- lights as you dial
    assign LEDG = {8'b0, ~KEY[0]};    // write button pressed

    // ry_data unused in this demo (second read port); tie off to avoid a warning
    logic unused;
    assign unused = |ry_data;
endmodule
