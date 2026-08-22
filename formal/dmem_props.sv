// =============================================================================
//  dmem_props.sv  --  formal properties for the data memory (registered read)
// -----------------------------------------------------------------------------
//  Proves the data memory's registered-read write-through for ALL inputs, by
//  k-induction with Yosys's built-in SAT engine (no external solver).
//
//  The read is REGISTERED (rdata <= mem[addr]), so a value appears one cycle
//  after its address. Using $past at depth 2 we check the round trip: if a word
//  W was written to address A two cycles ago, and address A was read one cycle
//  ago with no intervening overwrite, then rdata delivers exactly W now. This
//  captures both the 1-cycle read latency and correct storage in one property.
//
//  The proof instantiates the memory with a small address width (AW=4). The
//  read/write LOGIC is identical for any size, so this proves the behaviour
//  without flattening the full 64K-word array (which would be intractable).
//
//  Run:
//    yowasp-yosys -p "read_verilog -sv -formal rtl/dmem.sv formal/dmem_props.sv; \
//                     prep -top dmem_props -flatten; memory_map; opt -full; async2sync; \
//                     chformal -lower; sat -tempinduct -set-init-zero -prove-asserts -seq 20 -verify"
// =============================================================================

module dmem_props (
    input logic        clk, we,
    input logic [3:0]  addr,
    input logic [15:0] wdata
);
    logic [15:0] rdata;

    dmem #(.AW(4), .DW(16)) dut (
        .clk(clk), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata)
    );

    // $past at depth 2 needs two cycles of history before it is valid.
    logic v1 = 1'b0, v2 = 1'b0;
    always_ff @(posedge clk) begin v1 <= 1'b1; v2 <= v1; end

    always_ff @(posedge clk) if (v2) begin
        // Wrote W to address A two cycles ago, read A one cycle ago, and did NOT
        // overwrite A one cycle ago -> the registered read delivers W now.
        if ($past(we, 2) && $past(addr, 1) == $past(addr, 2)
            && !($past(we, 1) && $past(addr, 1) == $past(addr, 2)))
            assert (rdata == $past(wdata, 2));
    end
endmodule
