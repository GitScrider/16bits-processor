// =============================================================================
//  fetch_top.sv  --  DE2-115 integration demo #1: the FETCH stage (PC + imem)
// -----------------------------------------------------------------------------
//  The first time two modules work TOGETHER: the program counter (pc.sv) drives
//  the address of the instruction memory (imem.sv), so as the PC counts the ROM
//  hands back the instruction stored at each address. That is exactly what a CPU
//  does every cycle in its fetch phase -- "what instruction is at the address the
//  PC is pointing to?" -- built here from the two blocks you already brought up
//  one at a time.
//
//  The imem holds the 7-word demo program:
//     addr 0:0000  1:0112  2:0221  3:8312  4:9032  5:0240  6:e003  7..F:0000
//
//  Two ways to walk it, chosen by SW17:
//    * FREE-RUN  (SW17 = 1): a ~2 Hz tick auto-advances the PC. Watch the address
//                             climb and the instruction change on its own.
//    * SINGLE-STEP (SW17 = 0): the PC only moves when YOU press KEY0 -- one
//                             instruction per press, so you can read each one.
//
//  Controls:
//    SW17     -> mode: 1 = free-run (auto), 0 = single-step (manual KEY0)
//    KEY0     -> STEP: advance to the next instruction (single-step mode)
//    KEY3     -> RESET: PC back to address 0
//
//  Display / LEDs:
//    HEX7     -> current address (the PC, 0..F)
//    HEX3 HEX2 HEX1 HEX0 -> the 16-bit instruction fetched = OP RD RX RY/I
//    LEDR[15:0] -> that instruction word in binary
//    LEDG8    -> ~1 Hz heartbeat (the divider is alive)
//    LEDG1    -> mode (lit = free-run)
//    LEDG0    -> lit when this address holds a (non-zero) program word
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
    // --- slow clock: a 1-cycle "tick" ~2x/second, plus a ~1 Hz heartbeat ------
    localparam int DIV = 25_000_000;      // CLOCK_50 cycles between ticks
    logic [24:0] divcnt;
    logic        tick;
    logic        blink;
    always_ff @(posedge CLOCK_50) begin
        if (divcnt == DIV - 1) begin
            divcnt <= 25'd0;
            tick   <= 1'b1;
            blink  <= ~blink;
        end else begin
            divcnt <= divcnt + 1'b1;
            tick   <= 1'b0;
        end
    end

    // --- one clean pulse per KEY0 press (falling edge, active-low) -----------
    logic k0_0, k0_1, k0_2;
    always_ff @(posedge CLOCK_50) begin
        k0_0 <= KEY[0]; k0_1 <= k0_0; k0_2 <= k0_1;
    end
    logic step_pulse;
    assign step_pulse = k0_2 & ~k0_1;

    // --- advance enable by mode ---------------------------------------------
    logic mode;
    assign mode = SW[17];
    logic en;
    assign en = mode ? tick : step_pulse;

    // --- FETCH: program counter drives the instruction memory ----------------
    logic [3:0]  pc_addr;
    logic [15:0] instr;

    pc #(.W(4)) u_pc (
        .clk    (CLOCK_50),
        .rst    (~KEY[3]),          // press KEY3 -> PC = 0
        .en     (en),               // +1 per tick (free-run) or per press (step)
        .load   (1'b0),             // no jumps in this demo: fetch walks in order
        .target (4'd0),
        .pc_out (pc_addr)
    );

    imem #(.AW(4), .DW(16)) u_imem (
        .addr  (pc_addr),
        .instr (instr)
    );

    // --- displays -----------------------------------------------------------
    hex7seg h7 (.digit(pc_addr),      .seg(HEX7));  // current address
    hex7seg h3 (.digit(instr[15:12]), .seg(HEX3));  // OP
    hex7seg h2 (.digit(instr[11:8]),  .seg(HEX2));  // RD
    hex7seg h1 (.digit(instr[7:4]),   .seg(HEX1));  // RX
    hex7seg h0 (.digit(instr[3:0]),   .seg(HEX0));  // RY / I
    assign HEX4 = 7'b1111111;   // off (separator)
    assign HEX5 = 7'b1111111;   // off (separator)
    assign HEX6 = 7'b1111111;   // off (separator)

    assign LEDR = {2'b00, instr};                 // instruction word in binary
    assign LEDG = {blink, 6'b000000, mode, |instr};  // heartbeat / mode / has-word

    // KEY1, KEY2 and the lower switches are unused in this demo.
    logic unused;
    assign unused = (|SW[16:0]) & KEY[1] & KEY[2];
endmodule
