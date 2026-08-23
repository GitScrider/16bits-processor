// =============================================================================
//  vga_cpu_tb.sv  --  self-checking test of the CPU running the VGA program
// -----------------------------------------------------------------------------
//  Runs cpu.sv with the VGA moving-square program (logisim/programs/vga_square.mem)
//  and checks the memory-mapped store taps: every store must target the video
//  address (1) and carry the counter, which increments by 1 each loop pass
//  (1, 2, 3, ...). This proves the program + MMIO plumbing that feeds vid_val.
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
    logic [15:0] expected = 16'h0001;   // first stored counter value is 1

    // watch the store taps (a store commits in P4 -> st_we pulses)
    always_ff @(posedge clk) begin
        if (!rst && st_we) begin
            stores = stores + 1;
            if (st_addr !== 16'h0001) begin
                $display("  ERROR store #%0d: addr=%h expected 0001", stores, st_addr);
                errors = errors + 1;
            end
            if (st_data !== expected) begin
                $display("  ERROR store #%0d: data=%h expected %h", stores, st_data, expected);
                errors = errors + 1;
            end
            expected = expected + 16'h0001;
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        // run long enough for several loop passes (each pass = 3 instr x 5 phases)
        repeat (400) @(posedge clk);

        if (stores < 5) begin
            $display("  ERROR: only %0d stores seen (expected several)", stores);
            errors = errors + 1;
        end
        $display("----------------------------------------------------------");
        if (errors == 0)
            $display("VGA-CPU TB PASS: %0d stores, counter incremented 1,2,3,... to addr 1", stores);
        else
            $display("VGA-CPU TB FAIL: %0d error(s) over %0d stores", errors, stores);
        $display("----------------------------------------------------------");
        $finish;
    end
endmodule
