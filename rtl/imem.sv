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
    parameter int AW = 4,        // address width (PC bits). 2**AW = number of words
    parameter int DW = 16,       // data width: bits per instruction word
    parameter     PROGRAM = ""   // which built-in program: "" = loop.mem, "vga" = moving square
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

        if (PROGRAM == "vga") begin
            // VGA moving-square program: the CPU itself computes a bouncing X
            // position and stores it to the memory-mapped video address (1).
            // r1=x, r2=dx (step), r5=video address, r7=XMAX (right wall = 640-64),
            // r9=scratch. See fpga/de2_115/vga_top.sv and logisim/programs/vga_square.mem.
            mem[0]  = 16'h0204;  // addi r2, r0, 4   -> dx = 4 (step)
            mem[1]  = 16'h0501;  // addi r5, r0, 1   -> video address = 1
            mem[2]  = 16'h0709;  // addi r7, r0, 9   -> r7 = 9
            mem[3]  = 16'h2778;  // muli r7, r7, 8   -> r7 = 72
            mem[4]  = 16'h2778;  // muli r7, r7, 8   -> r7 = 576  (XMAX)
            mem[5]  = 16'h4112;  // add  r1, r1, r2  -> x += dx        (loop start)
            mem[6]  = 16'hC051;  // sw   r5, r1      -> mem[1] <- x
            mem[7]  = 16'h5917;  // sub  r9, r1, r7  -> r9 = x - XMAX
            mem[8]  = 16'h909B;  // beqz r9, 11      -> hit right wall? reverse
            mem[9]  = 16'h901B;  // beqz r1, 11      -> hit left wall (x==0)? reverse
            mem[10] = 16'hE005;  // j    5           -> else keep going
            mem[11] = 16'h5202;  // sub  r2, r0, r2  -> dx = -dx  (reverse)
            mem[12] = 16'hE005;  // j    5           -> loop
            // mem[13..15] stay 0x0000
        end else if (PROGRAM == "grav1") begin
            // One ball bouncing with gravity that LOSES ENERGY each bounce, drawn
            // into the FINE tile grid (40 cols x 30 rows, 16x16-px cells) for SMOOTH
            // motion. fine_y is in 1/8-cell units, so row = fine_y/8 (one divi).
            // FLOOR = 224 (= row 28). Ball is a single cell in column 20.
            //
            // DAMPED bounce via an ENERGY register E (starts at E_MAX=21): the ball
            // launches off the floor with vy = -E, and every floor hit does E -= 1,
            // so each bounce is lower than the last (first bounce ~row 1, then decays
            // toward the floor). When E reaches 0 the demo RESETS (E=E_MAX, fine_y=0,
            // vy=0) for a fresh drop from the top -> loops forever, always on-grid
            // (rows 0..28), never drifting. All conditionals are branchless 0/1 masks
            // (this ISA's beqz only reaches addr 0..15, and the loop lives higher up):
            //     hit    = 1 - slt(fine_y, FLOOR)          (1 on/under the floor)
            //     ezero  = slt(0, E)                        (1 while E>0)
            //     atzero = 1 - ezero                        (1 exactly when E==0)
            //     E += atzero*E_MAX ; fine_y *= ezero ; vy *= ezero   (the reset)
            //
            // FLICKER-FREE: DRAW the new cell first, then ERASE the old one; skip the
            // erase (redirect it to off-screen SCRATCH=1600=COLS*COLS) when row is
            // unchanged, so a dwelling ball never blinks.
            //   r1=COLS(40), r2=col(20), r3=FLOOR(224), r4=E_MAX(21),
            //   r5=G/one/colour(1), r6=fine_y, r7=vy, r8=prev_row, r9=E,
            //   r14=SCRATCH(1600); r10/r11/r12/r13/r15 = per-loop scratch.
            // The loop body is the (3x + ModelSim) verified damped renderer; only the
            // setup constants change for the finer grid.
            // ---- setup: build the (now larger) constants from 4-bit immediates ----
            mem[0]  = 16'h0108;  // addi r1, r0, 8
            mem[1]  = 16'h2115;  // muli r1, r1, 5    COLS = 8*5 = 40
            mem[2]  = 16'h0204;  // addi r2, r0, 4
            mem[3]  = 16'h2225;  // muli r2, r2, 5    col = 4*5 = 20 (middle column)
            mem[4]  = 16'h0304;  // addi r3, r0, 4
            mem[5]  = 16'h2337;  // muli r3, r3, 7    r3 = 28 (floorRow)
            mem[6]  = 16'h2338;  // muli r3, r3, 8    FLOOR = 28*8 = 224 (row 28)
            mem[7]  = 16'h0407;  // addi r4, r0, 7
            mem[8]  = 16'h2443;  // muli r4, r4, 3    E_MAX = 7*3 = 21
            mem[9]  = 16'h0501;  // addi r5, r0, 1    1 : gravity G / one / colour
            mem[10] = 16'h0600;  // addi r6, r0, 0    fine_y = 0 (start at top)
            mem[11] = 16'h0700;  // addi r7, r0, 0    vy = 0
            mem[12] = 16'h0800;  // addi r8, r0, 0    prev_row = 0
            mem[13] = 16'h4940;  // add  r9, r4, r0   E = E_MAX = 21
            mem[14] = 16'h6E11;  // mul  r14,r1, r1   SCRATCH = COLS*COLS = 1600 (off-screen)
            // ---- frame loop (addr 15) ----
            mem[15] = 16'h4775;  // add  r7, r7, r5   vy += G (gravity before move)
            mem[16] = 16'h4667;  // add  r6, r6, r7   fine_y += vy
            mem[17] = 16'h8A63;  // slt  r10, r6, r3  below = (fine_y < FLOOR)
            mem[18] = 16'h5B5A;  // sub  r11, r5, r10 hit  = 1 - below
            mem[19] = 16'h5C63;  // sub  r12, r6, r3  t = fine_y - FLOOR
            mem[20] = 16'h6CBC;  // mul  r12, r11,r12 t = hit*(fine_y-FLOOR)
            mem[21] = 16'h566C;  // sub  r6, r6, r12  fine_y = FLOOR if hit (clamp)
            mem[22] = 16'h4C79;  // add  r12, r7, r9  t = vy + E
            mem[23] = 16'h6CBC;  // mul  r12, r11,r12 t = hit*(vy+E)
            mem[24] = 16'h577C;  // sub  r7, r7, r12  vy = -E on hit (launch w/ energy)
            mem[25] = 16'h599B;  // sub  r9, r9, r11  E -= hit (lose energy per bounce)
            mem[26] = 16'h8C09;  // slt  r12, r0, r9  ezero = (0 < E)  (1 while E>0)
            mem[27] = 16'h5D5C;  // sub  r13, r5, r12 atzero = 1 - ezero (1 iff E==0)
            mem[28] = 16'h6FD4;  // mul  r15, r13,r4  t = atzero*E_MAX
            mem[29] = 16'h499F;  // add  r9, r9, r15  E = E_MAX again when it hit 0
            mem[30] = 16'h666C;  // mul  r6, r6, r12  fine_y = 0 (re-drop) when E==0
            mem[31] = 16'h677C;  // mul  r7, r7, r12  vy = 0 when E==0
            mem[32] = 16'h3C68;  // divi r12, r6, 8   row = fine_y / 8  (r12 = row now)
            mem[33] = 16'h6AC1;  // mul  r10, r12,r1  r10 = row*COLS
            mem[34] = 16'h4AA2;  // add  r10, r10,r2  newAddr = row*COLS + col
            mem[35] = 16'h6B81;  // mul  r11, r8, r1  r11 = prev_row*COLS
            mem[36] = 16'h4BB2;  // add  r11, r11,r2  oldAddr = prev_row*COLS + col
            // ---- decide the erase target (branchless skip-if-unmoved) ----
            mem[37] = 16'h8DC8;  // slt  r13, r12,r8  a = (row < prev_row)
            mem[38] = 16'h8F8C;  // slt  r15, r8, r12 b = (prev_row < row)
            mem[39] = 16'h4DDF;  // add  r13, r13,r15 changed = a + b  (0 or 1)
            mem[40] = 16'h5FBE;  // sub  r15, r11,r14 d = oldAddr - SCRATCH
            mem[41] = 16'h6FDF;  // mul  r15, r13,r15 d = changed * d
            mem[42] = 16'h4FEF;  // add  r15, r14,r15 eraseTarget = SCRATCH + d
            // ---- draw THEN erase, back to back (no absent-ball window) ----
            mem[43] = 16'hC0A5;  // sw   r10, r5      DRAW new = colour (ball lit)
            mem[44] = 16'hC0F0;  // sw   r15, r0      ERASE eraseTarget (old, or scratch)
            mem[45] = 16'h48C0;  // add  r8, r12,r0   prev_row = row
            mem[46] = 16'hE00F;  // j    15           next frame
        end else if (PROGRAM == "grav3") begin
            // THREE balls falling with gravity, drawn into the tile grid.
            //   Ball A: fy=r1, vy=r2, prow=r3, col 3,  colour 1 (red)
            //   Ball B: fy=r4, vy=r5, prow=r6, col 9,  colour 2 (green)
            //   Ball C: fy=r7, vy=r8, prow=r9, col 15, colour 3 (blue)
            //   r10=G, r11=FLOOR(104), r12=one, r13=COLS(20), r14/r15=scratch.
            // fy is in 1/8-cell units (row = fy/8). Balls start at staggered
            // heights so they bounce out of phase.
            // ---- setup ----
            mem[0]  = 16'h0A01;  // addi r10,r0,1   G = 1
            mem[1]  = 16'h0C01;  // addi r12,r0,1   one = 1
            mem[2]  = 16'h0B08;  // addi r11,r0,8
            mem[3]  = 16'h2BBD;  // muli r11,r11,13 FLOOR = 104
            mem[4]  = 16'h0D04;  // addi r13,r0,4
            mem[5]  = 16'h2DD5;  // muli r13,r13,5  COLS = 20
            mem[6]  = 16'h0408;  // addi r4,r0,8
            mem[7]  = 16'h2445;  // muli r4,r4,5    fy_b = 40 (row 5)
            mem[8]  = 16'h0708;  // addi r7,r0,8
            mem[9]  = 16'h2779;  // muli r7,r7,9    fy_c = 72 (row 9)
            // ---- frame loop (addr 10) ----
            // Ball A (col 3, colour 1)
            mem[10] = 16'h6E3D;  // mul  r14,r3,r13  old = prow_a*COLS
            mem[11] = 16'h0EE3;  // addi r14,r14,3   + col
            mem[12] = 16'hC0E0;  // sw   r14,r0      erase
            mem[13] = 16'h422A;  // add  r2,r2,r10   vy += G
            mem[14] = 16'h4112;  // add  r1,r1,r2    fy += vy
            mem[15] = 16'h8F1B;  // slt  r15,r1,r11  below
            mem[16] = 16'h4FFF;  // add  r15,r15,r15 2*below
            mem[17] = 16'h5FFC;  // sub  r15,r15,r12 factor
            mem[18] = 16'h622F;  // mul  r2,r2,r15   bounce
            mem[19] = 16'h3F18;  // divi r15,r1,8    row
            mem[20] = 16'h03F0;  // addi r3,r15,0    prow_a = row
            mem[21] = 16'h6EFD;  // mul  r14,r15,r13 row*COLS
            mem[22] = 16'h0EE3;  // addi r14,r14,3   + col
            mem[23] = 16'h0F01;  // addi r15,r0,1    colour 1
            mem[24] = 16'hC0EF;  // sw   r14,r15     draw
            // Ball B (col 9, colour 2)
            mem[25] = 16'h6E6D;  // mul  r14,r6,r13
            mem[26] = 16'h0EE9;  // addi r14,r14,9
            mem[27] = 16'hC0E0;  // sw   r14,r0
            mem[28] = 16'h455A;  // add  r5,r5,r10
            mem[29] = 16'h4445;  // add  r4,r4,r5
            mem[30] = 16'h8F4B;  // slt  r15,r4,r11
            mem[31] = 16'h4FFF;  // add  r15,r15,r15
            mem[32] = 16'h5FFC;  // sub  r15,r15,r12
            mem[33] = 16'h655F;  // mul  r5,r5,r15
            mem[34] = 16'h3F48;  // divi r15,r4,8
            mem[35] = 16'h06F0;  // addi r6,r15,0
            mem[36] = 16'h6EFD;  // mul  r14,r15,r13
            mem[37] = 16'h0EE9;  // addi r14,r14,9
            mem[38] = 16'h0F02;  // addi r15,r0,2
            mem[39] = 16'hC0EF;  // sw   r14,r15
            // Ball C (col 15, colour 3)
            mem[40] = 16'h6E9D;  // mul  r14,r9,r13
            mem[41] = 16'h0EEF;  // addi r14,r14,15
            mem[42] = 16'hC0E0;  // sw   r14,r0
            mem[43] = 16'h488A;  // add  r8,r8,r10
            mem[44] = 16'h4778;  // add  r7,r7,r8
            mem[45] = 16'h8F7B;  // slt  r15,r7,r11
            mem[46] = 16'h4FFF;  // add  r15,r15,r15
            mem[47] = 16'h5FFC;  // sub  r15,r15,r12
            mem[48] = 16'h688F;  // mul  r8,r8,r15
            mem[49] = 16'h3F78;  // divi r15,r7,8
            mem[50] = 16'h09F0;  // addi r9,r15,0
            mem[51] = 16'h6EFD;  // mul  r14,r15,r13
            mem[52] = 16'h0EEF;  // addi r14,r14,15
            mem[53] = 16'h0F03;  // addi r15,r0,3
            mem[54] = 16'hC0EF;  // sw   r14,r15
            mem[55] = 16'hE00A;  // j    10          next frame
        end else if (PROGRAM == "onecell") begin
            // Simplest board test: draw ONE fixed cell and spin. No maths, no
            // movement. If a single steady cell appears, the CPU + tile-write
            // path works and the trouble is in the moving physics.
            mem[0] = 16'h0201;   // addi r2, r0, 1   -> colour = 1
            mem[1] = 16'h0107;   // addi r1, r0, 7   -> cell = 7 (col 7, row 0)
            mem[2] = 16'hC012;   // sw   r1, r2      -> mem[7] = colour
            mem[3] = 16'hE003;   // j    3           -> spin
        end else if (PROGRAM == "walk") begin
            // Second test: walk a cell across the grid (dynamic writes, but NO
            // multiply or divide). Erase previous, draw current, index++, wrap
            // via a compare. If this walks cleanly, dynamic CPU writes are fine
            // and the multiply/divide in the physics is the suspect.
            mem[0] = 16'h0201;   // addi r2, r0, 1   -> colour = 1
            mem[1] = 16'h0805;   // addi r8, r0, 5
            mem[2] = 16'h2884;   // muli r8, r8, 4   -> r8 = 20 (wrap limit: one row)
            // loop (addr 3)
            mem[3] = 16'hC030;   // sw   r3, r0      -> erase prev (mem[r3]=0)
            mem[4] = 16'hC012;   // sw   r1, r2      -> draw cur  (mem[r1]=colour)
            mem[5] = 16'h0310;   // addi r3, r1, 0   -> prev = cur
            mem[6] = 16'h0111;   // addi r1, r1, 1   -> cur++
            mem[7] = 16'h5918;   // sub  r9, r1, r8  -> r9 = cur - 20
            mem[8] = 16'h909B;   // beqz r9, 11      -> if cur==20, wrap
            mem[9] = 16'hE003;   // j    3           -> else loop
            mem[10]= 16'hE003;   // (pad) j 3
            mem[11]= 16'h0100;   // addi r1, r0, 0   -> cur = 0  (wrap)
            mem[12]= 16'hE003;   // j    3
        end else if (PROGRAM == "jrtest") begin
            // jr smoke test: jr over two "trap" instructions to a landing pad.
            // If jr works, r1 stays 0 and r2 becomes 7; if it fell through, r1=30.
            mem[0] = 16'h0504;   // addi r5, r0, 4   -> r5 = 4 (jr target)
            mem[1] = 16'hF050;   // jr   r5          -> PC = r5 = 4 (skips 2,3)
            mem[2] = 16'h011F;   // addi r1, r1, 15  -> TRAP (must not run)
            mem[3] = 16'h011F;   // addi r1, r1, 15  -> TRAP
            mem[4] = 16'h0207;   // addi r2, r0, 7   -> r2 = 7 (landing)
            mem[5] = 16'hE005;   // j    5           -> spin
        end else begin
            // the 7-word default demo program from the design brief (loop.mem)
            mem[0] = 16'h0000;
            mem[1] = 16'h0112;
            mem[2] = 16'h0221;
            mem[3] = 16'h8312;
            mem[4] = 16'h9032;
            mem[5] = 16'h0240;
            mem[6] = 16'he003;
            // mem[7] .. mem[15] stay 16'h0000 from the clear loop above.
        end
    end

    // ---- COMBINATIONAL (async) read: output follows the address immediately --
    assign instr = mem[addr];

endmodule
