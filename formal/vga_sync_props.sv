// =============================================================================
//  vga_sync_props.sv  --  formal properties for the VGA timing generator
// -----------------------------------------------------------------------------
//  Proves the raster counters can never run out of bounds and that the visible
//  flag exactly matches the visible rectangle -- for ALL time and ALL inputs, by
//  k-induction with Yosys's built-in SAT engine (no external solver).
//
//    * hcount always stays within one line   (0 .. 799)   -- can't run away
//    * vcount always stays within one frame   (0 .. 524)
//    * display_on is high exactly on the visible 640 x 480 area
//
//  The bound invariants are inductive: from any in-range count, the wrap logic
//  yields another in-range count (and holding when pix_en is low keeps it in
//  range), so induction lifts them to all reachable states.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv -formal rtl/vga_sync.sv formal/vga_sync_props.sv; \
//                     prep -top vga_sync_props -flatten; memory_map; opt -full; async2sync; \
//                     chformal -lower; sat -tempinduct -set-init-zero -prove-asserts -seq 20 -verify"
// =============================================================================

module vga_sync_props (
    input logic clk, rst, pix_en
);
    logic [9:0] hcount, vcount;
    logic       hsync, vsync, display_on;

    vga_sync dut (
        .clk(clk), .rst(rst), .pix_en(pix_en),
        .hcount(hcount), .vcount(vcount),
        .hsync(hsync), .vsync(vsync), .display_on(display_on)
    );

    always_ff @(posedge clk) begin
        // counters stay inside one 800 x 525 raster -- never run away
        assert (hcount < 10'd800);
        assert (vcount < 10'd525);
        // the visible flag is exactly the visible rectangle
        assert (display_on == ((hcount < 10'd640) && (vcount < 10'd480)));
    end
endmodule
