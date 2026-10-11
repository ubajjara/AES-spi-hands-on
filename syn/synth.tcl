# ============================================================
# Script de Síntese
# ============================================================

# Carregar configuração
source syn/.synopsys_dc.setup


# Ler RTL
analyze -format sverilog rtl/porta_and.sv


# Elaborar
elaborate porta_and

link

# Constraints

source syn/constraints.sdc

# Verificação do design


puts "\n=================================================="
puts "CHECK DESIGN"
puts "=================================================="

check_design

# Relatórios pré-síntese

redirect syn/reports/area_pre.rpt {
report_area -hierarchy
}

redirect syn/reports/timing_pre.rpt {
report_timing -max_paths 10
}

# Síntese

puts "\n=================================================="
puts "INICIANDO SÍNTESE"
puts "=================================================="

compile_ultra -no_autoungroup


# Relatórios pós-síntese

redirect syn/reports/area_pos.rpt {
report_area -hierarchy
}

redirect syn/reports/timing_relatorio.rpt {
report_timing -max_paths 10
}

redirect syn/reports/power.rpt {
report_power
}

redirect syn/reports/setup_violations.rpt {
report_constraint -all_violators
}

# ------------------------------------------------------------
# Exportar netlist
# ------------------------------------------------------------

write -format verilog -hierarchy -output syn/netlist/porta_and_syn.v

write -format ddc -hierarchy -output syn/netlist/porta_and_syn.ddc

# ------------------------------------------------------------
# Salvar sessão do DC
# ------------------------------------------------------------

write_file -format ddc -hierarchy -output syn/netlist/porta_and.ddc

puts "\n=================================================="
puts "SÍNTESE CONCLUÍDA"
puts "=================================================="
puts "Arquivos gerados:"
puts "  synth/area_pos.rpt"
puts "  synth/timing_relatorio.rpt"
puts "  synth/power.rpt"
puts "  synth/setup_violations.rpt"
puts "  synth/porta_and_syn.v"
puts "  synth/porta_and_syn.ddc"
puts "==================================================" 