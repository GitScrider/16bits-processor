// =============================================================================
//  vga_gpu.sv  --  the "GPU": render a tile framebuffer to VGA
// -----------------------------------------------------------------------------
//  A tiny tile-based video generator. The screen is divided into a grid of
//  COLS x ROWS cells (CELLW x CELLH pixels each). A cell's value is a colour
//  index stored in the tile framebuffer (tileram). For every pixel the raster
//  scans, this module works out which cell the pixel is in, reads that cell's
//  colour, and paints it. So the CPU "draws" simply by writing colour indices
//  into memory cells -- exactly the framebuffer model of a real display adapter,
//  at coarse resolution.
//
//    cell column = x / CELLW      cell row = y / CELLH
//    cell address = row * COLS + column
//
//  With 16-pixel cells the divisions are just bit slices (x>>4, y>>4); the
//  row*COLS is a small constant multiply. The read is registered, so the
//  colour lines up with the pixel being drawn one clock later (invisible).
//
//  FINE grid: 40 x 30 cells of 16x16 px over 640x480 (exactly fills the screen).
//  Fine cells give SMOOTH motion -- a small object steps 16 px at a time instead
//  of teleporting a whole coarse tile, and its apex is a thin band, not a fat one.
//
//  The CPU reaches the framebuffer through the exposed write port (wclk/we/
//  waddr/wdata), which the board top drives from a memory-mapped store.
//
//  NOTE: `cell` is a reserved word in Verilog, so the cell value is `cell_val`.
//  Compatibility: sized literals only -> compiles on ModelSim ASE 10.1d.
// =============================================================================

module vga_gpu #(
    parameter int COLS  = 40,   // grid is COLS x ROWS cells (FINE: smooth motion)
    parameter int ROWS  = 30,
    parameter int CELLW = 16,   // cell size in pixels (power of 2 -> shift)
    parameter int CELLH = 16
) (
    input  logic        clk,        // fast board clock (50 MHz)
    input  logic        rst,
    input  logic        pix_en,     // 25 MHz pixel strobe

    // framebuffer write port (CPU clock domain)
    input  logic        wclk,
    input  logic        we,
    input  logic [15:0] waddr,      // cell index the CPU is writing
    input  logic [7:0]  wdata,      // colour index

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

    // ---- which cell is this pixel in? --------------------------------------
    // CELLW = CELLH = 16 -> divide by 16 is a 4-bit right shift (a bit slice).
    logic [5:0] col, row;
    assign col = x[9:4];    // x / 16  -> 0..39 in the visible area
    assign row = y[9:4];    // y / 16  -> 0..29

    logic [10:0] raddr;
    assign raddr = row * COLS[5:0] + {5'b0, col};   // row*COLS + col (0..1199)

    // ---- the tile framebuffer ----------------------------------------------
    // AW=11 -> 2048 cells covers the 40x30=1200 grid, with room above 1199 for an
    // off-screen "scratch" cell the CPU can erase into harmlessly.
    logic [7:0] cell_val;
    tileram #(.AW(11), .DW(8)) u_fb (
        .clk_w(wclk), .we(we), .addr_w(waddr[10:0]), .data_w(wdata),
        .clk_r(clk), .addr_r(raddr), .data_r(cell_val)
    );

    // ---- colour map: cell value -> RGB -------------------------------------
    // 0 = white background; 1/2/3 = the three ball colours; else grey.
    always_comb begin
        if (!display_on) begin
            vga_r = 8'h00; vga_g = 8'h00; vga_b = 8'h00;   // black off-screen
        end else begin
            case (cell_val)
                8'd1:    begin vga_r = 8'h00; vga_g = 8'h00; vga_b = 8'h00; end // black
                8'd2:    begin vga_r = 8'h30; vga_g = 8'hC0; vga_b = 8'h40; end // green
                8'd3:    begin vga_r = 8'h40; vga_g = 8'h70; vga_b = 8'hF0; end // blue
                8'd0:    begin vga_r = 8'hFF; vga_g = 8'hFF; vga_b = 8'hFF; end // white bg
                default: begin vga_r = 8'h80; vga_g = 8'h80; vga_b = 8'h80; end // grey
            endcase
        end
    end
endmodule
