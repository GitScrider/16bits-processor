// =============================================================================
//  imem_tb.sv  --  self-checking testbench for the 16 x 16-bit instruction ROM
// -----------------------------------------------------------------------------
//  Run (ModelSim ASE, bundled with Quartus):
//      vlib work
//      vlog -sv ../rtl/imem.sv imem_tb.sv
//      vsim -c -do "run -all; quit -f" imem_tb
//
//  Or with Icarus Verilog:
//      iverilog -g2012 -o imem_tb.vvp ../rtl/imem.sv imem_tb.sv
//      vvp imem_tb.vvp
//      gtkwave imem_tb.vcd     # optional: view the waveform
//
//  Checks: reading every address 0..15 returns the expected word -- the seven
//  demo-program words in the first slots, and 0x0000 everywhere after. Because
//  the read is combinational there is no clock: we just drive the address, let
//  the logic settle, and compare against an in-testbench reference array.
// =============================================================================

`timescale 1ns/1ps

module imem_tb;

    localparam int AW = 4;             // address width
    localparam int DW = 16;            // data width
    localparam int NWORDS = (1 << AW); // = 16 words

    logic [AW-1:0] addr;
    logic [DW-1:0] instr;

    int errors = 0;
    int checks = 0;

    // Reference model: what each address is expected to contain. Mirrors the
    // inline demo program in rtl/imem.sv -- 7 words, then zeros.
    logic [DW-1:0] expected [0:NWORDS-1];

    // Device under test
    imem #(.AW(AW), .DW(DW)) dut (
        .addr(addr),
        .instr(instr)
    );

    integer i;

    initial begin
        $dumpfile("imem_tb.vcd");
        $dumpvars(0, imem_tb);

        $display("== Instruction memory (L1-I) self-checking testbench ==");

        // ---- Build the expected contents ------------------------------------
        for (i = 0; i < NWORDS; i = i + 1)
            expected[i] = {DW{1'b0}};        // default: zero
        expected[0] = 16'h0000;
        expected[1] = 16'h0112;
        expected[2] = 16'h0221;
        expected[3] = 16'h8312;
        expected[4] = 16'h9032;
        expected[5] = 16'h0240;
        expected[6] = 16'he003;
        // expected[7]..expected[15] remain 16'h0000.

        // ---- Read every address and compare ---------------------------------
        for (i = 0; i < NWORDS; i = i + 1) begin
            addr = i[AW-1:0];
            #1;                              // let the combinational read settle
            checks++;
            if (instr !== expected[i]) begin
                errors++;
                $display("  FAIL mem[%0d] = %h (expected %h)",
                         i, instr, expected[i]);
            end else begin
                $display("  ok   mem[%0d] = %h", i, instr);
            end
        end

        // ---- Summary --------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "imem testbench failed");
        $finish;
    end

endmodule
