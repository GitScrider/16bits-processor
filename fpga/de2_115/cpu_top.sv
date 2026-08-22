// =============================================================================
//  cpu_top.sv  --  DE2-115 board demo: the WHOLE processor running loop.mem
// -----------------------------------------------------------------------------
//  The grand finale: rtl/cpu.sv (PC + instruction memory + ALU + register file
//  + data memory, all conducted by the 5-phase ring sequencer) executing the
//  original demo program baked into imem.sv, slow enough to watch.
//
//  A multicycle instruction takes 5 clocks, and at 50 MHz that is invisible, so
//  this wrapper feeds the CPU a SLOW, controllable clock:
//    * FREE-RUN  (SW17 = 1): a ~3 Hz tick auto-advances one machine phase at a
//                             time -- watch the phase light march and the loop run.
//    * SINGLE-STEP (SW17 = 0): KEY0 advances exactly one phase per press, so you
//                             can walk PC -> Fetch -> Execute -> Memory -> Writeback.
//
//  Controls:
//    SW17      -> mode: 1 = free-run, 0 = single-step (one phase per KEY0 press)
//    KEY0      -> STEP one machine phase (single-step mode)
//    KEY3      -> RESET (PC = 0, registers = 0, back to phase 1)
//
//  Display / LEDs:
//    HEX7      -> PC (current instruction address) -- watch it jump around the loop
//    HEX5      -> opcode of the current instruction
//    HEX2 HEX1 HEX0 -> the VALUES held in r1, r2, r3 -- watch r2 count 1,2,3,0 as it runs
//    LEDG4..0  -> the one-hot machine phase (PC/Fetch/Execute/Memory/Writeback)
//    LEDG7     -> mode (lit = free-run)
//    LEDG8     -> ~1 Hz heartbeat
//    LEDR15..0 -> the current instruction word, in binary
//
//  Target: DE2-115, Cyclone IV E, EP4CE115F29C7.
// =============================================================================

module cpu_top (
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
    // --- slow clock: ~3 Hz phase tick + ~0.75 Hz heartbeat -----------------
    localparam int DIV = 16_000_000;      // 50 MHz / 16e6 ~= 3 phase-steps/second (easy to film)
    logic [23:0] divcnt;
    logic        tick, blink;
    always_ff @(posedge CLOCK_50) begin
        if (divcnt == DIV - 1) begin
            divcnt <= 24'd0;
            tick   <= 1'b1;
            blink  <= ~blink;
        end else begin
            divcnt <= divcnt + 1'b1;
            tick   <= 1'b0;
        end
    end

    // --- synchronize buttons (clean edges) ---------------------------------
    logic [2:0] k0, k3;
    always_ff @(posedge CLOCK_50) begin
        k0 <= {k0[1:0], KEY[0]};
        k3 <= {k3[1:0], KEY[3]};
    end
    logic step_pulse, rst_req;
    assign step_pulse = k0[2] & ~k0[1];   // KEY0 press -> one-cycle pulse
    assign rst_req    = ~k3[1];           // KEY3 held (active-low), synchronized

    // --- build the CPU's slow clock ----------------------------------------
    // One rising edge per "event": a tick (free-run) or a press (single-step).
    // OR in reset so the CPU's synchronous reset always gets a clock edge.
    logic mode;
    assign mode = SW[17];
    logic advance;
    assign advance = mode ? tick : step_pulse;
    logic cpu_clk;
    always_ff @(posedge CLOCK_50)
        cpu_clk <= advance | rst_req;     // registered -> clean, glitch-free clock

    // --- the processor -----------------------------------------------------
    logic [3:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    cpu u_cpu (
        .clk(cpu_clk), .rst(rst_req),
        .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val)
    );

    // --- mirror r1, r2, r3 by snooping the write-back bus ------------------
    // Latch each register's new value whenever the CPU writes it. Since the
    // mirror updates on the SAME edge and with the SAME value as the register
    // file, it tracks the real register exactly -- so the displays show the
    // actual register CONTENTS, and you watch the numbers change as the loop runs.
    logic [15:0] r1v, r2v, r3v;
    always_ff @(posedge cpu_clk) begin
        if (rst_req) begin
            r1v <= 16'h0000; r2v <= 16'h0000; r3v <= 16'h0000;
        end else if (wb_we) begin
            if (wb_rd == 4'd1) r1v <= wb_val;
            if (wb_rd == 4'd2) r2v <= wb_val;   // the loop counter: 1,2,3,0,...
            if (wb_rd == 4'd3) r3v <= wb_val;   // the slt flag: 0 / 1
        end
    end

    // --- displays -----------------------------------------------------------
    hex7seg h7 (.digit(pc_out),       .seg(HEX7));  // program counter
    hex7seg h5 (.digit(instr[15:12]), .seg(HEX5));  // opcode (OP field)
    hex7seg h2 (.digit(r1v[3:0]),     .seg(HEX2));  // value of r1
    hex7seg h1 (.digit(r2v[3:0]),     .seg(HEX1));  // value of r2 (the loop counter)
    hex7seg h0 (.digit(r3v[3:0]),     .seg(HEX0));  // value of r3 (the slt flag)
    assign HEX3 = 7'b1111111;   // off (separator)
    assign HEX4 = 7'b1111111;   // off (separator)
    assign HEX6 = 7'b1111111;   // off (separator)

    assign LEDR = {2'b00, instr};                    // instruction word in binary
    assign LEDG = {blink, mode, 2'b00, phase};       // heartbeat, mode, phase (one-hot)

    // KEY1, KEY2 and the lower switches are unused
    logic unused;
    assign unused = (|SW[16:0]) & KEY[1] & KEY[2];
endmodule
