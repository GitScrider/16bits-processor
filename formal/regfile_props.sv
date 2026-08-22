// =============================================================================
//  regfile_props.sv  --  formal properties for the 16x16 register file
// -----------------------------------------------------------------------------
//  Proves the register file's read/write contract for ALL inputs, by k-induction
//  with Yosys's built-in SAT engine (no external solver). Using $past, each cycle
//  we check the two guarantees that matter:
//
//    1. After a reset, every register reads back as zero.
//    2. A value written to a register (we, rd, wdata) is returned by a read of
//       that same register on the next cycle -- the write is stored, not lost.
//
//  These follow directly from the flip-flop update, so they are inductive.
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv -formal rtl/regfile.sv formal/regfile_props.sv; \
//                     prep -top regfile_props -flatten; memory_map; opt -full; async2sync; \
//                     chformal -lower; sat -tempinduct -set-init-zero -prove-asserts -seq 20 -verify"
// =============================================================================

module regfile_props (
    input logic        clk, rst, we,
    input logic [3:0]  rd, rx, ry,
    input logic [15:0] wdata
);
    logic [15:0] rx_data, ry_data;

    regfile #(.WIDTH(16), .NREG(16), .SEL(4)) dut (
        .clk(clk), .rst(rst), .we(we), .rd(rd), .wdata(wdata),
        .rx(rx), .ry(ry), .rx_data(rx_data), .ry_data(ry_data)
    );

    // $past is undefined in the first cycle; gate the checks until it is valid.
    logic past_valid = 1'b0;
    always_ff @(posedge clk) past_valid <= 1'b1;

    always_ff @(posedge clk) if (past_valid) begin
        // (1) a reset clears every register -> any read returns zero afterwards
        if ($past(rst))
            assert (rx_data == 16'h0000);
        // (2) a value written last cycle is read back this cycle from that reg
        else if ($past(we) && rx == $past(rd))
            assert (rx_data == $past(wdata));
    end
endmodule
