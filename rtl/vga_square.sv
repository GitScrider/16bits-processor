// =============================================================================
//  vga_square.sv  --  draw a square at the position the CPU computed
// -----------------------------------------------------------------------------
//  This is the memory-mapped video output. The CPU now does the interesting part
//  itself: it runs a program that computes a BOUNCING X coordinate (add the step,
//  detect the walls, flip the direction) and stores that coordinate to a
//  memory-mapped video register. That coordinate arrives here as `pos_x`, and all
//  this module does is paint a coloured square there. The CPU decides *where*;
//  the hardware only decides *how to light it up*.
//
//   * Horizontal position comes straight from the CPU (pos_x). The vertical
//     position is fixed (BOX_Y) -- the CPU's tiny 16-word program bounces one
//     axis, so the square slides left/right across the middle of the screen.
//
//   * CLOCK CROSSING. pos_x is written in the CPU's (slow) clock domain and read
//     here in the pixel domain, so it goes through a two-flop synchroniser and is
//     sampled ONCE PER FRAME (at the top-left pixel) so the square never tears.
//
//  Compatibility: sized literals only -> compiles on ModelSim ASE 10.1d.
// =============================================================================

module vga_square #(
    parameter int SIZE  = 64,       // square is SIZE x SIZE pixels
    parameter int BOX_Y = 208       // fixed vertical position ((480-64)/2 = centre)
) (
    input  logic        clk,        // fast board clock (50 MHz)
    input  logic        rst,
    input  logic        pix_en,     // 25 MHz pixel strobe
    input  logic [15:0] pos_x,      // X position the CPU computed (0 .. 640-SIZE)

    output logic        hsync,
    output logic        vsync,
    output logic        display_on,
    output logic [7:0]  vga_r,
    output logic [7:0]  vga_g,
    output logic [7:0]  vga_b
);
    // ---- raster timing ------------------------------------------------------
    logic [9:0] x, y;
    vga_sync u_sync (
        .clk(clk), .rst(rst), .pix_en(pix_en),
        .hcount(x), .vcount(y),
        .hsync(hsync), .vsync(vsync), .display_on(display_on)
    );

    // ---- bring pos_x safely into the pixel domain (two-flop synchroniser) ----
    logic [15:0] xs1, xs2;
    always_ff @(posedge clk) begin
        xs1 <= pos_x;
        xs2 <= xs1;
    end

    // ---- latch the square's position once per frame (at the top-left pixel) --
    logic [9:0] box_x;
    logic       frame_start;
    assign frame_start = (x == 10'd0) && (y == 10'd0);

    always_ff @(posedge clk) begin
        if (rst)
            box_x <= 10'd0;
        else if (pix_en && frame_start)
            box_x <= xs2[9:0];      // whatever X the CPU last stored
    end

    // ---- is the current pixel inside the square? ---------------------------
    logic in_box;
    assign in_box = (x >= box_x) && (x < box_x + SIZE[9:0]) &&
                    (y >= BOX_Y[9:0]) && (y < BOX_Y[9:0] + SIZE[9:0]);

    // ---- colour: black square on a white field; black in blanking ----------
    always_comb begin
        if (!display_on) begin
            vga_r = 8'h00; vga_g = 8'h00; vga_b = 8'h00;   // must be black off-screen
        end else if (in_box) begin
            vga_r = 8'h00; vga_g = 8'h00; vga_b = 8'h00;   // black square
        end else begin
            vga_r = 8'hFF; vga_g = 8'hFF; vga_b = 8'hFF;   // white background
        end
    end
endmodule
