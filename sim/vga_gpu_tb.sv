// =============================================================================
//  vga_gpu_tb.sv  --  render one frame of the tile GPU to a PPM image
// -----------------------------------------------------------------------------
//  Writes three coloured cells into the tile framebuffer through the GPU's write
//  port, then captures one full visible frame (640x480) as a PPM, so we can see
//  the grid render. Cells (col,row): (5,3)=red, (10,7)=green, (15,11)=blue.
//  Cell address = row*20 + col.  Cell (5,3) covers pixels x=160..191, y=96..127.
//
//  Run:  vlog -sv rtl/vga_sync.sv rtl/tileram.sv rtl/vga_gpu.sv sim/vga_gpu_tb.sv
//        vsim -c -do "run -all; quit -f" work.vga_gpu_tb
//  Output: vga_gpu.ppm (P3) in the current directory.
// =============================================================================
`timescale 1ns/1ps
module vga_gpu_tb;
    logic        clk = 1'b0, rst = 1'b1, pix_en = 1'b0;
    logic        we = 1'b0;
    logic [15:0] waddr = 16'h0000;
    logic [7:0]  wdata = 8'h00;
    logic        hsync, vsync, display_on;
    logic [7:0]  r, g, b;

    vga_gpu dut (
        .clk(clk), .rst(rst), .pix_en(pix_en),
        .wclk(clk), .we(we), .waddr(waddr), .wdata(wdata),
        .hsync(hsync), .vsync(vsync), .display_on(display_on),
        .vga_r(r), .vga_g(g), .vga_b(b)
    );

    always #5 clk = ~clk;                         // 100 MHz
    always_ff @(posedge clk) pix_en <= ~pix_en;   // 25 MHz pixel strobe

    integer fd, visible = 0;

    initial begin
        fd = $fopen("vga_gpu.ppm", "w");
        $fwrite(fd, "P3\n640 480\n255\n");

        // ---- draw three cells while held in reset -------------------------
        @(negedge clk);
        we = 1'b1;
        waddr = 16'd65;  wdata = 8'd1; @(posedge clk); // (col5,row3)=red   3*20+5
        waddr = 16'd150; wdata = 8'd2; @(posedge clk); // (col10,row7)=green 7*20+10
        waddr = 16'd235; wdata = 8'd3; @(posedge clk); // (col15,row11)=blue 11*20+15
        we = 1'b0;
        repeat (6) @(posedge clk);
        rst = 1'b0;
    end

    // After reset the raster scans row-major; capture the first 640x480 visible px.
    always_ff @(posedge clk) if (!rst && pix_en && display_on && visible < 640*480) begin
        $fwrite(fd, "%0d %0d %0d\n", r, g, b);
        visible = visible + 1;
        if (visible == 640*480) begin
            $fclose(fd);
            $display("----------------------------------------------------------");
            $display("VGA-GPU TB PASS: rendered a 640x480 frame (%0d px) to vga_gpu.ppm", visible);
            $display("----------------------------------------------------------");
            $finish;
        end
    end
endmodule
