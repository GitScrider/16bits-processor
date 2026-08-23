// =============================================================================
//  cpu.sv  --  the integrated 16-bit multicycle RISC processor
// -----------------------------------------------------------------------------
//  The payoff of the module-by-module bring-up: every block wired together into
//  one working CPU, driven by the 5-phase ring sequencer, running the original
//  Logisim demo program (logisim/programs/loop.mem, baked into imem.sv).
//
//  ---------------------------------------------------------------------------
//  ENCODING NOTE. This top level decodes the ORIGINAL Logisim opcode map (the
//  numbering the historical loop.mem was written for), which differs from the
//  reconstructed ISA in docs/ (used by the standalone control.sv demo):
//
//     instruction word = [ OP(15:12) | RD(11:8) | RX(7:4) | RY/I(3:0) ]   (OP = MSN)
//
//     OP 0x0  addi   reg[RD] = reg[RX] + zext(I)
//     OP 0x8  slt    reg[RD] = (reg[RX] < reg[RY]) ? 1 : 0     (signed)
//     OP 0x9  beqz   if (reg[RX] == 0) PC = I(target)  else PC+1
//     OP 0xE  j      PC = I(target)
//     (0x1..0x7, 0xA..0xD, 0xF are not used by loop.mem and decode as no-ops here)
//
//  0x0000 is therefore "addi r0,r0,0" -- a natural no-op (adds 0 to r0).
//
//  ---------------------------------------------------------------------------
//  MULTICYCLE TIMING. One instruction takes five machine clocks; the one-hot
//  sequencer marches phase 1..5 and back. Each phase does its slice of work:
//     phase[0] P1  PC        present the program counter to instruction memory
//     phase[1] P2  Fetch/Dec read the instruction; decode; read RX, RY
//     phase[2] P3  Execute   ALU computes; latch the result and the ZERO flag
//     phase[3] P4  Memory    data-memory access (idle for this program)
//     phase[4] P5  Writeback write reg[RD]; update the PC (+1, or branch/jump)
//  State (PC, registers, ALU-out latch) only changes on the edge of the phase
//  that owns it, so the whole thing is one clean synchronous machine.
//
//  Compatibility: sized literals only (no '0/'1, no type'() casts) -> compiles
//  on ModelSim ASE 10.1d (bundled with Quartus II 13.1).
// =============================================================================

