// =============================================================================
//  sequencer_demo_top.sv  --  DE2-115 board demo: the 5-phase sequencer, live
// -----------------------------------------------------------------------------
//  Brings up rtl/sequencer.sv on the DE2-115 as a "marching light". The
//  sequencer is a one-hot ring counter of 5 machine phases -- exactly one bit is
//  set, and each clock rotates it one position:
//
//     00001 -> 00010 -> 00100 -> 01000 -> 10000 -> 00001 -> ...
//       PC       F/D      EX       MEM      WB       PC
//
//  Map those 5 bits onto 5 LEDs and you get a single point of light marching
//  around a ring forever -- the clearest possible picture of "one-hot" and
//  "ring counter".
//
//  A NOTE ON THE CLOCK: sequencer.sv advances on EVERY clock edge (it has no
//  enable). At the board's 50 MHz that is far too fast to see, so this wrapper
//  feeds the sequencer a SLOW, controllable clock instead: a ~2 Hz tick in
//  free-run, or one clean edge per button press in single-step. In the real CPU
//  the sequencer is clocked at full speed; here we just slow it down to watch.
//
//  Controls:
//    SW17     -> mode: 1 = free-run (~2 Hz, marches on its own), 0 = single-step
//    KEY0     -> STEP: advance one phase (single-step mode)
//    KEY3     -> RESET: back to phase 1 (PC), one-hot 00001
//
//  Display / LEDs:
//    LEDG4..LEDG0 -> the 5 one-hot phase bits (the marching light)
//                    LEDG0 = PC  LEDG1 = Fetch/Decode  LEDG2 = Execute
//                    LEDG3 = Memory  LEDG4 = Write-back
//    LEDR4..LEDR0 -> the same 5 bits in red, for extra visibility
//    HEX0     -> the active phase number, 1..5
//    LEDG7    -> mode (lit = free-run)
//    LEDG8    -> ~1 Hz heartbeat (the slow clock is alive)
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module sequencer_demo_top (
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
    // --- slow clock: ~2 Hz tick + ~1 Hz heartbeat --------------------------
    localparam int DIV = 25_000_000;      // 50 MHz / 25e6 = 2 ticks/second
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

    // --- synchronize the buttons (clean edges) ------------------------------
    logic [2:0] k0, k3;
    always_ff @(posedge CLOCK_50) begin
        k0 <= {k0[1:0], KEY[0]};
        k3 <= {k3[1:0], KEY[3]};
    end
    logic step_pulse;                     // KEY0 press -> one-cycle pulse
    assign step_pulse = k0[2] & ~k0[1];
    logic rst_req;                        // KEY3 held (active-low, synchronized)
    assign rst_req = ~k3[1];

    // --- build the sequencer's slow clock -----------------------------------
    // One rising edge per "event": a tick (free-run) or a press (single-step).
    // We OR in the reset so a synchronous reset always gets a clock edge to act.
    logic mode;
    assign mode = SW[17];
    logic advance;
    assign advance = mode ? tick : step_pulse;

    logic seq_clk;
    always_ff @(posedge CLOCK_50)
        seq_clk <= advance | rst_req;     // registered -> a clean, glitch-free clock

    // --- the module under test ----------------------------------------------
    logic [4:0] phase;
    sequencer u_seq (
        .clk   (seq_clk),
        .rst   (rst_req),
        .phase (phase)
    );

    // --- active phase number (1..5) for the display -------------------------
    logic [3:0] phase_num;
    always_comb begin
        unique case (phase)
            5'b00001: phase_num = 4'd1;   // PC
            5'b00010: phase_num = 4'd2;   // Fetch/Decode
            5'b00100: phase_num = 4'd3;   // Execute
            5'b01000: phase_num = 4'd4;   // Memory
            5'b10000: phase_num = 4'd5;   // Write-back
            default:  phase_num = 4'd0;   // (illegal / transient one-hot)
        endcase
    end

    // --- displays -----------------------------------------------------------
    hex7seg h0 (.digit(phase_num), .seg(HEX0));   // which phase (1..5)
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign HEX6 = 7'b1111111;
    assign HEX7 = 7'b1111111;

    assign LEDR = {13'b0, phase};                    // marching light (red)
    assign LEDG = {blink, mode, 2'b00, phase};       // heartbeat, mode, marching light (green)

    // lower switches / KEY1 / KEY2 unused
    logic unused;
    assign unused = (|SW[16:0]) & KEY[1] & KEY[2];
endmodule
