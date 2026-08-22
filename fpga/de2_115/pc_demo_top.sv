// =============================================================================
//  pc_demo_top.sv  --  DE2-115 board demo: the program counter, live
// -----------------------------------------------------------------------------
//  Brings up rtl/pc.sv on the DE2-115 so you can WATCH the instruction address
//  advance, wrap, jump and reset with your own eyes. The PC is a 4-bit register
//  (addresses the 16-word instruction memory), so it counts 0..F and wraps.
//
//  Two ways to drive it, chosen by SW17:
//    * FREE-RUN  (SW17 = 1): a slow ~2 Hz tick auto-advances the PC. Watch it
//                             climb 0->1->...->F->0 on HEX0 / the red LEDs.
//    * SINGLE-STEP (SW17 = 0): the PC only moves when YOU press KEY0. One clean
//                             +1 per press -- perfect for stepping instruction
//                             by instruction.
//
//  Controls:
//    SW17       -> mode: 1 = free-run (auto), 0 = single-step (manual KEY0)
//    SW[3:0]    -> jump TARGET address (0..F), shown live on HEX7
//    KEY0       -> STEP: advance PC by +1 (single-step mode; one pulse/press)
//    KEY1       -> LOAD: jump the PC to the SW[3:0] target (beats a step)
//    KEY3       -> RESET: force PC back to address 0
//
//  Display / LEDs:
//    HEX0       -> current PC value (the instruction address), hex 0..F
//    HEX7       -> the target a LOAD (KEY1) would jump to  = SW[3:0]
//    LEDR[3:0]  -> current PC in binary (see it count in base 2)
//    LEDG0      -> ~1 Hz heartbeat of the free-run clock (so you see it ticking)
//    LEDG8      -> mode indicator (lit = free-run)
//
//  This wraps rtl/pc.sv unchanged; everything here is just plumbing to turn the
//  50 MHz board clock into something a human can watch, plus clean one-pulse-
//  per-press buttons (the same debounce-by-edge trick used in regfile_demo_top).
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module pc_demo_top (
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
    // --- slow clock: a 1-cycle "tick" pulse ~2x per second ------------------
    // 50 MHz / 25e6 = 2 pulses/second. The counter counts CLOCK_50 edges; when
    // it reaches the top it emits a single-cycle `tick` and restarts. We also
    // toggle `blink` on every tick to get a ~1 Hz square wave for the heartbeat.
    localparam int DIV = 25_000_000;      // CLOCK_50 cycles between ticks
    logic [24:0] divcnt;                  // 2**25 = 33.5M > DIV, so it fits
    logic        tick;
    logic        blink;

    always_ff @(posedge CLOCK_50) begin
        if (divcnt == DIV - 1) begin
            divcnt <= 25'd0;
            tick   <= 1'b1;               // one-cycle enable pulse
            blink  <= ~blink;             // heartbeat: flips ~once per 0.5s
        end else begin
            divcnt <= divcnt + 1'b1;
            tick   <= 1'b0;
        end
    end

    // --- clean one-pulse-per-press for KEY0 (step) and KEY1 (load) ----------
    // KEY is active-low, so a PRESS is a falling edge (1 -> 0). We synchronize
    // then detect the edge, yielding exactly one 1-cycle pulse per press.
    logic k0_0, k0_1, k0_2;
    logic k1_0, k1_1, k1_2;
    always_ff @(posedge CLOCK_50) begin
        k0_0 <= KEY[0]; k0_1 <= k0_0; k0_2 <= k0_1;
        k1_0 <= KEY[1]; k1_1 <= k1_0; k1_2 <= k1_1;
    end
    logic step_pulse, load_pulse;
    assign step_pulse = k0_2 & ~k0_1;     // KEY0 press
    assign load_pulse = k1_2 & ~k1_1;     // KEY1 press

    // --- choose the advance-enable by mode ----------------------------------
    logic mode;                           // 1 = free-run, 0 = single-step
    assign mode = SW[17];
    logic en;
    assign en = mode ? tick : step_pulse;

    // --- the module under test ----------------------------------------------
    logic [3:0] pc_out;
    pc #(.W(4)) u_pc (
        .clk    (CLOCK_50),
        .rst    (~KEY[3]),                // press KEY3 -> PC = 0
        .en     (en),                     // +1 on a tick (free-run) or a press
        .load   (load_pulse),             // KEY1 -> jump to target (beats en)
        .target (SW[3:0]),                // jump destination
        .pc_out (pc_out)
    );

    // --- displays -----------------------------------------------------------
    hex7seg h0 (.digit(pc_out),  .seg(HEX0));   // current instruction address
    hex7seg h7 (.digit(SW[3:0]), .seg(HEX7));   // target a LOAD would jump to
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign HEX6 = 7'b1111111;

    assign LEDR = {14'b0, pc_out};        // PC in binary on the red LEDs
    assign LEDG = {mode, 7'b0000000, blink};  // LEDG8 = mode, LEDG0 = heartbeat
endmodule
