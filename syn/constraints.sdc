# ============================================================
# Arquivo de Restrições (SDC) - Vending Machine
# ============================================================

# 10 ns -> 100 MHz
create_clock -name clk -period 10 [get_ports clk]

# Incerteza do clock
set_clock_uncertainty 0.1 [get_clocks clk]

# Tempo de subida/descida do clock
set_clock_transition 0.1 [get_clocks clk]


set_input_delay 2 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 3 -clock clk [all_outputs]


# Definir o driver das entradas
set_driving_cell -lib_cell INVX2_RVT -pin ZN [remove_from_collection [all_inputs] [get_ports clk]]

# Aplica uma carga de 10 fF em todas as saídas
set_load 0.010 [all_outputs]
