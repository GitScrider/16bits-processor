// =============================================================================
//  cpu_tb.sv  --  self-checking testbench for the integrated multicycle CPU
// -----------------------------------------------------------------------------
//  Runs the original Logisim demo program (loop.mem, baked into imem.sv) on the
//  integrated cpu.sv and checks the nested-loop behaviour:
//
//     0: addi r0,r0,0   (no-op)
//     1: addi r1,r1,2   -> r1 = 2                (loop bound, set once)
//     2: addi r2,r2,1   -> r2 = r2 + 1           (inner counter)   <-- branch target
//     3: slt  r3,r1,r2  -> r3 = (r1 < r2)                          <-- jump target
//     4: beqz r3,2      -> if r3==0 go to 2 (keep counting)
//     5: addi r2,r4,0   -> r2 = 0 (reset the counter)
//     6: j    3         -> restart forever
//
//  Expected steady behaviour: r1 stays 2, r2 walks 1,2,3 then resets to 0 and
//  repeats; r3 is 1 exactly when r2 has passed r1. The branch is taken while
//  r3==0 (pc 4->2) and falls through when r3==1 (pc 4->5); the jump always
//  reboots the loop (pc 6->3).
// =============================================================================

`timescale 1ns/1ps

module cpu_tb;
    logic        clk = 1'b0;
    logic        rst;
    logic [3:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;

    cpu dut (.clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase));

    // 100 MHz clock
    always #5 clk = ~clk;

    // convenient views of the registers under test (hierarchical peek)
    wire [15:0] r0 = dut.u_rf.regs[0];
    wire [15:0] r1 = dut.u_rf.regs[1];
    wire [15:0] r2 = dut.u_rf.regs[2];
    wire [15:0] r3 = dut.u_rf.regs[3];

    integer errors = 0;
    integer icount = 0;      // instructions retired (counted at P1)
    logic   inited = 1'b0;   // set once pc has passed the r1=2 setup

    // decode a hex opcode to a short mnemonic for the trace
    function string mnem(input logic [3:0] op);
        case (op)
            4'h0: mnem = "addi";
            4'h8: mnem = "slt ";
            4'h9: mnem = "beqz";
            4'hE: mnem = "j   ";
            default: mnem = "??? ";
        endcase
    endfunction

    // Sample at P1 (start of each instruction): registers hold every completed
    // write, and pc_out/instr are the instruction about to run.
    always @(negedge clk) begin
        if (!rst && phase == 5'b00001) begin
            icount = icount + 1;
            $display("  [%0t] instr#%0d  pc=%0d  %04h %s   r0=%0d r1=%0d r2=%0d r3=%0d",
                     $time, icount, pc_out, instr, mnem(instr[15:12]), r0, r1, r2, r3);

            // once we've executed the r1=2 setup at address 1, r1 must stay 2
            if (pc_out >= 4'd2) inited = 1'b1;
            if (inited && r1 !== 16'd2) begin
                $display("  ** ERROR: r1 should be 2 after setup, got %0d", r1);
                errors = errors + 1;
            end
            // the inner counter must stay within its loop bound
            if (r2 > 16'd3) begin
                $display("  ** ERROR: r2 out of expected range [0..3], got %0d", r2);
                errors = errors + 1;
            end
            // slt result is boolean
            if (r3 > 16'd1) begin
                $display("  ** ERROR: r3 (slt result) should be 0 or 1, got %0d", r3);
                errors = errors + 1;
            end
            // the program only lives in addresses 0..6
            if (pc_out > 4'd6) begin
                $display("  ** ERROR: pc ran outside the program (0..6), got %0d", pc_out);
                errors = errors + 1;
            end
        end
    end

    // track that the interesting control-flow events actually happen
    logic saw_branch_taken = 1'b0;  // pc 4 -> 2
    logic saw_branch_fall  = 1'b0;  // pc 4 -> 5
    logic saw_jump         = 1'b0;  // pc 6 -> 3
    logic [3:0] prev_pc = 4'hF;
    always @(negedge clk) begin
        if (!rst && phase == 5'b00001) begin
            if (prev_pc == 4'd4 && pc_out == 4'd2) saw_branch_taken = 1'b1;
            if (prev_pc == 4'd4 && pc_out == 4'd5) saw_branch_fall  = 1'b1;
            if (prev_pc == 4'd6 && pc_out == 4'd3) saw_jump         = 1'b1;
            prev_pc = pc_out;
        end
    end

    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
        $display("=== cpu_tb: running loop.mem on the integrated CPU ===");
        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;

        // run ~40 instructions (each is 5 clocks) -> a few full outer loops
        repeat (5*45) @(negedge clk);

        $display("=== control-flow coverage ===");
        $display("  branch taken (4->2): %0d   branch fall-through (4->5): %0d   jump (6->3): %0d",
                 saw_branch_taken, saw_branch_fall, saw_jump);
        if (!saw_branch_taken) begin $display("  ** ERROR: conditional branch never taken"); errors = errors + 1; end
        if (!saw_branch_fall)  begin $display("  ** ERROR: branch never fell through");      errors = errors + 1; end
        if (!saw_jump)         begin $display("  ** ERROR: jump never executed");            errors = errors + 1; end

        $display("=====================================================");
        if (errors == 0) $display("  RESULT: PASS  (%0d instructions retired, 0 errors)", icount);
        else             $display("  RESULT: FAIL  (%0d errors)", errors);
        $display("=====================================================");
        $finish;
    end
endmodule
