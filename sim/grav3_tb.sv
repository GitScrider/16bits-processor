// =============================================================================
//  grav3_tb.sv  --  verify three gravity balls drawn into the tile grid
// -----------------------------------------------------------------------------
//  Runs cpu.sv with PROGRAM="grav3" and watches the colour "draw" stores. Each
//  colour maps to a ball in a known column: 1->col3, 2->col9, 3->col15. From a
//  draw's address (row*20 + col) we recover the row and check each ball: it stays
//  on the grid (row 0..14) and it bounces (falls then comes back up).
//
//  Run:  vlog -sv rtl/sequencer.sv rtl/pc.sv rtl/imem.sv rtl/control.sv \
//               rtl/regfile.sv rtl/alu.sv rtl/dmem.sv rtl/cpu.sv sim/grav3_tb.sv
//        vsim -c -do "run -all; quit -f" grav3_tb
// =============================================================================
`timescale 1ns/1ps
module grav3_tb;
    logic        clk = 1'b0, rst = 1'b1;
    logic [7:0]  pc_out;
    logic [15:0] instr;
    logic [4:0]  phase;
    logic [3:0]  wb_rd;
    logic        wb_we;
    logic [15:0] wb_val;
    logic        st_we;
    logic [15:0] st_addr, st_data;

    cpu #(.PROGRAM("grav3"), .PCW(8)) dut (
        .clk(clk), .rst(rst), .pc_out(pc_out), .instr(instr), .phase(phase),
        .wb_rd(wb_rd), .wb_we(wb_we), .wb_val(wb_val),
        .st_we(st_we), .st_addr(st_addr), .st_data(st_data)
    );

    always #5 clk = ~clk;

    // per-ball tracking, indexed by colour 1..3
    integer prev_row [1:4];
    integer max_row  [1:4];
    logic   saw_down [1:4];
    logic   saw_up   [1:4];
    integer draws = 0, errors = 0, i;

    function automatic integer colof(input integer color);
        colof = (color == 1) ? 3 : (color == 2) ? 9 : 15;
    endfunction

    initial for (i = 1; i <= 3; i = i + 1) begin
        prev_row[i] = -1; max_row[i] = 0; saw_down[i] = 0; saw_up[i] = 0;
    end

    always_ff @(posedge clk) begin
        if (!rst && st_we && st_data >= 16'd1 && st_data <= 16'd3) begin
            automatic integer c   = st_data;
            automatic integer row = (st_addr - colof(c)) / 20;
            draws = draws + 1;
            if (row < 0 || row > 14) begin
                $display("  ERROR ball %0d: row=%0d off-grid (addr=%0d)", c, row, st_addr);
                errors = errors + 1;
            end
            if (prev_row[c] >= 0) begin
                if (row > prev_row[c]) saw_down[c] = 1'b1;
                if (row < prev_row[c] && saw_down[c]) saw_up[c] = 1'b1;
            end
            if (row > max_row[c]) max_row[c] = row;
            prev_row[c] = row;
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (12000) @(posedge clk);

        for (i = 1; i <= 3; i = i + 1) begin
            if (max_row[i] < 10)                begin $display("  ERROR ball %0d: max row %0d", i, max_row[i]); errors = errors + 1; end
            if (!(saw_down[i] && saw_up[i]))    begin $display("  ERROR ball %0d: no bounce (d=%0b u=%0b)", i, saw_down[i], saw_up[i]); errors = errors + 1; end
        end
        $display("----------------------------------------------------------");
        if (errors == 0)
            $display("GRAV3 TB PASS: 3 balls, %0d draws, each fell & bounced on-grid (max rows %0d/%0d/%0d)",
                     draws, max_row[1], max_row[2], max_row[3]);
        else
            $display("GRAV3 TB FAIL: %0d error(s)", errors);
        $display("----------------------------------------------------------");
        $finish;
    end
endmodule
