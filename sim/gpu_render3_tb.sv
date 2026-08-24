// =============================================================================
//  gpu_render3_tb.sv  --  render the 3-ball scene: CPU -> tile GPU -> frame
// -----------------------------------------------------------------------------
//  Same idea as gpu_render_tb but with PROGRAM="grav3". We freeze the framebuffer
//  at the end of a frame (right after ball C is drawn, so all three balls are in
//  place) and capture one 640x480 frame to a PPM.
// =============================================================================
`timescale 1ns/1ps
module gpu_render3_tb;
    logic        clk = 1'b0, rst = 1'b1, pix_en = 1'b0;
    logic [7:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;

    cpu #(.PROGRAM("grav3"), .PCW(8)) u_cpu (
        .clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    // freeze at the end of the 6th frame (after ball C, colour 3, is drawn)
    integer framedraws = 0;
    logic   frozen = 1'b0;
    always_ff @(posedge clk) if (!rst && st_we && st_data == 16'd3) begin
        framedraws = framedraws + 1;
        if (framedraws == 6) frozen <= 1'b1;
    end
    wire gwe = st_we & ~frozen;

    logic hsync, vsync, disp;
    logic [7:0] r, g, b;
    vga_gpu u_gpu (
        .clk(clk), .rst(rst), .pix_en(pix_en),
        .wclk(clk), .we(gwe), .waddr(st_addr), .wdata(st_data[7:0]),
        .hsync(hsync), .vsync(vsync), .display_on(disp),
        .vga_r(r), .vga_g(g), .vga_b(b)
    );

    always #5 clk = ~clk;
    always_ff @(posedge clk) pix_en <= ~pix_en;

    integer fd, visible = 0;
    logic   capturing = 1'b0, was_top = 1'b0;
    wire    at_top = (u_gpu.x == 10'd0) && (u_gpu.y == 10'd0);

    initial begin
        fd = $fopen("gpu3.ppm", "w");
        $fwrite(fd, "P3\n640 480\n255\n");
        repeat (4) @(posedge clk);
        rst = 1'b0;
    end

    always_ff @(posedge clk) if (!rst && pix_en) begin
        if (frozen && at_top && !was_top && !capturing && visible == 0)
            capturing <= 1'b1;
        was_top <= at_top;
        if (capturing && disp && visible < 640*480) begin
            $fwrite(fd, "%0d %0d %0d\n", r, g, b);
            visible = visible + 1;
            if (visible == 640*480) begin
                $fclose(fd);
                $display("GPU-RENDER3 TB PASS: captured 3-ball frame (%0d px)", visible);
                $finish;
            end
        end
    end
endmodule
