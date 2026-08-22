// =============================================================================
//  control.sv  --  Control Unit / opcode decoder for the 16-bit RISC processor
// -----------------------------------------------------------------------------
//  Module 3 of the module-by-module FPGA bring-up.
//
//  Mirrors the Logisim "Unidade de Controle": it looks at the 4-bit OPCODE of
//  the current instruction and drives every control line the datapath needs.
//  Think of it as the conductor of the orchestra -- it plays no data itself, it
//  just tells each part (ALU, register file, memory, PC logic) what to do.
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: this module is PURELY COMBINATIONAL. There is no clock, no
//  memory, no state. The outputs are a direct function of the input `op` --
//  change `op` and the outputs settle to their new values after a tiny gate
//  delay. That is exactly what a decoder is: a "truth table cast into logic".
//
//  We express that truth table with ONE `always_comb` and a `case (op)`. Each
//  case arm is one row of the table. Because a decoder is nothing more than a
//  lookup, the `case` reads like the datasheet it implements.
//
//  WHY DEFAULT EVERY OUTPUT TO 0 FIRST?  In a combinational `always_comb`, if
//  some execution path leaves an output unassigned, the synthesizer must keep
//  its OLD value -- and "remember the old value" means it infers a LATCH. A
//  latch in what should be pure logic is a classic, hard-to-debug bug. By
//  assigning EVERY output a default (all zeros) at the very top of the block,
//  every output is guaranteed to get a value on every path, so no latch can be
//  inferred. Each `case` arm then only overrides the lines that must be 1.
//
//  ---------------------------------------------------------------------------
//  ULAOP note: the 3-bit `ulaop` field emitted here is the SAME encoding the
//  ALU (alu.sv) decodes -- 000 add, 001 sub, 010 mul, 011 div, 100 slt,
//  101 sub-for-beqz. Keeping the two files in sync is what makes the pieces
//  click together into a working CPU.
//
//  Compatibility: uses only sized literals (4'h1, 3'b000, 1'b0) -- no unsized
//  '0 / '1 and no type'() casts -- so it also compiles on ModelSim ASE 10.1d
//  (bundled with Quartus II 13.1).
// =============================================================================

module control (
    input  logic [3:0] op,        // 4-bit opcode of the current instruction
    output logic       jump,      // unconditional jump (j): load PC with target
    output logic       branch,    // conditional branch (beqz): take if ZERO set
    output logic       memwrite,  // write data memory (sw)
    output logic       memula,    // "mem-to-reg": write-back value comes from data memory (lw)
    output logic       aluadr,    // route ALU output to memory-address / branch path
    output logic [2:0] ulaop,     // ALU operation select (see ULAOP note above)
    output logic       regwrite,  // WriteBack: write the result into register RD
    output logic       alusrc     // ALU 2nd operand = immediate (1) or register (0)
);

    // ---- Opcode map ---------------------------------------------------------
    // Matches the Logisim UNIDADE DE CONTROLE decoder (recovered from the .circ
    // netlist). Note: 0x0 is addi, not a separate "ctrl" -- 0x0000 decodes to
    // "addi r0,r0,0", which is the natural no-op.
    localparam logic [3:0] OP_ADDI = 4'h0; // rd = rx + imm
    localparam logic [3:0] OP_SUBI = 4'h1; // rd = rx - imm
    localparam logic [3:0] OP_MULI = 4'h2; // rd = rx * imm
    localparam logic [3:0] OP_DIVI = 4'h3; // rd = rx / imm
    localparam logic [3:0] OP_ADD  = 4'h4; // rd = rx + ry
    localparam logic [3:0] OP_SUB  = 4'h5; // rd = rx - ry
    localparam logic [3:0] OP_MUL  = 4'h6; // rd = rx * ry
    localparam logic [3:0] OP_DIV  = 4'h7; // rd = rx / ry
    localparam logic [3:0] OP_SLT  = 4'h8; // rd = (rx < ry) ? 1 : 0
    localparam logic [3:0] OP_BEQZ = 4'h9; // branch if rx == 0
    localparam logic [3:0] OP_SW   = 4'hC; // mem[addr] = ry  (store word)
    localparam logic [3:0] OP_LW   = 4'hD; // rd = mem[addr]  (load word)
    localparam logic [3:0] OP_J    = 4'hE; // PC = target     (unconditional jump)
    // 0xA, 0xB and 0xF are RESERVED -> handled by the default arm (all outputs 0).

    // ALU operation codes (mirror rtl/alu.sv ULAOP encoding).
    localparam logic [2:0] ULA_ADD  = 3'b000;
    localparam logic [2:0] ULA_SUB  = 3'b001;
    localparam logic [2:0] ULA_MUL  = 3'b010;
    localparam logic [2:0] ULA_DIV  = 3'b011;
    localparam logic [2:0] ULA_SLT  = 3'b100;
    localparam logic [2:0] ULA_BEQZ = 3'b101; // subtract; ZERO flag drives beqz

    always_comb begin
        // ---- DEFAULTS: every output gets a value first (no latches) ----------
        jump     = 1'b0;
        branch   = 1'b0;
        memwrite = 1'b0;
        memula   = 1'b0;
        aluadr   = 1'b0;
        ulaop    = ULA_ADD; // 3'b000
        regwrite = 1'b0;
        alusrc   = 1'b0;

        // ---- Per-opcode overrides: one arm == one row of the truth table -----
        unique case (op)
            // Columns:            jump branch memwrite memula aluadr ulaop     regwrite alusrc

            // ---- Immediate ALU ops: alusrc=1 (2nd operand = immediate), write RD
            OP_ADDI : begin ulaop = ULA_ADD; regwrite = 1'b1; alusrc = 1'b1; end
            OP_SUBI : begin ulaop = ULA_SUB; regwrite = 1'b1; alusrc = 1'b1; end
            OP_MULI : begin ulaop = ULA_MUL; regwrite = 1'b1; alusrc = 1'b1; end
            OP_DIVI : begin ulaop = ULA_DIV; regwrite = 1'b1; alusrc = 1'b1; end

            // ---- Register ALU ops: alusrc=0 (2nd operand = register), write RD
            OP_ADD  : begin ulaop = ULA_ADD; regwrite = 1'b1; end
            OP_SUB  : begin ulaop = ULA_SUB; regwrite = 1'b1; end
            OP_MUL  : begin ulaop = ULA_MUL; regwrite = 1'b1; end
            OP_DIV  : begin ulaop = ULA_DIV; regwrite = 1'b1; end
            OP_SLT  : begin ulaop = ULA_SLT; regwrite = 1'b1; end

            // ---- Control flow / memory ------------------------------------------
            // beqz: subtract (via ULA_BEQZ) so ZERO can be tested; take branch and
            // steer the ALU result onto the address/branch path. No register write.
            OP_BEQZ : begin branch = 1'b1; aluadr = 1'b1; ulaop = ULA_BEQZ; end

            // sw: compute address in the ALU, drive it onto the address path, and
            // write data memory. No register write.
            OP_SW   : begin memwrite = 1'b1; aluadr = 1'b1; end

            // lw: compute address in the ALU, drive the address path, and write
            // back the value coming FROM data memory (memula=1) into RD.
            OP_LW   : begin memula = 1'b1; aluadr = 1'b1; regwrite = 1'b1; end

            // j: unconditional jump -- only the jump line is asserted.
            OP_J    : begin jump = 1'b1; end

            // 0xA, 0xB, 0xF and anything else: reserved -> keep all-zero defaults.
            default : begin
                // (defaults already zero)
            end
        endcase
    end

endmodule
