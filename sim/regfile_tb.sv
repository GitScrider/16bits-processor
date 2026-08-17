// =============================================================================
//  regfile_tb.sv  --  self-checking testbench for the 16 x 16-bit register file
// -----------------------------------------------------------------------------
//  Run (ModelSim ASE, bundled with Quartus):
//      vlib work
//      vlog -sv ../rtl/regfile.sv regfile_tb.sv
//      vsim -c -do "run -all; quit -f" regfile_tb
//
//  Checks: reset clears all registers; a written value reads back; write-enable
//  actually gates writes; the two read ports are independent; and a random
//  write-all / read-all sweep matches a reference model.
// =============================================================================

`timescale 1ns/1ps

module regfile_tb;

    localparam int WIDTH = 16;
    localparam int NREG  = 16;
    localparam int SEL   = 4;

    logic             clk = 1'b0;
    logic             rst, we;
    logic [SEL-1:0]   rd, rx, ry;
    logic [WIDTH-1:0] wdata, rx_data, ry_data;

    int errors = 0;
    int checks = 0;

    // reference model of what each register should hold
    logic [WIDTH-1:0] model [0:NREG-1];

    // Device under test
    regfile #(.WIDTH(WIDTH), .NREG(NREG), .SEL(SEL)) dut (
        .clk(clk), .rst(rst), .we(we),
        .rd(rd), .wdata(wdata),
        .rx(rx), .ry(ry),
        .rx_data(rx_data), .ry_data(ry_data)
    );

    // free-running clock: 10 ns period
    always #5 clk = ~clk;

    // drive one write that commits on the next rising edge
    task automatic wr(input [SEL-1:0] r, input [WIDTH-1:0] v);
        @(negedge clk);
        we = 1'b1; rd = r; wdata = v;
        @(posedge clk);          // write commits here
        @(negedge clk); we = 1'b0;
        model[r] = v;
    endtask

    // read both ports and check against the model
    task automatic rdchk(input [SEL-1:0] a, input [SEL-1:0] b);
        rx = a; ry = b;
        #1;                       // let the combinational read settle
        checks++;
        if (rx_data !== model[a]) begin
            errors++;
            $display("  FAIL rx: reg[%0d] = %h (expected %h)", a, rx_data, model[a]);
        end
        if (ry_data !== model[b]) begin
            errors++;
            $display("  FAIL ry: reg[%0d] = %h (expected %h)", b, ry_data, model[b]);
        end
    endtask

    integer i, k;

    initial begin
        $dumpfile("regfile_tb.vcd");
        $dumpvars(0, regfile_tb);

        $display("== Register file self-checking testbench ==");

        we = 1'b0; rd = 4'd0; rx = 4'd0; ry = 4'd0; wdata = 16'd0; rst = 1'b1;

        // ---- Reset: hold rst over a rising edge, all registers clear ---------
        @(negedge clk); @(posedge clk); @(negedge clk);
        rst = 1'b0;
        for (i = 0; i < NREG; i = i + 1) model[i] = {WIDTH{1'b0}};

        // every register (both ports) must read as zero after reset
        for (i = 0; i < NREG; i = i + 1) rdchk(i[SEL-1:0], i[SEL-1:0]);

        // ---- Directed write / read-back --------------------------------------
        wr(4'd5, 16'hABCD);
        rdchk(4'd5, 4'd5);

        // ---- Write-enable gating: we=0 must NOT change register 5 ------------
        @(negedge clk); we = 1'b0; rd = 4'd5; wdata = 16'h1111;
        @(posedge clk); @(negedge clk);
        rdchk(4'd5, 4'd5);                     // still 0xABCD

        // ---- Two independent read ports --------------------------------------
        wr(4'd2, 16'h1234);
        wr(4'd9, 16'h5678);
        rdchk(4'd2, 4'd9);

        // ---- Random write-all then random read-back sweep --------------------
        for (i = 0; i < NREG; i = i + 1) wr(i[SEL-1:0], $random);
        for (k = 0; k < 500; k = k + 1) rdchk($random, $random);

        // ---- Summary ---------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "regfile testbench failed");
        $finish;
    end

endmodule
