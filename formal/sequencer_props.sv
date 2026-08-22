// =============================================================================
//  sequencer_props.sv  --  formal property for the 5-phase sequencer (temporal)
// -----------------------------------------------------------------------------
//  SEQUENTIAL safety invariant, proved by k-induction with Yosys's built-in SAT
//  engine (no external solver needed).
//
//  With the flops initialised to zero (sat -set-init-zero), the phase register is
//  always either the all-zero power-on value -- which the module's self-correcting
//  guard turns into 00001 on the very next edge -- or a valid ONE-HOT code. That
//  invariant is 1-inductive (reset -> 00001; all-zero -> 00001; and rotating a
//  one-hot value always yields a one-hot value), so induction proves it holds for
//  ALL time and ALL inputs: the ring can never wander into an illegal multi-hot
//  state and get stuck.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv -formal rtl/sequencer.sv formal/sequencer_props.sv; \
//                     prep -top sequencer_props -flatten; async2sync; chformal -lower; \
//                     sat -tempinduct -set-init-zero -prove-asserts -seq 20 -verify"
// =============================================================================

module sequencer_props (input logic clk, rst);
    logic [4:0] phase;

    sequencer dut (.clk(clk), .rst(rst), .phase(phase));

    // The phase register is always a valid code: the transient all-zero power-on
    // value, or exactly one hot bit. Never an illegal multi-hot combination.
    always_ff @(posedge clk)
        assert (phase == 5'b00000 || $onehot(phase));
endmodule
