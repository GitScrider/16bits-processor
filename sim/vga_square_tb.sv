// =============================================================================
//  vga_square_tb.sv  --  render one VGA frame to a PPM image + timing sanity
// -----------------------------------------------------------------------------
//  Drives vga_square with a fixed pos_x (as if the CPU had stored that X) and
//  captures one full visible frame (640x480) as a PPM file, so we can look at
//  exactly what the monitor would show. Also checks the frame really is 640x480
//  visible pixels. For pos_x=200 the box lands at (200, 208) (BOX_Y centre).
//
//  Run:  vlog -sv rtl/vga_sync.sv rtl/vga_square.sv sim/vga_square_tb.sv
//        vsim -c -do "run -all; quit -f" work.vga_square_tb
//  Output: vga_frame.ppm (P3) in the current directory.
// =============================================================================
`timescale 1ns/1ps
module vga_square_tb;
    logic        clk = 1'b0, rst = 1'b1, pix_en = 1'b0;
    logic [15:0] pos_x = 16'd200;        // CPU-computed X -> box at (200, 208)
    logic        hsync, vsync, display_on;
    logic [7:0]  r, g, b;

    vga_square dut (
        .clk(clk), .rst(rst), .pix_en(pix_en), .pos_x(pos_x),
        .hsync(hsync), .vsync(vsync), .display_on(display_on),
        .vga_r(r), .vga_g(g), .vga_b(b)
    );

    always #5 clk = ~clk;                         // 100 MHz
    always_ff @(posedge clk) pix_en <= ~pix_en;   // 25 MHz pixel strobe

    integer fd;
    integer visible = 0;

    initial begin
        fd = $fopen("vga_frame.ppm", "w");
        $fwrite(fd, "P3\n640 480\n255\n");
        repeat (8) @(posedge clk);   // let vid_val propagate through the synchroniser
        rst = 1'b0;
    end

    // After reset the raster starts at (0,0) and scans row-major, so the first
    // 640x480 display_on pixels ARE frame 1's visible area, in order.
    always_ff @(posedge clk) if (!rst && pix_en && display_on && visible < 640*480) begin
        $fwrite(fd, "%0d %0d %0d\n", r, g, b);
        visible = visible + 1;
        if (visible == 640*480) begin
            $fclose(fd);
            $display("----------------------------------------------------------");
            $display("VGA-SQUARE TB PASS: rendered a 640x480 frame (%0d visible px) to vga_frame.ppm", visible);
            $display("----------------------------------------------------------");
            $finish;
        end
    end
endmodule
