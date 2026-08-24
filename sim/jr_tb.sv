// =============================================================================
//  jr_tb.sv  --  self-checking test of the jr (jump-register) instruction
// -----------------------------------------------------------------------------
//  Runs cpu.sv with the "jrtest" program (imem PROGRAM="jrtest"): it loads an
//  address into r5 and does `jr r5`, jumping over two "trap" instructions to a
//  landing pad. If jr works, the traps never run (r1 stays 0) and the landing
//  sets r2 = 7. If jr fell through instead, r1 would be 30. This proves the
//  register-indirect jump end to end in the RTL (matching the Logisim design).
//
//  Run:  vlog -sv rtl/sequencer.sv rtl/pc.sv rtl/imem.sv rtl/control.sv \
//               rtl/regfile.sv rtl/alu.sv rtl/dmem.sv rtl/cpu.sv sim/jr_tb.sv
//        vsim -c -do "run -all; quit -f" jr_tb
// =============================================================================
`timescale 1ns/1ps
module jr_tb;
    logic        clk = 1'b0, rst = 1'b1;
    logic [3:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;

    cpu #(.PROGRAM("jrtest")) dut (
        .clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    always #5 clk = ~clk;

    // Mirror the registers we care about by snooping the write-back taps.
    logic [15:0] r1 = 16'h0000, r2 = 16'h0000, r5 = 16'h0000;
    always_ff @(posedge clk) if (!rst && wb_we) begin
        if (wb_rd == 4'd1) r1 <= wb_val;
        if (wb_rd == 4'd2) r2 <= wb_val;
        if (wb_rd == 4'd5) r5 <= wb_val;
    end

    integer errors = 0;
    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (120) @(posedge clk);   // plenty for the 6-instruction program to settle

        if (r5 !== 16'd4)  begin $display("  ERROR: r5=%0d expected 4",  r5); errors = errors + 1; end
        if (r1 !== 16'd0)  begin $display("  ERROR: r1=%0d expected 0 (traps ran -> jr fell through!)", r1); errors = errors + 1; end
        if (r2 !== 16'd7)  begin $display("  ERROR: r2=%0d expected 7 (landing not reached)", r2); errors = errors + 1; end
        if (pc_out !== 4'd5) begin $display("  ERROR: pc=%0d expected 5 (spin)", pc_out); errors = errors + 1; end

        $display("----------------------------------------------------------");
        if (errors == 0)
            $display("JR TB PASS: jr r5 jumped to 4, skipped the traps (r1=0, r2=7), PC spinning at 5");
        else
            $display("JR TB FAIL: %0d error(s)", errors);
        $display("----------------------------------------------------------");
        $finish;
    end
endmodule
