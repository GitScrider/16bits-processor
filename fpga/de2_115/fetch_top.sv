// =============================================================================
//  fetch_top.sv  --  DE2-115 integration demo #1: the FETCH stage
// -----------------------------------------------------------------------------
//  First integration step of the CPU: wire the program counter (pc.sv) to the
//  instruction memory (imem.sv) and watch the processor walk through the program
//  (logisim/programs/loop.mem, baked into imem) one instruction at a time.
//
//  A ~2 Hz tick (divided down from CLOCK_50) advances the PC automatically, so
//  the address steps 0,1,2,... and the display shows the instruction fetched at
//  each address. This is the classic "is my CPU fetching correctly?" bring-up.
//
//  Controls:
//    KEY[3] (press) -> reset the PC to 0
//    KEY[0] (hold)  -> pause (freeze the PC so you can read an instruction)
//
//  Display / LEDs:
//    HEX3..HEX0 -> the 16-bit instruction word at the current address
//    HEX5       -> the current PC (address 0..15)
//    HEX7,HEX6,HEX4 -> blank
//    LEDR[15:0] -> the instruction word (binary)
//    LEDG[8]    -> heartbeat (shows the divider is alive)
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module fetch_top (
    input  logic        CLOCK_50,
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,       // active-low
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
    // --- ~2 Hz tick from the 50 MHz clock -----------------------------------
    localparam int DIVMAX = 25_000_000;      // 0.5 s -> a step every half second
    logic [24:0] div = '0;
    logic        tick;
    always_ff @(posedge CLOCK_50) begin
        if (div >= DIVMAX - 1) div <= '0;
        else                   div <= div + 1'b1;
    end
    assign tick = (div == '0);               // 1-cycle pulse each wrap

    // --- Fetch stage: PC -> instruction memory ------------------------------
    logic [3:0]  pc_addr;
    logic [15:0] instr;

    // advance once per tick, unless KEY[0] is held (active-low: pressed = 0 = pause)
    logic step;
    assign step = tick & KEY[0];

    pc #(.W(4)) u_pc (
        .clk    (CLOCK_50),
        .rst    (~KEY[3]),          // press KEY[3] to reset PC to 0
        .en     (step),
        .load   (1'b0),
        .target (4'd0),
        .pc_out (pc_addr)
    );

    imem #(.AW(4), .DW(16)) u_imem (
        .addr  (pc_addr),
        .instr (instr)
    );

    // --- Display ------------------------------------------------------------
    hex7seg h0 (.digit(instr[3:0]),   .seg(HEX0));
    hex7seg h1 (.digit(instr[7:4]),   .seg(HEX1));
    hex7seg h2 (.digit(instr[11:8]),  .seg(HEX2));
    hex7seg h3 (.digit(instr[15:12]), .seg(HEX3));
    hex7seg h5 (.digit(pc_addr),      .seg(HEX5));  // current address
    assign HEX4 = 7'b1111111;   // off
    assign HEX6 = 7'b1111111;   // off
    assign HEX7 = 7'b1111111;   // off

    assign LEDR = {2'b00, instr};
    assign LEDG = {div[24], 8'b00000000};   // heartbeat on the leftmost green LED

    // SW unused in this demo
    logic unused;
    assign unused = |SW;
endmodule
