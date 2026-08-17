// =============================================================================
//  sequencer_tb.sv  --  self-checking testbench for the 5-phase sequencer
// -----------------------------------------------------------------------------
//  Run (ModelSim ASE, bundled with Quartus):
//      vlib work
//      vlog -sv ../rtl/sequencer.sv sequencer_tb.sv
//      vsim -c -do "run -all; quit -f" sequencer_tb
//
//  Or with Icarus Verilog:
//      iverilog -g2012 -o sequencer_tb.vvp ../rtl/sequencer.sv sequencer_tb.sv
//      vvp sequencer_tb.vvp
//
//  What we check:
//    * after reset the phase is exactly 5'b00001 (start at PC);
//    * over ~15 clock edges the phase steps through the EXACT one-hot ring
//      00001 -> 00010 -> 00100 -> 01000 -> 10000 -> 00001 -> ... cyclically;
//    * on EVERY sampled cycle the output is truly one-hot (exactly one bit set),
//      checked with $countones.
//
//  The reference model is a copy of the ring kept here in the testbench: it is
//  seeded to 00001 and rotated left the same way the DUT should rotate. If the
//  DUT ever disagrees we print the mismatch and $fatal at the end.
// =============================================================================

`timescale 1ns/1ps

module sequencer_tb;

    // DUT connections
    logic       clk = 1'b0;
    logic       rst;
    logic [4:0] phase;

    // Self-checking bookkeeping
    int errors = 0;
    int checks = 0;

    // Reference model: the phase value we EXPECT to see this cycle.
    logic [4:0] exp_phase;

    // Device under test
    sequencer dut (
        .clk(clk),
        .rst(rst),
        .phase(phase)
    );

    // Free-running clock: 10 ns period (toggle every 5 ns).
    always #5 clk = ~clk;

    // Compare the DUT against the reference model for the current cycle:
    //   1) the phase must be one-hot (exactly one bit set), and
    //   2) it must equal the expected ring value.
    task automatic chk(input string tag);
        checks++;
        if ($countones(phase) !== 1) begin
            errors++;
            $display("  FAIL [%s] not one-hot: phase=%b (countones=%0d)",
                     tag, phase, $countones(phase));
        end
        if (phase !== exp_phase) begin
            errors++;
            $display("  FAIL [%s] phase=%b (expected %b)", tag, phase, exp_phase);
        end
    endtask

    integer i;

    initial begin
        $dumpfile("sequencer_tb.vcd");
        $dumpvars(0, sequencer_tb);

        $display("== 5-phase sequencer self-checking testbench ==");

        // ---- Reset: hold rst across a rising edge so it takes effect ----------
        rst = 1'b1;
        @(negedge clk); @(posedge clk); @(negedge clk);
        exp_phase = 5'b00001;          // reset defines the starting state (PC)
        chk("after-reset");            // phase must be 00001 and one-hot
        rst = 1'b0;                    // release reset; ring is free to advance

        // ---- Free-run: walk the ring for ~15 edges (three full laps) ----------
        //  Each rising edge the DUT rotates left; we rotate the reference the
        //  same way, then sample at the following negedge where signals are
        //  stable and compare. Fifteen edges wraps 10000 -> 00001 three times,
        //  which is what proves the sequence is CYCLIC, not just monotonic.
        for (i = 0; i < 15; i = i + 1) begin
            @(posedge clk);            // DUT advances one phase here
            exp_phase = {exp_phase[3:0], exp_phase[4]}; // reference rotates too
            @(negedge clk);            // sample where the register is settled
            chk("ring");
        end

        // ---- Summary ---------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "sequencer testbench failed");
        $finish;
    end

endmodule
