// =============================================================================
//  dmem.sv  --  data memory (L1-D) for the 16-bit RISC processor
// -----------------------------------------------------------------------------
//  Module 3 of the module-by-module FPGA bring-up.
//
//  This is the memory that the load/store instructions talk to:
//    * lw  (load  word)  -> READ  a word from mem[addr]
//    * sw  (store word)  -> WRITE a word to  mem[addr]
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: RAM vs ROM, and the "registered read".
//
//   * A ROM (read-only memory, e.g. the instruction memory) is initialised once
//     and never written during operation -- you only ever read it. A RAM (this
//     module) can be both written and read while the processor runs.
//
//   * WRITING here is SEQUENTIAL (clocked): the new word is stored into the array
//     only on the rising edge of the clock, and only when `we` (write-enable) is
//     high. That is the `if (we) mem[addr] <= wdata;` line below.
//
//   * READING here is ALSO SEQUENTIAL -- and that is the important, slightly
//     surprising part. Instead of `assign rdata = mem[addr];` (which would be a
//     COMBINATIONAL read, like the register file's two read ports in regfile.sv),
//     we clock the read too: `rdata <= mem[addr];`. The address you present is
//     latched on the clock edge and the data appears ONE CLOCK LATER. This is a
//     "registered read" and it costs us a 1-cycle READ LATENCY.
//
//  ---------------------------------------------------------------------------
//  WHY pay that 1-cycle latency on purpose?  ->  BLOCK RAM.
//
//   Real FPGAs (our Cyclone IV E) contain dedicated on-chip memory blocks
//   ("M9K" block RAMs). Those hardware blocks have a REGISTERED output built into
//   them -- the read data is only available on the cycle after the address is
//   applied. So if we describe our memory with a registered read, the synthesis
//   tool can map the whole array straight onto one (or a few) of those efficient
//   block RAMs. If instead we asked for a combinational read of a large array,
//   the tool cannot use block RAM and is forced to build the memory out of
//   thousands of ordinary logic registers ("distributed RAM") -- huge and slow.
//   For a 2**16 x 16-bit memory that simply would not fit. Matching the block
//   RAM's timing (one registered read) is the price of using it, and it is a
//   price we happily pay.
//
//   Contrast with regfile.sv: the register file is TINY (16 words) and needs its
//   read result in the SAME cycle for the ALU, so it uses a combinational read
//   and maps to logic. Data memory is HUGE and can tolerate a pipeline bubble,
//   so it uses a registered read and maps to block RAM. Same idea (a memory),
//   opposite engineering trade-off.
//
//  ---------------------------------------------------------------------------
//  SAME-ADDRESS COLLISION: what if we read and write the same address on the
//  same edge?  Because both statements live in one clocked block and use the
//  non-blocking `<=`, the right-hand sides are sampled FIRST (using the OLD
//  contents of mem[addr]) and only then do the updates happen. So rdata captures
//  the value that was there BEFORE this cycle's write -- classic "read-before-
//  write" (a.k.a. read-old-data) behaviour. The testbench checks exactly this.
//
//  Compatibility: uses sized literals ({DW{1'b0}}) instead of unsized '0, and no
//  type'() casts, so it also compiles on ModelSim ASE 10.1d (bundled with
//  Quartus II 13.1).
// =============================================================================

module dmem #(
    parameter int AW = 16,           // address width -> 2**AW words of storage
    parameter int DW = 16            // data width    -> bits per word
) (
    input  logic          clk,       // memory clock
    input  logic          we,        // write-enable (1 = store wdata this edge)
    input  logic [AW-1:0] addr,      // word address (for both read and write)
    input  logic [DW-1:0] wdata,     // data to store on a write (sw)
    output logic [DW-1:0] rdata      // data read back (valid ONE clock after addr)
);

    // The storage: 2**AW words of DW bits each (an unpacked array).
    // (1<<AW) is "2 to the power AW". For AW=16 that is 65,536 words -- exactly
    // the kind of large array that MUST live in FPGA block RAM.
    logic [DW-1:0] mem [0:(1<<AW)-1];

    // ---- SEQUENTIAL: one clocked block does BOTH the write and the read ------
    // Keeping the write and the registered read together in a single
    // always_ff @(posedge clk) is the canonical pattern that synthesis tools
    // recognise as "this is a block RAM".
    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;      // WRITE: store wdata (only when we is high)

        rdata <= mem[addr];          // READ : latch mem[addr] -> valid next cycle
    end

endmodule
