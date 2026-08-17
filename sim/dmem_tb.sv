// =============================================================================
//  dmem_tb.sv  --  self-checking testbench for the data memory (L1-D)
// -----------------------------------------------------------------------------
//  Run (ModelSim ASE, bundled with Quartus):
//      vlib work
//      vlog -sv ../rtl/dmem.sv dmem_tb.sv
//      vsim -c -do "run -all; quit -f" dmem_tb
//
//  Or with Icarus Verilog:
//      iverilog -g2012 -o dmem_tb.vvp ../rtl/dmem.sv dmem_tb.sv && vvp dmem_tb.vvp
//
//  IMPORTANT SIM-SPEED NOTE: the real design uses AW=16 (65,536 words), but we
//  instantiate the DUT here with AW=8 (256 words). A tiny memory keeps the
//  simulation fast and the reference model small, while exercising exactly the
//  same RTL behaviour.
//
//  What we check:
//    * The 1-cycle REGISTERED-READ latency: data presented as an address is only
//      valid on the clock AFTER the address is applied.
//    * A written word reads back correctly (directed writes/reads).
//    * write-enable actually gates writes (we=0 must not change memory).
//    * SAME-ADDRESS collision returns read-before-write (old) data.
//    * A random write-all / random read-back sweep matches a reference model.
// =============================================================================

`timescale 1ns/1ps

module dmem_tb;

    // Small address width on purpose -> 256 words -> fast simulation.
    localparam int AW = 8;
    localparam int DW = 16;

    logic          clk = 1'b0;
    logic          we;
    logic [AW-1:0] addr;
    logic [DW-1:0] wdata;
    logic [DW-1:0] rdata;

    int errors = 0;
    int checks = 0;

    // Reference model: what each of the 256 locations should currently hold.
    // (Left as X until first written -- we only ever read locations we wrote.)
    logic [15:0] model [0:255];

    // Device under test
    dmem #(.AW(AW), .DW(DW)) dut (
        .clk   (clk),
        .we    (we),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata)
    );

    // free-running clock: 10 ns period
    always #5 clk = ~clk;

    // ---- WRITE one word, committing on the next rising edge -----------------
    task automatic wr(input [AW-1:0] a, input [DW-1:0] v);
        @(negedge clk);
        we = 1'b1; addr = a; wdata = v;
        @(posedge clk);          // mem[a] <= v commits here
        @(negedge clk); we = 1'b0;
        model[a] = v;
    endtask

    // ---- READ one word and check it, accounting for the 1-cycle latency -----
    // We present the address, wait for the rising edge that latches
    // rdata <= mem[addr], then (after a small delta) the read data is valid.
    task automatic rdchk(input [AW-1:0] a);
        @(negedge clk);
        we = 1'b0; addr = a;     // present the address
        @(posedge clk);          // rdata <= mem[addr] captured on THIS edge
        #1;                      // let the non-blocking update settle
        checks++;
        if (rdata !== model[a]) begin
            errors++;
            $display("  FAIL read: mem[%0d] = %h (expected %h)", a, rdata, model[a]);
        end
    endtask

    integer i, k;
    logic [AW-1:0] ra;

    initial begin
        $dumpfile("dmem_tb.vcd");
        $dumpvars(0, dmem_tb);

        $display("== Data memory (L1-D) self-checking testbench ==");

        we = 1'b0; addr = {AW{1'b0}}; wdata = {DW{1'b0}};

        // ---- Directed write then read-back (demonstrates 1-cycle latency) ----
        wr(8'd5, 16'hABCD);
        rdchk(8'd5);

        wr(8'd0,   16'h0001);
        wr(8'd255, 16'hFFFE);   // exercise both ends of the address range
        rdchk(8'd0);
        rdchk(8'd255);

        // ---- write-enable gating: with we=0, memory must NOT change ----------
        // Drive a bogus wdata at addr 5 but keep we low across an edge.
        @(negedge clk); we = 1'b0; addr = 8'd5; wdata = 16'h1111;
        @(posedge clk); @(negedge clk);
        rdchk(8'd5);            // still 0xABCD

        // ---- SAME-ADDRESS collision: read-before-write returns OLD data ------
        // addr 5 currently holds 0xABCD. On ONE edge we write 0x5555 AND read.
        // The registered read captures the OLD value (0xABCD), not the new one.
        @(negedge clk); we = 1'b1; addr = 8'd5; wdata = 16'h5555;
        @(posedge clk);        // mem[5] <= 0x5555 ; rdata <= old mem[5] (0xABCD)
        #1;
        checks++;
        if (rdata !== 16'hABCD) begin
            errors++;
            $display("  FAIL collision: rdata = %h (expected old value ABCD)", rdata);
        end
        model[5] = 16'h5555;   // the write DID take effect...
        @(negedge clk); we = 1'b0;
        rdchk(8'd5);           // ...so a fresh read now returns the new 0x5555

        // ---- Random write-all, then random read-back sweep -------------------
        for (i = 0; i < 256; i = i + 1) wr(i[AW-1:0], $random);
        for (k = 0; k < 500; k = k + 1) begin
            ra = $random;      // any address 0..255 is legal and has been written
            rdchk(ra);
        end

        // ---- Summary ---------------------------------------------------------
        $display("== %0d checks, %0d errors ==", checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        if (errors != 0) $fatal(1, "dmem testbench failed");
        $finish;
    end

endmodule
