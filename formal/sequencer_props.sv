// =============================================================================
//  sequencer_props.sv  --  formal property for the 5-phase sequencer (temporal)
// -----------------------------------------------------------------------------
//  This is a SEQUENTIAL property: "phase is always one-hot". Proving it needs
//  temporal reasoning — assume the machine starts in reset (so it begins at the
//  one-hot phase 00001), then prove one-hot is preserved forever by k-induction.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv rtl/sequencer.sv formal/sequencer_props.sv; \
//                     prep -top sequencer_props -flatten; chformal -lower; \
//                     sat -tempinduct -prove-asserts -seq 20"
// =============================================================================

module sequencer_props (input logic clk, rst);
    logic [4:0] phase;

    sequencer dut (.clk(clk), .rst(rst), .phase(phase));

    // In the very first state, assume the sequencer is being reset -> it starts
    // at phase 00001 (one-hot) rather than an arbitrary/unknown value.
    always_comb if ($initstate) assume (rst);

    // Whenever it is not held in reset, the phase register must be one-hot.
    always_ff @(posedge clk)
        if (!rst) assert ($onehot(phase));
endmodule
