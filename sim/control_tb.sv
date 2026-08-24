// =============================================================================
//  control_tb.sv  --  self-checking testbench for the Control Unit (decoder)
// -----------------------------------------------------------------------------
//  Run (ModelSim ASE, bundled with Quartus):
//      vlib work
//      vlog -sv ../rtl/control.sv control_tb.sv
//      vsim -c -do "run -all; quit -f" control_tb
//
//  Or with Icarus Verilog:
//      iverilog -g2012 -o control_tb.vvp ../rtl/control.sv control_tb.sv
//      vvp control_tb.vvp
//
//  Strategy: the control unit is a pure lookup table, so the ideal test is to
//  exercise EVERY possible input. There are only 16 opcodes (4 bits), so we
//  sweep op = 0..15, pack the DUT's outputs into one bus, and compare it to a
//  golden reference bus for that opcode. If any bit differs, we print the
//  offending opcode and expected/actual buses, then FAIL.
//
//  The reference is written as a "truth table in code": one 10-bit vector per
//  opcode, each built from named fields in the exact column order of the spec:
//      {jump, branch, memwrite, memula, aluadr, ulaop[2:0], regwrite, alusrc}
//  so a human can read a row here and check it against the design brief.
//  Note: jr (0xF) asserts BOTH jump and branch -- that unique pair is how the
//  datapath recognises a register-indirect jump.
// =============================================================================

`timescale 1ns/1ps

module control_tb;

    // DUT inputs / outputs
    logic [3:0] op;
    logic       jump;
    logic       branch;
    logic       memwrite;
    logic       memula;
    logic       aluadr;
    logic [2:0] ulaop;
    logic       regwrite;
    logic       alusrc;

    int errors = 0;
    int checks = 0;

    // Device under test
    control dut (
        .op(op),
        .jump(jump),
        .branch(branch),
        .memwrite(memwrite),
        .memula(memula),
        .aluadr(aluadr),
        .ulaop(ulaop),
        .regwrite(regwrite),
        .alusrc(alusrc)
    );

    // ---- Pack the DUT outputs into one 10-bit bus, MSB..LSB in spec order ----
    //   bit:  9    8      7        6      5      4:2       1        0
    //        jump branch memwrite memula aluadr ulaop[2:0] regwrite alusrc
    logic [9:0] dut_bus;
    assign dut_bus = {jump, branch, memwrite, memula, aluadr, ulaop, regwrite, alusrc};

    // ---- Golden reference: the truth table, one 10-bit row per opcode --------
    logic [9:0] expected [0:15];

    // helper: assemble a row from its named fields
    function automatic logic [9:0] row(
        input logic       f_jump,
        input logic       f_branch,
        input logic       f_memwrite,
        input logic       f_memula,
        input logic       f_aluadr,
        input logic [2:0] f_ulaop,
        input logic       f_regwrite,
        input logic       f_alusrc);
        row = {f_jump, f_branch, f_memwrite, f_memula, f_aluadr,
               f_ulaop, f_regwrite, f_alusrc};
    endfunction

    integer o;

    initial begin
        $dumpfile("control_tb.vcd");
        $dumpvars(0, control_tb);

        $display("== Control unit self-checking testbench ==");

        // ---- Build the golden truth table -----------------------------------
        //                    jump branch memw  memula aluadr ulaop    regw  alusrc
        expected[4'h0] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b000,  1'b1, 1'b1); // addi
        expected[4'h1] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b001,  1'b1, 1'b1); // subi
        expected[4'h2] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b010,  1'b1, 1'b1); // muli
        expected[4'h3] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b011,  1'b1, 1'b1); // divi
        expected[4'h4] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b000,  1'b1, 1'b0); // add
        expected[4'h5] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b001,  1'b1, 1'b0); // sub
        expected[4'h6] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b010,  1'b1, 1'b0); // mul
        expected[4'h7] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b011,  1'b1, 1'b0); // div
        expected[4'h8] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b100,  1'b1, 1'b0); // slt
        expected[4'h9] = row(1'b0, 1'b1,  1'b0, 1'b0,  1'b1,  3'b101,  1'b0, 1'b0); // beqz
        expected[4'hA] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b000,  1'b0, 1'b0); // reserved
        expected[4'hB] = row(1'b0, 1'b0,  1'b0, 1'b0,  1'b0,  3'b000,  1'b0, 1'b0); // reserved
        expected[4'hC] = row(1'b0, 1'b0,  1'b1, 1'b0,  1'b1,  3'b000,  1'b0, 1'b0); // sw
        expected[4'hD] = row(1'b0, 1'b0,  1'b0, 1'b1,  1'b1,  3'b000,  1'b1, 1'b0); // lw
        expected[4'hE] = row(1'b1, 1'b0,  1'b0, 1'b0,  1'b0,  3'b000,  1'b0, 1'b0); // j
        expected[4'hF] = row(1'b1, 1'b1,  1'b0, 1'b0,  1'b0,  3'b000,  1'b0, 1'b0); // jr (jump+branch)

        // ---- Exhaustive sweep of all 16 opcodes -----------------------------
        for (o = 0; o < 16; o = o + 1) begin
            op = o[3:0];
            #1; // let the combinational decoder settle
            checks++;
            if (dut_bus !== expected[o]) begin
                errors++;
                $display("  FAIL op=0x%0h : dut=%b expected=%b", o[3:0], dut_bus, expected[o]);
                $display("        (order: jump branch memwrite memula aluadr ulaop[2:0] regwrite alusrc)");
            end
        end

        // ---- Summary --------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "control testbench failed");
        $finish;
    end

endmodule
