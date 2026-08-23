// =============================================================================
//  vga_sync.sv  --  640x480 @ 60 Hz VGA timing generator
// -----------------------------------------------------------------------------
//  The video-output stage's heartbeat: it walks a pixel across the screen, left
//  to right and top to bottom, and raises the two sync pulses a monitor needs to
//  lock onto the picture. Everything that draws (the moving square) just asks
//  this module "which pixel am I on, and is it on the visible screen?".
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: a VGA frame is mostly counting.
//
//   * A 640x480 picture is not 640x480 clocks -- around every visible line and
//     frame sits a BLANKING border (front porch, sync pulse, back porch) that
//     dates back to CRT monitors needing time to fly the beam back. So the real
//     grid is 800 x 525 "pixel slots", of which 640 x 480 are visible.
//
//   * Two COUNTERS do all the work: hcount 0..799 steps every pixel; when it
//     wraps, vcount 0..524 steps one line. That is the whole raster scan.
//
//   * The SYNC pulses are just windows on those counters: HSYNC goes low while
//     hcount is inside the horizontal sync window, VSYNC low while vcount is in
//     the vertical one. (This 640x480@60 mode uses NEGATIVE sync polarity.)
//
//   * PIXEL CLOCK. 640x480@60 wants ~25 MHz. Rather than make a second clock,
//     this module runs on the board's fast clock and only advances when the
//     input strobe `pix_en` is high -- pulse it every other 50 MHz edge and the
//     raster runs at 25 MHz, all in one clock domain (simpler, safer timing).
//
//  Compatibility: sized literals only -> compiles on ModelSim ASE 10.1d.
// =============================================================================

module vga_sync #(
    // 640x480 @ 60 Hz, 25 MHz pixel rate (VESA / industry-standard numbers).
    parameter int H_DISPLAY = 640,
    parameter int H_FRONT   = 16,
    parameter int H_SYNC    = 96,
    parameter int H_BACK    = 48,
    parameter int V_DISPLAY = 480,
    parameter int V_FRONT   = 10,
    parameter int V_SYNC    = 2,
    parameter int V_BACK    = 33
) (
    input  logic       clk,        // fast board clock (e.g. 50 MHz)
    input  logic       rst,        // synchronous reset -> top-left of the frame
    input  logic       pix_en,     // pixel strobe: pulse at the 25 MHz pixel rate

    output logic [9:0] hcount,     // 0 .. H_TOTAL-1  (column, incl. blanking)
    output logic [9:0] vcount,     // 0 .. V_TOTAL-1  (row, incl. blanking)
    output logic       hsync,      // horizontal sync (active LOW)
    output logic       vsync,      // vertical sync (active LOW)
    output logic       display_on  // high only inside the visible 640x480 area
);
    // ---- derived boundaries (all constant at elaboration) ------------------
    localparam int H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;  // 800
    localparam int V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;  // 525
    localparam int H_SYNC_LO = H_DISPLAY + H_FRONT;                    // 656
    localparam int H_SYNC_HI = H_DISPLAY + H_FRONT + H_SYNC - 1;       // 751
    localparam int V_SYNC_LO = V_DISPLAY + V_FRONT;                    // 490
    localparam int V_SYNC_HI = V_DISPLAY + V_FRONT + V_SYNC - 1;       // 491

    // ---- the two raster counters -------------------------------------------
    // hcount steps every pixel slot; at the end of a line it wraps and steps
    // vcount; at the end of the last line vcount wraps -> a new frame.
    always_ff @(posedge clk) begin
        if (rst) begin
            hcount <= 10'd0;
            vcount <= 10'd0;
        end else if (pix_en) begin
            if (hcount == H_TOTAL[9:0] - 10'd1) begin
                hcount <= 10'd0;
                if (vcount == V_TOTAL[9:0] - 10'd1)
                    vcount <= 10'd0;
                else
                    vcount <= vcount + 10'd1;
            end else begin
                hcount <= hcount + 10'd1;
            end
        end
    end

    // ---- sync pulses + visible-area flag (pure functions of the counters) ---
    assign hsync = ~((hcount >= H_SYNC_LO[9:0]) && (hcount <= H_SYNC_HI[9:0]));
    assign vsync = ~((vcount >= V_SYNC_LO[9:0]) && (vcount <= V_SYNC_HI[9:0]));
    assign display_on = (hcount < H_DISPLAY[9:0]) && (vcount < V_DISPLAY[9:0]);
endmodule
