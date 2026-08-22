// =============================================================================
//  pc_props.sv  --  formal properties for the program counter (temporal)
// -----------------------------------------------------------------------------
//  Proves the PC's next-state relation and its priority order for ALL inputs, by
//  k-induction with Yosys's built-in SAT engine. Using $past, each cycle we check
//  that pc_out took the value the spec demands from the PREVIOUS cycle's inputs:
//     reset  >  load  >  enable(+1)  >  hold
//  (Only the first true branch fires -- that is exactly "load beats enable".)
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv -formal rtl/pc.sv formal/pc_props.sv; \
//                     prep -top pc_props -flatten; async2sync; chformal -lower; \
//                     sat -tempinduct -set-init-zero -prove-asserts -seq 20 -verify"
// =============================================================================

module pc_props (
    input logic       clk, rst, en, load,
    input logic [3:0] target
);
    logic [3:0] pc_out;

    pc #(.W(4)) dut (
        .clk(clk), .rst(rst), .en(en), .load(load),
        .target(target), .pc_out(pc_out)
    );

    // $past is undefined in the first cycle; gate the checks until it is valid.
    logic past_valid = 1'b0;
    always_ff @(posedge clk) past_valid <= 1'b1;

    always_ff @(posedge clk) if (past_valid) begin
        if      ($past(rst))  assert (pc_out == 4'd0);                 // reset -> 0
        else if ($past(load)) assert (pc_out == $past(target));        // load beats enable
        else if ($past(en))   assert (pc_out == $past(pc_out) + 4'd1); // advance, wraps
        else                  assert (pc_out == $past(pc_out));        // hold
    end
endmodule
