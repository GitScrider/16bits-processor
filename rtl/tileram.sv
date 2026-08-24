// =============================================================================
//  tileram.sv  --  the tile framebuffer: a small dual-port RAM the "GPU" reads
// -----------------------------------------------------------------------------
//  This is the memory the CPU draws into and the video stage reads out -- a
//  genuine framebuffer, just at coarse (tile) resolution. It has TWO ports:
//
//    * WRITE port (CPU side): clocked. When `we` is high, cell `addr_w` takes the
//      new value `data_w` on the rising edge of `clk_w`. The CPU reaches this
//      through a memory-mapped `sw` (see the board top).
//
//    * READ port (video side): combinational. The video stage presents a cell
//      address `addr_r` derived from the pixel being drawn and gets that cell's
//      value back on `data_r` immediately -- no latency to align to the raster.
//
//  One clocked write port + one asynchronous read port is the "simple dual-port"
//  pattern; for a grid this small it maps to logic / MLAB, so the two sides can
//  run in different clock domains (slow CPU write, fast pixel read). A write and
//  a read hitting the same cell in the same instant can glitch that one cell for
//  one pixel -- cosmetically invisible here.
//
//  Compatibility: sized literals only -> compiles on ModelSim ASE 10.1d.
// =============================================================================

module tileram #(
    parameter int AW = 9,    // address width -> 2**AW cells (512 covers a 20x15=300 grid)
    parameter int DW = 8     // bits per cell (a colour index)
) (
    // write port (CPU clock domain)
    input  logic          clk_w,
    input  logic          we,
    input  logic [AW-1:0] addr_w,
    input  logic [DW-1:0] data_w,
    // read port (pixel clock domain), REGISTERED
    input  logic          clk_r,
    input  logic [AW-1:0] addr_r,
    output logic [DW-1:0] data_r
);
    logic [DW-1:0] mem [0:(1<<AW)-1];

    // clear to background (0) so an un-drawn grid starts blank
    integer i;
    initial for (i = 0; i < (1<<AW); i = i + 1) mem[i] = {DW{1'b0}};

    // clocked write (CPU). The read is REGISTERED on the pixel clock: this is what
    // lets synthesis map the array onto a fast dedicated block RAM instead of a
    // huge combinational mux. A combinational read of a 512-cell array cannot
    // settle within a pixel at 25 MHz, so the DAC would latch garbage -- exactly
    // the on-screen jitter that a zero-delay simulation never shows. The one-cycle
    // read latency only shifts the picture by a single (invisible) pixel.
    always_ff @(posedge clk_w)
        if (we) mem[addr_w] <= data_w;

    always_ff @(posedge clk_r)
        data_r <= mem[addr_r];
endmodule
