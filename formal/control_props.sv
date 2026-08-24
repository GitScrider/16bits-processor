// =============================================================================
//  control_props.sv  --  formal properties for the control unit (exhaustive)
// -----------------------------------------------------------------------------
//  The decoder is combinational, so Yosys's SAT engine proves these for ALL 16
//  opcodes at once: each control line is asserted for EXACTLY the right opcodes.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv rtl/control.sv formal/control_props.sv; \
//                     prep -top control_props -flatten; chformal -lower; sat -prove-asserts -verify"
// =============================================================================

module control_props (input logic [3:0] op);
    logic       jump, branch, memwrite, memula, aluadr, regwrite, alusrc;
    logic [2:0] ulaop;

    control dut (.op(op), .jump(jump), .branch(branch), .memwrite(memwrite),
                 .memula(memula), .aluadr(aluadr), .ulaop(ulaop),
                 .regwrite(regwrite), .alusrc(alusrc));

    always_comb begin
        // regwrite: write a result for the arithmetic/slt ops (0x0..0x8) and lw (0xD).
        assert (regwrite == ((op <= 4'h8) || op == 4'hD));
        // alusrc (immediate operand): only the immediate ALU ops addi..divi (0x0..0x3).
        assert (alusrc  == (op <= 4'h3));
        // jump: j (0xE) and jr (0xF). jr asserts jump AND branch together.
        assert (jump    == (op == 4'hE || op == 4'hF));
        // branch: beqz (0x9) and jr (0xF). The jump+branch pair means jr.
        assert (branch  == (op == 4'h9 || op == 4'hF));
        // memwrite: only sw (0xC).
        assert (memwrite == (op == 4'hC));
        // memula (mem-to-reg): only lw (0xD).
        assert (memula  == (op == 4'hD));
        // aluadr (data-memory-address / branch-compare path): beqz, sw, lw.
        assert (aluadr  == (op == 4'h9 || op == 4'hC || op == 4'hD));
        // ulaop selects the ALU function per opcode.
        assert (ulaop == ((op == 4'h1 || op == 4'h5) ? 3'b001 :  // sub  (subi, sub)
                          (op == 4'h2 || op == 4'h6) ? 3'b010 :  // mul  (muli, mul)
                          (op == 4'h3 || op == 4'h7) ? 3'b011 :  // div  (divi, div)
                          (op == 4'h8)               ? 3'b100 :  // slt
                          (op == 4'h9)               ? 3'b101 :  // subtract-for-ZERO (beqz)
                                                       3'b000)); // add / mem / jump / reserved
        // reserved opcodes 0xA / 0xB assert no control line (all quiet).
        if (op == 4'hA || op == 4'hB)
            assert (!jump && !branch && !memwrite && !memula && !aluadr && !regwrite && !alusrc && ulaop == 3'b000);
    end
endmodule
