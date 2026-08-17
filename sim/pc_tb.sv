// =============================================================================
//  pc_tb.sv  --  self-checking testbench for the program counter
// -----------------------------------------------------------------------------
//  Run (ModelSim ASE, bundled with Quartus):
//      vlib work
//      vlog -sv ../rtl/pc.sv pc_tb.sv
//      vsim -c -do "run -all; quit -f" pc_tb
//
//  Or with Icarus Verilog:
//      iverilog -g2012 -o pc_tb.vvp ../rtl/pc.sv pc_tb.sv && vvp pc_tb.vvp
//
//  Checks: synchronous reset forces PC to 0; with en=1 the PC counts
//  0,1,2,3,...; load=1 (target=7) redirects the PC and beats en; with
//  en=0 && load=0 the PC holds; the counter wraps at the top (2**W -> 0); and a
//  long pseudo-random sweep of all four controls tracks a reference model.
// =============================================================================

`timescale 1ns/1ps

module pc_tb;

    localparam int W = 4;                       // PC width (matches 16-word imem)
    localparam logic [W-1:0] TOP = {W{1'b1}};   // top address = 2**W - 1 (=15)

    // DUT ports
    logic         clk = 1'b0;
    logic         rst, en, load;
    logic [W-1:0] target;
    logic [W-1:0] pc_out;

    // Reference model: a plain copy of what the PC *should* hold.
    logic [W-1:0] model;

    int errors = 0;
    int checks = 0;

    // Device under test
    pc #(.W(W)) dut (
        .clk(clk), .rst(rst), .en(en), .load(load),
        .target(target), .pc_out(pc_out)
    );

    // free-running clock: 10 ns period
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    //  step(): drive the four controls, let one clock edge apply them, update
    //  the reference model with the SAME priority (rst > load > en > hold), then
    //  compare the DUT against the model.
    // -------------------------------------------------------------------------
    task automatic step(input logic r, input logic e, input logic l,
                        input logic [W-1:0] t, input string name);
        @(negedge clk);
        rst = r; en = e; load = l; target = t;
        @(posedge clk);              // DUT registers its next value here
        // mirror the DUT's priority chain in software:
        if (r)       model = {W{1'b0}};
        else if (l)  model = t;
        else if (e)  model = model + 1'b1;   // wraps naturally at 2**W
        // else: HOLD -> leave model unchanged
        #1;                          // let the non-blocking update settle
        checks++;
        if (pc_out !== model) begin
            errors++;
            $display("  FAIL [%s] pc=%0d (expected %0d)  [rst=%b en=%b load=%b target=%0d]",
                     name, pc_out, model, r, e, l, t);
        end
    endtask

    integer i;

    initial begin
        $dumpfile("pc_tb.vcd");
        $dumpvars(0, pc_tb);

        $display("== Program counter self-checking testbench ==");

        // safe initial drive
        rst = 1'b1; en = 1'b0; load = 1'b0; target = {W{1'b0}};
        model = {W{1'b0}};

        // ---- Synchronous reset: PC must be 0 --------------------------------
        step(1'b1, 1'b0, 1'b0, 4'd0, "reset");
        step(1'b1, 1'b1, 1'b1, 4'd9, "reset-beats-all"); // rst wins over load/en

        // ---- Count up: en=1 should give 1,2,3,4,5,6 ------------------------
        for (i = 0; i < 6; i = i + 1)
            step(1'b0, 1'b1, 1'b0, 4'd0, "count-up");

        // ---- Load a target: PC jumps to 7 ----------------------------------
        step(1'b0, 1'b0, 1'b1, 4'd7, "load-7");

        // ---- Load priority: load must beat en on the same edge -------------
        step(1'b0, 1'b1, 1'b1, 4'd3, "load-beats-en");   // -> 3, not 8

        // ---- Hold: neither load nor en -> PC keeps its value ---------------
        step(1'b0, 1'b0, 1'b0, 4'd0, "hold");
        step(1'b0, 1'b0, 1'b0, 4'd0, "hold");            // still 3

        // ---- Wrap-around at the top: TOP (=15) then +1 rolls over to 0 ------
        step(1'b0, 1'b0, 1'b1, TOP,  "load-top");        // PC = 15
        step(1'b0, 1'b1, 1'b0, 4'd0, "wrap");            // 15 + 1 -> 0

        // ---- Pseudo-random sweep of all four controls ----------------------
        // Reset once to a known state, then hammer random control combinations
        // and confirm the DUT always matches the reference model.
        step(1'b1, 1'b0, 1'b0, 4'd0, "rand-reset");
        for (i = 0; i < 1000; i = i + 1) begin
            logic r, e, l;
            logic [W-1:0] t;
            r = ($random % 8 == 0);   // reset occasionally (~1 in 8)
            e = $random;
            l = $random;
            t = $random;
            step(r, e, l, t, "rand");
        end

        // ---- Summary --------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "pc testbench failed");
        $finish;
    end

endmodule
