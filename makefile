# ==========================================
# Diretórios
# ==========================================
RTL_DIR     = rtl
TB_DIR      = tb
SCRIPTS_DIR = syn
REPORTS_DIR = $(SCRIPTS_DIR)/reports
NETLIST_DIR = $(SCRIPTS_DIR)/netlist

# ==========================================
# Arquivos
# ==========================================
RTL_FILES = $(RTL_DIR)/*.sv
TB_FILES  = $(TB_DIR)/*.sv

# Top do testbench
TOP = tb_porta_and

# Pós-síntese (ajuste LIBRARY_FILE ao caminho real dos modelos Verilog do SAED32)
NETLIST_FILE    = $(NETLIST_DIR)/porta_and_syn.v
LIBRARY_FILE    = libs/saed32nm.v
SIMV_POST_SYNTH = simv_post

# ==========================================
# Parâmetros de cada ferramenta
# ==========================================
VLOGAN_PARAMS = -full64 \
                -sverilog \
                -timescale=1ns/1ps \
                -kdb \
                +lint=all

VCS_PARAMS = -full64 \
             -timescale=1ns/1ps \
             -debug_access+all \
             -kdb \
             +notimingchecks \
             +nospecify

# ==========================================
# 1. Verificação de sintaxe
# ==========================================
syntax:
	vlogan $(VLOGAN_PARAMS) $(RTL_FILES) $(TB_FILES)

# ==========================================
# 2. Compilação / Elaboração
# ==========================================
compile: syntax
	vcs $(VCS_PARAMS) $(TOP)

# ==========================================
# 3. Rodar simulação
# ==========================================
run: compile
	./simv

# ==========================================
# 4. Abrir waveform no Verdi
# ==========================================
wave:
	verdi -ssf waves.fsdb &

# ==========================================
# 5. Síntese
# ==========================================
synth:
	mkdir -p $(REPORTS_DIR) $(NETLIST_DIR)
	dc_shell -f $(SCRIPTS_DIR)/synth.tcl | tee $(REPORTS_DIR)/synth.log

# ==========================================
# 6. Simulação pós-síntese
# ==========================================
sim_netlist: clean_sim synth
	vlogan $(VLOGAN_PARAMS) $(LIBRARY_FILE) $(NETLIST_FILE) $(TB_FILES)
	vcs $(VCS_PARAMS) $(TOP) -o $(SIMV_POST_SYNTH)
	./$(SIMV_POST_SYNTH)

# ==========================================
# Limpeza da síntese
# ==========================================
clean_synth:
	rm -rf ./alib-* ./default.svf ./command.log ./work_dc \
		$(REPORTS_DIR)/* $(NETLIST_DIR)/*

# ==========================================
# Limpeza da simulação
# ==========================================
clean_sim:
	rm -rf \
		csrc \
		simv* \
		*.daidir \
		novas* \
		AN.DB \
		ucli.key \
		verdi* \
		DVEfiles \
		.vlogan* \
		*.fsdb \
		*.log \
		vfastLog \
		work

# ==========================================
# Limpeza total
# ==========================================
clean: clean_sim clean_synth

.PHONY: syntax compile run wave synth sim_netlist clean clean_sim clean_synth