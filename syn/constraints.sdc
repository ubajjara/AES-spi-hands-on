# ============================================================
# Arquivo de Restrições (SDC) - porta AND (combinacional)
# ============================================================

# Clock virtual: 10 ns -> 100 MHz (não há porta clk no design)
create_clock -name clk -period 10

# Incerteza do clock
set_clock_uncertainty 0.1 [get_clocks clk]

# Delays de I/O relativos ao clock virtual
set_input_delay 2 -clock clk [all_inputs]
set_output_delay 3 -clock clk [all_outputs]

# Driver das entradas
set_driving_cell -lib_cell INVX2_RVT -pin Y [all_inputs]

# Carga de 10 fF em todas as saídas
set_load 0.010 [all_outputs]
