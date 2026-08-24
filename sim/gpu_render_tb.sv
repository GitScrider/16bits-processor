// =============================================================================
//  gpu_render_tb.sv  --  full pipeline render: CPU physics -> tile GPU -> frame
// -----------------------------------------------------------------------------
//  Wires the CPU (running the gravity ball program) to the tile GPU: the CPU's
//  memory-mapped stores drive the framebuffer write port, and the GPU renders the
//  grid. We let the CPU run until it has drawn the ball a few rows down, freeze
//  the framebuffer, and capture one 640x480 frame to a PPM so we can see it.
//
//  (In the sim both run off one clock, so the CPU "draws" far faster than the
//  raster scans; freezing after a draw captures the ball at that position.)
//
//  Run:  vlog -sv rtl/sequencer.sv rtl/pc.sv rtl/imem.sv rtl/control.sv \
//               rtl/regfile.sv rtl/alu.sv rtl/dmem.sv rtl/cpu.sv \
//               rtl/vga_sync.sv rtl/tileram.sv rtl/vga_gpu.sv sim/gpu_render_tb.sv
//        vsim -c -do "run -all; quit -f" work.gpu_render_tb
// =============================================================================
`timescale 1ns/1ps
module gpu_render_tb;
    logic        clk = 1'b0, rst = 1'b1, pix_en = 1'b0;

    // CPU
    logic [7:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;

    cpu #(.PROGRAM("grav1"), .PCW(8)) u_cpu (
        .clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    // freeze the framebuffer after the ball has fallen a few rows
    integer draws = 0;
    logic   frozen = 1'b0;
    always_ff @(posedge clk) if (!rst && st_we && st_data == 16'd1) begin
        draws = draws + 1;
        if (draws == 8) frozen <= 1'b1;
    end
    wire gwe = st_we & ~frozen;

    // GPU
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
    logic   capturing = 1'b0;
    logic   was_top = 1'b0;
    wire    at_top = (u_gpu.x == 10'd0) && (u_gpu.y == 10'd0);

    initial begin
        fd = $fopen("gpu_frame.ppm", "w");
        $fwrite(fd, "P3\n640 480\n255\n");
        repeat (4) @(posedge clk);
        rst = 1'b0;
    end

    always_ff @(posedge clk) if (!rst && pix_en) begin
        // once frozen, start capturing at the next top-left corner
        if (frozen && at_top && !was_top && !capturing && visible == 0)
            capturing <= 1'b1;
        was_top <= at_top;

        if (capturing && disp && visible < 640*480) begin
            $fwrite(fd, "%0d %0d %0d\n", r, g, b);
            visible = visible + 1;
            if (visible == 640*480) begin
                $fclose(fd);
                $display("----------------------------------------------------------");
                $display("GPU-RENDER TB PASS: captured a frame (%0d px) after %0d draws", visible, draws);
                $display("----------------------------------------------------------");
                $finish;
            end
        end
    end
endmodule