module cpu #(
    parameter     PROGRAM = "",     // imem program; "" = loop.mem, "vga" = moving square
    parameter int DMEM_AW = 16      // data-memory address width (2**DMEM_AW words)
) (
    input  logic        clk,
    input  logic        rst,        // synchronous reset: PC=0, regs=0, phase=P1
    output logic [3:0]  pc_out,     // current instruction address
    output logic [15:0] instr,      // current instruction word
    output logic [4:0]  phase,      // one-hot machine phase (for observation)
    // --- debug taps (for the board demo; leave unconnected in simulation) ----
    output logic [3:0]  wb_rd,      // destination register of the current instruction
    output logic        wb_we,      // write-back strobe (high in P5 when a register is written)
    output logic [15:0] wb_val,     // value written back this instruction
    // --- memory-mapped store taps (a sw makes these live; drives the VGA reg) --
    output logic        st_we,      // store strobe: sw commits in P4
    output logic [15:0] st_addr,    // store address = reg[RX]
    output logic [15:0] st_data     // store data    = reg[RY]
);
    // ---- 5-phase ring sequencer --------------------------------------------
    sequencer u_seq (.clk(clk), .rst(rst), .phase(phase));

    // ---- Program counter ----------------------------------------------------
    // Updates only in the write-back phase (P5): load a branch/jump target when
    // taken, otherwise advance by +1. (load beats en inside pc.sv.)
    logic       take;               // branch-taken or jump
    logic [3:0] target;
    logic       pc_en, pc_load;
    assign pc_en   = phase[4];       // advance/commit happens in P5
    assign pc_load = phase[4] & take;
    pc #(.W(4)) u_pc (
        .clk(clk), .rst(rst),
        .en(pc_en), .load(pc_load), .target(target),
        .pc_out(pc_out)
    );

    // ---- Instruction memory (holds loop.mem) -------------------------------
    imem #(.AW(4), .DW(16), .PROGRAM(PROGRAM)) u_imem (.addr(pc_out), .instr(instr));

    // ---- Decode: the control unit turns the opcode into control lines -------
    logic [3:0] op, rd, rx, ryimm;
    assign op    = instr[15:12];
    assign rd    = instr[11:8];
    assign rx    = instr[7:4];
    assign ryimm = instr[3:0];

    logic       jump, branch, memwrite, memula, aluadr, regwrite, alusrc;
    logic [2:0] ulaop;
    control u_ctrl (
        .op(op),
        .jump(jump), .branch(branch), .memwrite(memwrite), .memula(memula),
        .aluadr(aluadr), .ulaop(ulaop), .regwrite(regwrite), .alusrc(alusrc)
    );

    // ---- Register file ------------------------------------------------------
    logic [15:0] rx_data, ry_data, wb_data;
    logic        rf_we;
    assign rf_we = phase[4] & regwrite;      // write in P5
    regfile #(.WIDTH(16), .NREG(16), .SEL(4)) u_rf (
        .clk(clk), .rst(rst), .we(rf_we),
        .rd(rd), .wdata(wb_data),
        .rx(rx), .ry(ryimm),
        .rx_data(rx_data), .ry_data(ry_data)
    );

    // ---- ALU operands -------------------------------------------------------
    // operand A is always the first source register RX.
    // operand B: immediate for addi; ZERO for beqz (so it tests reg[RX]==0);
    //            the second source register RY otherwise.
    logic [15:0] imm_ext, alu_a, alu_b, alu_result;
    logic        alu_zero;
    assign imm_ext = {12'b0, ryimm};         // zero-extended 4-bit immediate
    assign alu_a   = rx_data;
    assign alu_b   = alusrc ? imm_ext
                            : (branch ? 16'h0000 : ry_data);
    alu #(.WIDTH(16)) u_alu (
        .a(alu_a), .b(alu_b), .ulaop(ulaop),
        .result(alu_result), .zero(alu_zero)
    );

    // ---- ALU output register (latched in Execute, P3) ----------------------
    logic [15:0] alu_out_reg;
    logic        zero_reg;
    always_ff @(posedge clk) begin
        if (rst) begin
            alu_out_reg <= 16'h0000;
            zero_reg    <= 1'b0;
        end else if (phase[2]) begin        // P3 = Execute
            alu_out_reg <= alu_result;
            zero_reg    <= alu_zero;
        end
    end

    // ---- Data memory: written by sw (P4), read for lw (valid P5) -----------
    // The address is reg[RX]; sw stores reg[RY]. (loop.mem uses no lw/sw, so the
    // synthesizer prunes this block, but the datapath is complete for any program.)
    logic [15:0] mem_rdata;
    dmem #(.AW(DMEM_AW), .DW(16)) u_dmem (
        .clk(clk), .we(memwrite & phase[3]),
        .addr(rx_data[DMEM_AW-1:0]), .wdata(ry_data),
        .rdata(mem_rdata)
    );

    // ---- Write-back datum + next-PC selection ------------------------------
    assign wb_data = memula ? mem_rdata : alu_out_reg;  // lw -> memory read, else ALU
    assign take    = jump | (branch & zero_reg);
    assign target  = ryimm;                  // 4-bit branch/jump target

    // --- debug taps -------------------------------------------------------
    assign wb_rd  = rd;
    assign wb_we  = rf_we;
    assign wb_val = wb_data;

    // --- memory-mapped store taps: mirror exactly what dmem sees on a sw ----
    assign st_we   = memwrite & phase[3];
    assign st_addr = rx_data;
    assign st_data = ry_data;

    // aluadr steers reg[RX] onto the address path; here the data-memory address
    // is already reg[RX], so it needs no extra logic -- tie it off cleanly.
    logic unused;
    assign unused = aluadr;
endmodule
