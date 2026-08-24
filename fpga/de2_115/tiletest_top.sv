// =============================================================================
//  tiletest_top.sv  --  isolation test: a STATIC tile pattern (no CPU)
// -----------------------------------------------------------------------------
//  Debug aid. Loads a fixed red/green checkerboard into the tile framebuffer
//  once at power-on (a tiny address counter), then just displays it through the
//  real vga_gpu. No CPU, no dynamic writes. If this pattern is rock-steady on the
//  monitor, the tileram + vga_gpu render path is fine and the trouble is in the
//  CPU / clock-crossing write path. If it jitters, the render path itself is the
//  culprit.
// =============================================================================

module tiletest_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    output logic [7:0]  VGA_R, VGA_G, VGA_B,
    output logic        VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK,
    output logic [8:0]  LEDG,
    output logic [17:0] LEDR
);
    logic rst;
    assign rst = ~KEY[3];

    // 25 MHz pixel strobe + VGA clock
    logic clkdiv = 1'b0;
    always_ff @(posedge CLOCK_50) clkdiv <= ~clkdiv;
    logic pix_en;
    assign pix_en  = clkdiv;
    assign VGA_CLK = clkdiv;

    // ---- one-shot pattern loader: fill cells 0..299 with a checkerboard ------
    logic [9:0] initaddr = 10'h000;
    logic       initing  = 1'b1;
    always_ff @(posedge CLOCK_50) if (initing) begin
        if (initaddr == 10'd511) initing <= 1'b0;
        else                     initaddr <= initaddr + 10'd1;
    end
    // checkerboard from the cell index bits -> alternating red(1)/green(2)
    logic [7:0] initdata;
    assign initdata = (initaddr[0] ^ initaddr[4]) ? 8'd1 : 8'd2;

    // ---- the real GPU, fed by the loader instead of a CPU -------------------
    logic hsync, vsync, disp;
    vga_gpu u_gpu (
        .clk(CLOCK_50), .rst(rst), .pix_en(pix_en),
        .wclk(CLOCK_50), .we(initing), .waddr({6'b0, initaddr}), .wdata(initdata),
        .hsync(hsync), .vsync(vsync), .display_on(disp),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
    );
    assign VGA_HS      = hsync;
    assign VGA_VS      = vsync;
    assign VGA_BLANK_N = disp;
    assign VGA_SYNC_N  = 1'b0;

    assign LEDG = {8'b0, initing};   // LEDG0 on while loading (should go off fast)
    assign LEDR = 18'h00000;
endmodule
