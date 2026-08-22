# Timing constraints for the DE2-115 hello-world.
# The only clock is the 50 MHz board oscillator on CLOCK_50 (period = 20 ns).
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# The switches / buttons / LEDs / 7-seg are asynchronous to the eye; no I/O
# timing needs to be met for this smoke test. Tell TimeQuest not to worry.
set_false_path -from [get_ports {SW[*] KEY[*]}] -to [all_registers]
set_false_path -from * -to [get_ports {LEDR[*] LEDG[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] HEX6[*] HEX7[*]}]
