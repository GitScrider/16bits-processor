// =============================================================================
//  vga_square.sv  --  draw a moving square whose position comes from the CPU
// -----------------------------------------------------------------------------
//  This is the memory-mapped video output: the processor writes an ever-changing
//  number to a memory-mapped register, that number arrives here as `vid_val`, and
//  this module turns it into the on-screen position of a coloured square. The CPU
//  supplies the *value*; the hardware turns the value into *pixels* -- which is
//  exactly what a framebuffer / video peripheral does.
//
//  ---------------------------------------------------------------------------
//  HOW A NUMBER BECOMES A BOUNCE.
//
//   * The CPU program just counts up: vid_val = 0,1,2,3,... forever. A counter
//     alone would slide the square off the edge, so the position is a TRIANGLE
//     WAVE of the counter -- it rises, then falls, then rises, so the square
//     bounces between the walls instead of wrapping.
//
//   * A triangle wave is cheap in hardware: take N bits of the counter; while the
//     top bit is 0 the lower bits count UP, and while it is 1 use their bitwise
//     complement so they count DOWN. No multiply, no divide.
//       - X uses 10 bits (period 1024) -> sweeps 0..511 and back.
//       - Y uses  9 bits (period  512) -> sweeps 0..255 and back, twice as fast,
//         so the square traces a bouncing, non-diagonal path.
//
//   * CLOCK CROSSING. vid_val is written in the CPU's (slow) clock domain and
//     read here in the pixel domain, so it is passed through a two-flop
//     synchroniser and only sampled ONCE PER FRAME (at vsync) -- so the square
//     never tears or twitches mid-picture.
//
//  Compatibility: sized literals only -> compiles on ModelSim ASE 10.1d.
// =============================================================================

module vga_square #(
    parameter int SIZE = 64                 // square is SIZE x SIZE pixels
) (
    input  logic        clk,        // fast board clock (50 MHz)
    input  logic        rst,
    input  logic        pix_en,     // 25 MHz pixel strobe
    input  logic [15:0] vid_val,    // the CPU's memory-mapped counter

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

    // ---- bring vid_val safely into the pixel domain (two-flop synchroniser) --
    logic [15:0] val_s1, val_s2;
    always_ff @(posedge clk) begin
        val_s1 <= vid_val;
        val_s2 <= val_s1;
    end

    // ---- latch the square's position once per frame (at the top-left corner) --
    // Triangle waves from the synchronised counter (see header): pure bit tricks.
    logic [9:0] box_x;              // 0..511
    logic [9:0] box_y;              // 0..255
    logic       frame_start;
    assign frame_start = (x == 10'd0) && (y == 10'd0);

    always_ff @(posedge clk) begin
        if (rst) begin
            box_x <= 10'd0;
            box_y <= 10'd0;
        end else if (pix_en && frame_start) begin
            // X: 10-bit triangle, range 0..511  (val_s2[9]=0 -> up, =1 -> down)
            box_x <= val_s2[9] ? {1'b0, ~val_s2[8:0]} : {1'b0, val_s2[8:0]};
            // Y: 9-bit triangle, range 0..255
            box_y <= val_s2[8] ? {2'b0, ~val_s2[7:0]} : {2'b0, val_s2[7:0]};
        end
    end

    // ---- is the current pixel inside the square? ---------------------------
    logic in_box;
    assign in_box = (x >= box_x) && (x < box_x + SIZE[9:0]) &&
                    (y >= box_y) && (y < box_y + SIZE[9:0]);

    // ---- colour: bright cyan square on a dark-blue field; black in blanking --
    always_comb begin
        if (!display_on) begin
            vga_r = 8'h00; vga_g = 8'h00; vga_b = 8'h00;   // must be black off-screen
        end else if (in_box) begin
            vga_r = 8'h00; vga_g = 8'hFF; vga_b = 8'hFF;   // cyan square
        end else begin
            vga_r = 8'h10; vga_g = 8'h12; vga_b = 8'h3A;   // dark-blue background
        end
    end
endmodule
