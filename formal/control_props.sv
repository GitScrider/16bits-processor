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
        // regwrite: write a result for the arithmetic ops (0x1..0x9) and lw (0xC).
        assert (regwrite == ((op >= 4'h1 && op <= 4'h9) || op == 4'hC));
        // alusrc (immediate operand): only the immediate ALU ops addi..divi (0x1..0x4).
        assert (alusrc  == (op >= 4'h1 && op <= 4'h4));
        // jump: only j (0xD).
        assert (jump    == (op == 4'hD));
        // branch: only beqz (0xA).
        assert (branch  == (op == 4'hA));
        // memwrite: only sw (0xB).
        assert (memwrite == (op == 4'hB));
        // memula (mem-to-reg): only lw (0xC).
        assert (memula  == (op == 4'hC));
        // reserved opcodes 0xE / 0xF assert no control line (all quiet).
        if (op == 4'hE || op == 4'hF)
            assert (!jump && !branch && !memwrite && !memula && !aluadr && !regwrite && !alusrc && ulaop == 3'b000);
    end
endmodule
