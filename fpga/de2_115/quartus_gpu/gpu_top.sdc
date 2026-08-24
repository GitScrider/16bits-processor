# vga_top.sdc -- basic timing constraints for the VGA demo on the DE2-115.
#  The 50 MHz board clock is the only real clock; the 25 MHz pixel clock and the
#  ~3 kHz CPU clock are derived from it by simple counter division.

create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty

# The derived pixel/CPU clocks come off counter bits; let Quartus infer them.
derive_pll_clocks
