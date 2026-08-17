// =============================================================================
//  alu_tb.sv  --  self-checking testbench for the 16-bit ALU
// -----------------------------------------------------------------------------
//  Run with Icarus Verilog:
//      iverilog -g2012 -o alu_tb.vvp ../rtl/alu.sv alu_tb.sv
//      vvp alu_tb.vvp
//      gtkwave alu_tb.vcd     # optional: view the waveform
//
//  Or with ModelSim/Questa (comes with Quartus):
//      vlog ../rtl/alu.sv alu_tb.sv && vsim -c alu_tb -do "run -all; quit"
//
//  The testbench drives directed + pseudo-random vectors and checks the DUT
//  against a reference model computed here. It prints a PASS/FAIL summary and
//  exits non-zero on failure so it can be used in CI later.
// =============================================================================

`timescale 1ns/1ps

module alu_tb;

    localparam int WIDTH = 16;

    // ULAOP codes (mirror rtl/alu.sv)
    localparam logic [2:0] OP_ADD  = 3'b000;
    localparam logic [2:0] OP_SUB  = 3'b001;
    localparam logic [2:0] OP_MUL  = 3'b010;
    localparam logic [2:0] OP_DIV  = 3'b011;
    localparam logic [2:0] OP_SLT  = 3'b100;
    localparam logic [2:0] OP_BEQZ = 3'b101;

    logic [WIDTH-1:0] a, b, result;
    logic [2:0]       ulaop;
    logic             zero;

    localparam logic [WIDTH-1:0] ZERO16 = {WIDTH{1'b0}};

    int errors = 0;
    int checks = 0;

    // Device under test
    alu #(.WIDTH(WIDTH)) dut (
        .a(a), .b(b), .ulaop(ulaop), .result(result), .zero(zero)
    );

    // Reference model -- what RESULT *should* be for the given inputs.
    function automatic logic [WIDTH-1:0] ref_result(
        input logic [WIDTH-1:0] ra, input logic [WIDTH-1:0] rb, input logic [2:0] op);
        logic signed [WIDTH-1:0] sra, srb;
        sra = ra; srb = rb;
        case (op)
            OP_ADD  : ref_result = ra + rb;
            OP_SUB  : ref_result = ra - rb;
            OP_BEQZ : ref_result = ra - rb;
            OP_MUL  : ref_result = ra * rb;
            OP_DIV  : ref_result = (rb == ZERO16) ? ZERO16 : (sra / srb);
            OP_SLT  : ref_result = (sra < srb) ? {{(WIDTH-1){1'b0}}, 1'b1} : ZERO16;
            default : ref_result = ZERO16;
        endcase
    endfunction

    task automatic check(input logic [WIDTH-1:0] ta, tb_, input logic [2:0] top,
                         input string name);
        logic [WIDTH-1:0] exp;
        a = ta; b = tb_; ulaop = top;
        #1; // let combinational logic settle
        exp = ref_result(ta, tb_, top);
        checks++;
        if (result !== exp) begin
            errors++;
            $display("  FAIL [%s] a=%0d b=%0d op=%b -> result=%0d (expected %0d)",
                     name, $signed(ta), $signed(tb_), top, $signed(result), $signed(exp));
        end
        if (zero !== (exp == ZERO16)) begin
            errors++;
            $display("  FAIL [%s zero] a=%0d b=%0d op=%b -> zero=%b (expected %b)",
                     name, $signed(ta), $signed(tb_), top, zero, (exp == ZERO16));
        end
    endtask

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        $display("== ALU self-checking testbench ==");

        // ---- Directed cases -------------------------------------------------
        check(16'd5,  16'd3,  OP_ADD,  "add");
        check(16'd5,  16'd3,  OP_SUB,  "sub");
        check(16'd3,  16'd3,  OP_SUB,  "sub-equal");     // -> zero flag
        check(16'd4,  16'd3,  OP_MUL,  "mul");
        check(16'd20, 16'd4,  OP_DIV,  "div");
        check(16'd7,  16'd0,  OP_DIV,  "div-by-zero");   // guarded -> 0
        check(-16'sd4, 16'd3, OP_SLT,  "slt-neg-true");  // -4 < 3 -> 1
        check(16'd9,  16'd2,  OP_SLT,  "slt-false");     //  9 < 2 -> 0
        check(16'd0,  16'd0,  OP_BEQZ, "beqz-zero");     // -> zero flag
        check(16'd5,  16'd5,  OP_BEQZ, "beqz-eq");       // 5-5=0 -> zero flag

        // ---- Pseudo-random sweep -------------------------------------------
        for (int i = 0; i < 2000; i++) begin
            logic [WIDTH-1:0] ra, rb;
            logic [2:0]       op;
            ra = $random;
            rb = $random;
            op = $random % 6; // 0..5 = defined ops
            check(ra, rb, op, "rand");
        end

        // ---- Summary --------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "ALU testbench failed");
        $finish;
    end

endmodule
