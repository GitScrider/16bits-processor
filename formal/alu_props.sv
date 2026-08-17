// =============================================================================
//  alu_props.sv  --  formal properties for the ALU (combinational -> exhaustive)
// -----------------------------------------------------------------------------
//  Wraps rtl/alu.sv and asserts properties that must hold for EVERY input. Since
//  the ALU is combinational, Yosys's built-in SAT engine can prove these for all
//  2^35 (a, b, ulaop) combinations in one shot -- no simulation, no sampling.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv rtl/alu.sv formal/alu_props.sv; \
//                     prep -top alu_props -flatten; sat -prove-asserts -verify"
// =============================================================================

module alu_props (
    input logic [15:0] a,
    input logic [15:0] b,
    input logic [2:0]  ulaop
);
    logic [15:0] result;
    logic        zero;

    alu dut (.a(a), .b(b), .ulaop(ulaop), .result(result), .zero(zero));

    always_comb begin
        // The ZERO flag is exactly "result is zero".
        assert (zero == (result == 16'd0));

        // add / sub match plain 16-bit two's-complement arithmetic.
        if (ulaop == 3'b000) assert (result == (a + b));
        if (ulaop == 3'b001) assert (result == (a - b));

        // set-less-than yields exactly 0 or 1 (never anything else).
        if (ulaop == 3'b100) assert (result == 16'd0 || result == 16'd1);

        // divide guards against divide-by-zero (returns 0, never traps/X).
        if (ulaop == 3'b011 && b == 16'd0) assert (result == 16'd0);
    end
endmodule
