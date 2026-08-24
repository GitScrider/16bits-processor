// =============================================================================
//  vga_top.sv  --  DE2-115 board demo: the CPU drives a moving square on a VGA
//                  monitor (the roadmap's video-output stage, made real).
// -----------------------------------------------------------------------------
//  The processor runs the built-in moving-square program (imem PROGRAM="vga"):
//  it COMPUTES a bouncing X coordinate (add the step, test the walls, flip the
//  direction) and stores that coordinate to a memory-mapped video address every
//  loop -- the same words listed in logisim/programs/vga_square.mem. This wrapper
//  snoops that store into a video register, and the VGA stage draws a square at
//  that X. So a program running on our own CPU literally paints pixels on a
//  monitor, and the CPU -- not the hardware -- decides where the square goes.
//
//  Two clocks from the board's 50 MHz:
//    * pixel clock  = 50 MHz / 2 = 25 MHz  (drives the 640x480@60 VGA timing)
//    * CPU clock    = 50 MHz / 2^14 ~= 3 kHz  (slow, so the square drifts at a
//                     pleasant pace and the machine phases are watchable)
//
//  Controls:  KEY[3] = reset (active-low).  SW[17] = freeze the CPU (pause).
//  Status  :  LEDG[4:0] = machine phase (one-hot),  LEDR[15:0] = video value.
//
//  Compatibility: sized literals only -> ModelSim ASE 10.1d clean.
// =============================================================================

module vga_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,        // KEY[3] = reset (active-low)
    input  logic [17:0] SW,         // SW[17] = freeze CPU

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
    // ---- reset (button is active-low) --------------------------------------
    logic rst;
    assign rst = ~KEY[3];

    // ---- 25 MHz pixel strobe + VGA pixel clock (50 MHz / 2) ----------------
    logic clkdiv = 1'b0;
    always_ff @(posedge CLOCK_50) clkdiv <= ~clkdiv;
    logic pix_en;
    assign pix_en  = clkdiv;
    assign VGA_CLK = clkdiv;

    // ---- slow CPU clock (~3 kHz) so the square moves gently ----------------
    logic [15:0] slowcnt = 16'h0000;
    always_ff @(posedge CLOCK_50)
        if (!SW[17]) slowcnt <= slowcnt + 16'h0001;   // SW17 high = freeze
    logic cpu_clk;
    assign cpu_clk = slowcnt[13];

    // ---- the CPU, running the moving-square program ------------------------
    logic [3:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;
    cpu #(.PROGRAM("vga"), .DMEM_AW(4)) u_cpu (
        .clk(cpu_clk), .rst(rst),
        .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    // ---- memory-mapped video register (video address = 1) ------------------
    // The CPU stores its computed X position here; we snoop it off the store bus.
    logic [15:0] vid_x;
    always_ff @(posedge cpu_clk) begin
        if (rst)
            vid_x <= 16'h0000;
        else if (st_we && (st_addr == 16'h0001))
            vid_x <= st_data;
    end

    // ---- the VGA output stage (draws the square at the CPU's X) -------------
    logic hsync, vsync, disp;
    vga_square u_vga (
        .clk(CLOCK_50), .rst(rst), .pix_en(pix_en), .pos_x(vid_x),
        .hsync(hsync), .vsync(vsync), .display_on(disp),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
    );
    assign VGA_HS      = hsync;
    assign VGA_VS      = vsync;
    assign VGA_BLANK_N = disp;      // active-low blank: high during visible video
    assign VGA_SYNC_N  = 1'b0;      // sync-on-green not used on the ADV7123

    // ---- status LEDs -------------------------------------------------------
    assign LEDR = {2'b00, vid_x};               // CPU's X position on LEDR[15:0]
    assign LEDG = {cpu_clk, 3'b000, phase};     // [8]=CPU heartbeat, [4:0]=phase
endmodule
