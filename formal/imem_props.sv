// =============================================================================
//  imem_props.sv  --  formal properties for the instruction memory (ROM)
// -----------------------------------------------------------------------------
//  Proves the instruction ROM's contents and read behaviour for ALL addresses,
//  exhaustively, with Yosys's built-in SAT engine (no external solver).
//
//  The instruction memory is a 16-word ROM read combinationally (instr = mem[addr]
//  with no clock). Its contents are fixed at elaboration in imem.sv's initial
//  block. After `memory_map; opt -full` Yosys bakes those constants into flat
//  logic (an address-selected mux over the stored words) -- exactly the way it
//  synthesises to ~10 logic elements with no RAM block -- so a single SAT query
//  proves, for EVERY one of the 16 addresses at once, that the word delivered is
//  the intended program word and that instr is a pure function of addr.
//
//  The golden program below is a copy of the 7 words imem.sv lays down (the rest
//  of the ROM clears to 0x0000). If the RTL program changes, update both.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv -formal rtl/imem.sv formal/imem_props.sv; \
//                     prep -top imem_props -flatten; memory_map; opt -full; \
//                     chformal -lower; sat -prove-asserts -verify"
// =============================================================================

module imem_props (input logic [3:0] addr);
    logic [15:0] instr;

    imem #(.AW(4), .DW(16)) dut (.addr(addr), .instr(instr));

    // Golden copy of the demo program (must match imem.sv's initial block).
    function automatic logic [15:0] expected(input logic [3:0] a);
        case (a)
            4'h0: expected = 16'h0000;  // addi r0,r0,0  (no-op)
            4'h1: expected = 16'h0112;  // addi r1,r1,2
            4'h2: expected = 16'h0221;  // addi r2,r2,1
            4'h3: expected = 16'h8312;  // slt  r3,r1,r2
            4'h4: expected = 16'h9032;  // beqz r3,2
            4'h5: expected = 16'h0240;  // addi r2,r4,0  (r2=0)
            4'h6: expected = 16'he003;  // j    3
            default: expected = 16'h0000;  // mem[7..15] cleared to 0
        endcase
    endfunction

    // Every address returns exactly its intended word -- checked for all 16.
    always_comb assert (instr == expected(addr));
endmodule
