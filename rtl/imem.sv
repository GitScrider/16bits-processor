// =============================================================================
//  imem.sv  --  16 x 16-bit instruction memory / ROM ("Memoria de Instrucoes")
// -----------------------------------------------------------------------------
//  Module 3 of the module-by-module FPGA bring-up.
//
//  This is the L1-I: the read-only store the processor fetches instructions from.
//  The Program Counter (PC) presents an address, and the memory hands back the
//  16-bit instruction word stored there. There is one address input and one data
//  output -- no clock, no write port.
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: memory is just an ARRAY, and this one is READ-ONLY + ASYNC.
//
//   * STORAGE is an UNPACKED ARRAY. `logic [DW-1:0] mem [0:(1<<AW)-1]` reads as
//     "(1<<AW) boxes, each DW bits wide". The [DW-1:0] before the name is the
//     PACKED part (the width of one word); the [0:...] after the name is the
//     UNPACKED part (how many words). Together they form a little grid of bits.
//
//   * ROM vs RAM. A RAM can be written at run time (see regfile.sv, which has a
//     clocked write port). A ROM only ever gets *read* during operation -- its
//     contents are fixed when the chip is built. This instruction memory is a
//     ROM: notice there is no `clk`, no `we`, and no write logic anywhere below.
//
//   * COMBINATIONAL (ASYNCHRONOUS) READ. Just like the two read ports of the
//     register file, the output here follows the address immediately -- there is
//     no clock edge to wait for. That is why the read is a single continuous
//     `assign` at the bottom. Change `addr`, and `instr` updates right away.
//
//   * INITIALIZING MEMORY IN SIMULATION. A ROM has to get its contents somehow.
//     Two common ways are shown below:
//       (a) INLINE, in an `initial` block -- we literally write each word. Good
//           for a tiny demo program you want to keep next to the RTL.
//       (b) FROM A FILE, with `$readmemh("program.hex", mem)` -- the assembler /
//           toolchain emits a hex file and the memory loads it. Better once the
//           program grows. The commented line further down shows the swap.
//     On a real FPGA this `initial` content is what Quartus bakes into the ROM's
//     initialization (an on-chip memory block pre-loaded at configuration time).
//
//  Compatibility: uses sized literals ({DW{1'b0}}, 16'hXXXX) instead of unsized
//  '0 / type'() casts, so it also compiles on ModelSim ASE 10.1d (bundled with
//  Quartus II 13.1).
//
//  NOTE: the demo program words below are 16 bits wide, so they assume DW == 16.
//  Their per-instruction meaning depends on the ISA field layout / endianness,
//  which is still to be confirmed -- so we make no claim here about what each
//  word decodes to. They are just the fixed bit patterns the design brief gives.
// =============================================================================

module imem #(
    parameter int AW = 4,   // address width (PC bits). 2**AW = number of words
    parameter int DW = 16   // data width: bits per instruction word
) (
    input  logic [AW-1:0] addr,   // address from the PC
    output logic [DW-1:0] instr   // instruction word stored at that address
);

    // The storage: (1<<AW) words of DW bits each (an unpacked array).
    // For the defaults AW=4, DW=16 this is 16 x 16-bit -> mem[0] .. mem[15].
    logic [DW-1:0] mem [0:(1<<AW)-1];

    // ---- Initialize the ROM contents (simulation / FPGA power-on load) -------
    // We first clear every word to zero, then lay down the demo program in the
    // first seven words. Clearing first means every address we do NOT set
    // explicitly reads as a well-defined 0x0000 instead of X.
    integer i;
    initial begin
        // start from an all-zero ROM
        for (i = 0; i < (1<<AW); i = i + 1)
            mem[i] = {DW{1'b0}};

        // the 7-word demo program from the design brief
        mem[0] = 16'h0000;
        mem[1] = 16'h0112;
        mem[2] = 16'h0221;
        mem[3] = 16'h8312;
        mem[4] = 16'h9032;
        mem[5] = 16'h0240;
        mem[6] = 16'he003;
        // mem[7] .. mem[15] stay 16'h0000 from the clear loop above.

        // ---- Alternative: load a program from an external hex file ----------
        // Instead of the inline words above, a real build would emit a hex file
        // from the assembler and load it here (one 16-bit word per line, hex):
        //     $readmemh("program.hex", mem);
        // Leaving both here would double-load; use one or the other.
    end

    // ---- COMBINATIONAL (async) read: output follows the address immediately --
    assign instr = mem[addr];

endmodule
