// =============================================================================
//  gpu_top.sv  --  DE2-115 demo: the CPU + a tile "GPU" bouncing 3 balls on VGA
// -----------------------------------------------------------------------------
//  The capstone application. The CPU runs the 3-ball gravity program (grav3):
//  it computes each ball's position and DRAWS it by storing a colour index into
//  a tile of the framebuffer (a memory-mapped store). The tile GPU (vga_gpu)
//  reads that framebuffer and paints the 20x15 grid of 32x32-pixel cells to a
//  640x480 VGA display. CPU = physics; GPU = pixels; framebuffer in between.
//
//  Two clocks from the board's 50 MHz:
//    * pixel clock  = 50 MHz / 2 = 25 MHz  (the VGA raster)
//    * CPU clock    = 50 MHz / 2^13 ~= 6 kHz  (slow, so the balls fall gently)
//
//  Controls:  KEY[3] = reset.  SW[17] = freeze (pause the physics).
//  Status  :  LEDG[4:0] = machine phase,  LEDR[8:0] = last cell address written.
//
//  Compatibility: sized literals only -> ModelSim ASE 10.1d clean.
// =============================================================================

module gpu_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,        // KEY[3] = reset (active-low)
    input  logic [17:0] SW,         // SW[17] = freeze physics

    output logic [7:0]  VGA_R,
    output logic [7:0]  VGA_G,
    output logic [7:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,
    output logic        VGA_BLANK_N,
    output logic        VGA_SYNC_N,
    output logic        VGA_CLK,

    output logic [8:0]  LEDG,
    output logic [17:0] LEDR
);
    // ---- reset: automatic power-on pulse OR the KEY[3] button ---------------
    // On the board there is no reset unless you press KEY3, so the CPU would run
    // from its power-on register state. Hold reset for ~2^20 clocks after config
    // so every register (velocities, positions) starts cleanly at zero.
    logic [19:0] por_cnt = 20'h00000;
    logic        por     = 1'b1;
    always_ff @(posedge CLOCK_50) begin
        if (por_cnt != 20'hFFFFF) por_cnt <= por_cnt + 20'h00001;
        else                      por     <= 1'b0;
    end
    logic rst;
    assign rst = por | ~KEY[3];

    // ---- 25 MHz pixel strobe + VGA pixel clock (50 MHz / 2) ----------------
    logic clkdiv = 1'b0;
    always_ff @(posedge CLOCK_50) clkdiv <= ~clkdiv;
    logic pix_en;
    assign pix_en  = clkdiv;
    assign VGA_CLK = clkdiv;

    // ---- CPU clock: fast enough for SMOOTH motion --------------------------
    // The physics advances one step per loop (~32 instr x 5 phases ~= 160 CPU
    // clocks). At 50 MHz/2^13 ~= 6.1 kHz that is ~38 position updates/second --
    // fast enough to look continuous instead of teleporting. (The old 2^15 clock
    // gave only ~9 updates/s, which is what made the ball appear to jump.)
    logic [23:0] slowcnt = 24'h000000;
    always_ff @(posedge CLOCK_50)
        if (!SW[17]) slowcnt <= slowcnt + 24'h000001;   // SW17 high = freeze
    logic cpu_clk;
    assign cpu_clk = slowcnt[12];   // 50 MHz / 2^13 ~= 6.1 kHz (~38 fps of physics)

    // ---- the CPU, running the 3-ball gravity program -----------------------
    logic [7:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;
    cpu #(.PROGRAM("grav1"), .PCW(8), .DMEM_AW(11)) u_cpu (
        .clk(cpu_clk), .rst(rst),
        .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    // ---- the tile GPU: the CPU's stores drive the framebuffer write port ----
    // The framebuffer is written on CLOCK_50 (a real global clock), NOT on the
    // derived cpu_clk -- a counter-bit clock does not drive a block-RAM write
    // port reliably. st_we/st_addr/st_data hold steady for a whole P4 phase
    // (thousands of CLOCK_50 cycles), so sampling them on CLOCK_50 is safe.
    logic hsync, vsync, disp;
    vga_gpu u_gpu (
        .clk(CLOCK_50), .rst(rst), .pix_en(pix_en),
        .wclk(CLOCK_50), .we(st_we), .waddr(st_addr), .wdata(st_data[7:0]),
        .hsync(hsync), .vsync(vsync), .display_on(disp),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
    );
    assign VGA_HS      = hsync;
    assign VGA_VS      = vsync;
    assign VGA_BLANK_N = disp;      // active-low blank: high during visible video
    assign VGA_SYNC_N  = 1'b0;      // sync-on-green not used on the ADV7123

    // ---- status LEDs -------------------------------------------------------
    assign LEDR = {2'b00, st_addr};             // last cell address written
    assign LEDG = {cpu_clk, 3'b000, phase};     // [8]=CPU heartbeat, [4:0]=phase
endmodule
