// =============================================================================
//  regfile.sv  --  16 x 16-bit register file ("Banco de Registradores")
// -----------------------------------------------------------------------------
//  Module 2 of the module-by-module FPGA bring-up.
//
//  Mirrors the Logisim "Banco de Registradores": 16 registers of 16 bits, one
//  write port (selected by RD) and two read ports (selected by RX and RY).
//
//  ---------------------------------------------------------------------------
//  MINI-LESSON: this module deliberately shows BOTH kinds of logic side by side.
//
//   * READING is COMBINATIONAL. Given a register number, the output is just the
//     stored value — no clock involved. That is why the two read ports below are
//     plain `assign` statements: the output follows the selector immediately.
//
//   * WRITING is SEQUENTIAL (clocked). A new value is only stored on the rising
//     edge of the clock, and it stays remembered afterwards. That is what the
//     `always_ff @(posedge clk)` block does. Inside a clocked block we use the
//     non-blocking assignment `<=` (all right-hand sides are sampled, then the
//     registers update together at the edge) — never `=`.
//
//   The rule of thumb: "does this need to REMEMBER something between clock
//   edges?" Reading → no → combinational. Writing → yes → sequential.
//
//  RESET: this uses a SYNCHRONOUS reset — `rst` is tested *inside* the clocked
//  block, so it only takes effect on a clock edge. The asynchronous alternative
//  would put it in the sensitivity list: `always_ff @(posedge clk or posedge rst)`.
//  Synchronous reset is the safe default on FPGAs; asynchronous reset is mainly
//  used for a power-on reset that must act without waiting for a clock.
//
//  NOTE: unlike MIPS (where r0 is hardwired to 0), every one of the 16 registers
//  here is a normal read/write register, matching the Logisim design.
//
//  Compatibility: uses sized literals ({WIDTH{1'b0}}) instead of '0 so it also
//  compiles on ModelSim ASE 10.1d (bundled with Quartus II 13.1).
// =============================================================================

module regfile #(
    parameter int WIDTH = 16,   // bits per register
    parameter int NREG  = 16,   // number of registers
    parameter int SEL   = 4     // selector width (must address NREG: 2**SEL >= NREG)
) (
    input  logic             clk,      // write-back clock (ClockWB in the schematic)
    input  logic             rst,      // synchronous reset: clears all registers
    input  logic             we,       // write enable (RegWrite / WriteBack)
    input  logic [SEL-1:0]   rd,       // write-select  (destination register)
    input  logic [WIDTH-1:0] wdata,    // data to write back ("Dado para reg destino")
    input  logic [SEL-1:0]   rx,       // read-select A
    input  logic [SEL-1:0]   ry,       // read-select B
    output logic [WIDTH-1:0] rx_data,  // value of register[rx]
    output logic [WIDTH-1:0] ry_data   // value of register[ry]
);

    // The storage: NREG registers of WIDTH bits each (an unpacked array).
    logic [WIDTH-1:0] regs [0:NREG-1];

    // ---- SEQUENTIAL: write happens only on the clock edge -------------------
    integer i;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NREG; i = i + 1)
                regs[i] <= {WIDTH{1'b0}};
        end else if (we) begin
            regs[rd] <= wdata;            // store wdata into the RD-selected register
        end
    end

    // ---- COMBINATIONAL: reads follow the selectors immediately --------------
    assign rx_data = regs[rx];
    assign ry_data = regs[ry];

endmodule
