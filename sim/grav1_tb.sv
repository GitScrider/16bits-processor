// =============================================================================
//  grav1_tb.sv  --  verify one gravity ball drawn into the tile grid
// -----------------------------------------------------------------------------
//  Runs cpu.sv with PROGRAM="grav1" and watches the "draw" stores (colour writes,
//  st_data == 1). Each draw's address is row*40 + col (col = 20), so we recover the
//  cell row and check the ball: (1) always stays on the FINE grid (row 0..29),
//  (2) actually bounces -- its row climbs (falls) then decreases (comes back up), and
//  (3) is FLICKER-FREE: a little framebuffer model applies every store and asserts
//  the erase never clears the cell the ball was just drawn into (draw-then-erase +
//  skip-if-unmoved should guarantee the ball is never momentarily blank).
//
//  Run:  vlog -sv rtl/sequencer.sv rtl/pc.sv rtl/imem.sv rtl/control.sv \
//               rtl/regfile.sv rtl/alu.sv rtl/dmem.sv rtl/cpu.sv sim/grav1_tb.sv
//        vsim -c -do "run -all; quit -f" grav1_tb
// =============================================================================
`timescale 1ns/1ps
module grav1_tb;
    logic        clk = 1'b0, rst = 1'b1;
    logic [7:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;

    cpu #(.PROGRAM("grav1"), .PCW(8)) dut (
        .clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    always #5 clk = ~clk;

    integer errors = 0, draws = 0, flick = 0;
    integer prev_row = -1, max_row = 0, min_after_max = 99;
    logic   saw_down = 1'b0, saw_up = 1'b0;

    // ---- energy-loss (decay) + reset-loop tracking -------------------------
    // apex_min = highest point (smallest row) reached since the last floor touch.
    // On each floor touch (row==28) the completed bounce's apex is recorded; energy
    // loss shows up as later apexes being LOWER (larger row) than earlier ones.
    integer apex_min = 99, apex_hi = 99, apex_lo = -1, floor_touches = 0, resets = 0;

    // ---- framebuffer model: apply every store, watch the live ball cell ----
    // AW=11 grid + off-screen scratch (1600) -> size for the full 0..2047 range.
    logic [7:0] fb [0:2047];
    integer     ball_cell = -1;   // cell the ball currently occupies (last draw)
    integer     k;
    initial for (k = 0; k < 2048; k = k + 1) fb[k] = 8'h00;

    always_ff @(posedge clk) begin
        if (!rst && st_we) begin
            fb[st_addr[10:0]] = st_data[7:0];        // apply the store to the model
            if (st_data == 16'd1) begin              // a DRAW (colour) store
                automatic integer row = (st_addr - 20) / 40;  // addr = row*40 + 20
                draws = draws + 1;
                ball_cell = st_addr;                 // the ball now lives here
                if (row < 0 || row > 29) begin
                    $display("  ERROR draw #%0d: row=%0d off-grid (addr=%0d)", draws, row, st_addr);
                    errors = errors + 1;
                end
                if (prev_row >= 0) begin
                    if (row > prev_row) saw_down = 1'b1;             // falling
                    if (row < prev_row && saw_down) saw_up = 1'b1;  // bounced back up
                end
                if (row > max_row) max_row = row;
                // decay + reset tracking
                if (row < apex_min) apex_min = row;
                if (row == 28) begin                     // a floor touch
                    floor_touches = floor_touches + 1;
                    if (floor_touches > 1) begin         // skip the initial drop
                        if (apex_min < apex_hi) apex_hi = apex_min;  // best (highest) bounce
                        if (apex_min > apex_lo) apex_lo = apex_min;  // worst (lowest) bounce
                    end
                    apex_min = 99;                       // start accumulating next bounce
                end
                if (row == 0 && draws > 20) resets = resets + 1;     // re-drop from the top
                prev_row = row;
            end else begin                           // an ERASE (0) store
                // flicker-free invariant: the erase must NOT clear the live ball cell
                if (ball_cell >= 0 && fb[ball_cell[10:0]] != 8'd1) begin
                    if (flick < 5)
                        $display("  ERROR flicker: erase cleared live ball cell %0d (draw #%0d)", ball_cell, draws);
                    flick = flick + 1;
                    errors = errors + 1;
                end
            end
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (200000) @(posedge clk);  // >2 full decay cycles (each ~480 frames) -> sees resets + drift

        if (draws < 20)          begin $display("  ERROR: only %0d draws", draws); errors = errors + 1; end
        if (max_row < 25)        begin $display("  ERROR: ball only reached row %0d (expected 28)", max_row); errors = errors + 1; end
        if (!(saw_down && saw_up)) begin $display("  ERROR: no bounce seen (down=%0b up=%0b)", saw_down, saw_up); errors = errors + 1; end
        // energy loss: some bounce must peak higher than another (apex rows differ)
        if (!(apex_lo > apex_hi))  begin $display("  ERROR: no energy decay (apex range %0d..%0d)", apex_hi, apex_lo); errors = errors + 1; end
        // loop: the ball must re-drop from the top at least once (E hit 0 -> reset)
        if (resets < 1)            begin $display("  ERROR: never reset/looped (resets=%0d)", resets); errors = errors + 1; end

        $display("----------------------------------------------------------");
        if (errors == 0)
            $display("GRAV1 TB PASS: %0d draws, decaying bounce apex rows %0d..%0d, %0d resets, on-grid (max row %0d), 0 flicker",
                     draws, apex_hi, apex_lo, resets, max_row);
        else
            $display("GRAV1 TB FAIL: %0d error(s) (%0d flicker)", errors, flick);
        $display("----------------------------------------------------------");
        $finish;
    end
endmodule
