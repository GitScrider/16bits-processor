// =============================================================================
//  vga_cpu_tb.sv  --  self-checking test of the CPU computing the bounce
// -----------------------------------------------------------------------------
//  Runs cpu.sv with the VGA moving-square program (PROGRAM="vga") and checks the
//  memory-mapped store taps: every store targets the video address (1) and the
//  stored X stays inside the screen (0 .. 576), AND the value actually BOUNCES --
//  it climbs to the right wall, then comes back down, then climbs again. That
//  proves the CPU itself computes the bouncing position (add / sub / beqz), not
//  just a counter.
//
//  Run:  vlog -sv rtl/sequencer.sv rtl/pc.sv rtl/imem.sv rtl/control.sv \
//               rtl/regfile.sv rtl/alu.sv rtl/dmem.sv rtl/cpu.sv sim/vga_cpu_tb.sv
//        vsim -c -do "run -all; quit -f" vga_cpu_tb
// =============================================================================
`timescale 1ns/1ps
module vga_cpu_tb;
    logic        clk = 1'b0, rst = 1'b1;
    logic [3:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;

    cpu #(.PROGRAM("vga")) dut (
        .clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    always #5 clk = ~clk;   // 100 MHz

    integer errors = 0;
    integer stores = 0;
    integer prev_x = -1;
    integer max_x  = 0;
    integer min_after_max = 700;
    logic   saw_up   = 1'b0;   // x increased at some point
    logic   saw_down = 1'b0;   // x decreased at some point (a bounce off the right)
    logic   saw_reup = 1'b0;   // x increased again after decreasing (bounce off the left)

    always_ff @(posedge clk) begin
        if (!rst && st_we) begin
            stores = stores + 1;
            if (st_addr !== 16'h0001) begin
                $display("  ERROR store #%0d: addr=%h expected 0001", stores, st_addr);
                errors = errors + 1;
            end
            if (st_data > 16'd576) begin
                $display("  ERROR store #%0d: x=%0d out of range (>576)", stores, st_data);
                errors = errors + 1;
            end
            if (prev_x >= 0) begin
                if (st_data > prev_x) begin
                    saw_up = 1'b1;
                    if (saw_down) saw_reup = 1'b1;   // went up again after a bounce
                end
                if (st_data < prev_x) saw_down = 1'b1;
            end
            if (st_data > max_x) max_x = st_data;
            prev_x = st_data;
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (20000) @(posedge clk);   // enough for a full up-and-back sweep

        if (stores < 200)                     begin $display("  ERROR: only %0d stores", stores);        errors = errors + 1; end
        if (!(max_x >= 570))                  begin $display("  ERROR: max x only %0d (expected ~576)", max_x); errors = errors + 1; end
        if (!(saw_up && saw_down && saw_reup)) begin $display("  ERROR: did not observe a full bounce (up/down/up)"); errors = errors + 1; end

        $display("----------------------------------------------------------");
        if (errors == 0)
            $display("VGA-CPU TB PASS: %0d stores, x bounced 0..%0d and back (CPU-computed)", stores, max_x);
        else
            $display("VGA-CPU TB FAIL: %0d error(s)", errors);
        $display("----------------------------------------------------------");
        $finish;
    end
endmodule
