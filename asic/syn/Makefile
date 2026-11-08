# aperture/asic/syn : RTL -> Yosys -> OpenROAD -> KLayout GDSII  (sky130_fd_sc_hd)
#
#   make pdk        fetch the sky130hd platform files (LEF/lib/GDS/PDN/RC) into pdk/
#   make yosys      synthesis  -> build/<TOP>_netlist.v  + area report
#   make floorplan  openroad/floorplan.tcl   (1_floorplan.odb)
#   make place      openroad/place.tcl       (2_place.odb)
#   make cts        openroad/cts.tcl         (3_cts.odb)
#   make route      openroad/route.tcl       (4_route.odb)
#   make final      openroad/final.tcl       (reports, DEF, 5_final.odb)
#   make gds        klayout stream-out       (build/<TOP>.gds)
#   make all        yosys + every stage + gds
#
# Variables: TOP CLK_PERIOD_NS CORE_UTILIZATION PLACE_DENSITY PDK_DIR FRONTEND (slang|sv2v)
#            YOSYS SV2V OPENROAD KLAYOUT
# OpenROAD/KLayout are Linux/macOS tools: run those stages from WSL2 on Windows.

TOP              ?= iris_core
CLK_PERIOD_NS    ?= 6.67
CORE_UTILIZATION ?= 40
PLACE_DENSITY    ?= 0.60
FRONTEND         ?= slang
YOSYS            ?= yosys
SV2V             ?= sv2v
OPENROAD         ?= openroad
KLAYOUT          ?= klayout
OUT              ?= build

PDK_REPO  = https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
PDK_CLONE = pdk/orfs
PDK_DIR  ?= $(PDK_CLONE)/flow/platforms/sky130hd
LIB      ?= $(PDK_DIR)/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

FILES     = $(shell grep -v '^\#' rtl.f)
RTL_DEPS  = rtl.f $(wildcard ../design/*/rtl/*.sv)
PERIOD_PS = $(shell awk 'BEGIN{printf "%d", $(CLK_PERIOD_NS)*1000}')

export TOP CLK_PERIOD_NS CORE_UTILIZATION PLACE_DENSITY PDK_DIR
export BUILD := $(OUT)

OR = $(OPENROAD) -exit -no_splash

.PHONY: all pdk yosys floorplan place cts route final gds clean
all: gds

# ---------------------------------------------------------------- PDK
pdk:
	@test -d $(PDK_CLONE)/.git || { mkdir -p pdk && \
	  git clone --depth 1 --filter=blob:none --sparse $(PDK_REPO) $(PDK_CLONE) && \
	  git -C $(PDK_CLONE) sparse-checkout set flow/platforms/sky130hd; }
	@test -f $(LIB) && echo "PDK ready: $(PDK_DIR)"

# ---------------------------------------------------------------- synthesis
$(OUT)/$(TOP)_sv2v.v: $(RTL_DEPS)
	mkdir -p $(OUT)
	$(SV2V) --top=$(TOP) --define=SYNTHESIS $(FILES) > $@

$(OUT)/read.ys: $(RTL_DEPS) Makefile
	mkdir -p $(OUT)
ifeq ($(FRONTEND),sv2v)
	$(MAKE) $(OUT)/$(TOP)_sv2v.v
	echo "read_verilog -sv $(OUT)/$(TOP)_sv2v.v" > $@
else
	echo "plugin -i slang" > $@
	echo "read_slang --top $(TOP) -D SYNTHESIS $(FILES)" >> $@
endif

yosys $(OUT)/$(TOP)_netlist.v: $(OUT)/read.ys
	@test -f "$(LIB)" || { echo "liberty not found: $(LIB) (run 'make pdk' or set LIB=)"; exit 1; }
	sed -e 's|__LIB__|$(LIB)|g' -e 's|__TOP__|$(TOP)|g' \
	    -e 's|__PERIOD_PS__|$(PERIOD_PS)|g' -e 's|__OUT__|$(OUT)|g' yosys/synth.ys > $(OUT)/run_$(TOP).ys
	$(YOSYS) -l $(OUT)/$(TOP)_synth.log -s $(OUT)/run_$(TOP).ys
	@echo "--- $(OUT)/$(TOP)_stat.rpt ---"; tail -n 25 $(OUT)/$(TOP)_stat.rpt

# ---------------------------------------------------------------- place & route
$(OUT)/1_floorplan.odb: $(OUT)/$(TOP)_netlist.v openroad/floorplan.tcl openroad/common.tcl openroad/constraints.sdc
	mkdir -p $(OUT)/logs
	$(OR) -log $(OUT)/logs/floorplan.log openroad/floorplan.tcl
$(OUT)/2_place.odb: $(OUT)/1_floorplan.odb openroad/place.tcl
	$(OR) -log $(OUT)/logs/place.log openroad/place.tcl
$(OUT)/3_cts.odb: $(OUT)/2_place.odb openroad/cts.tcl
	$(OR) -log $(OUT)/logs/cts.log openroad/cts.tcl
$(OUT)/4_route.odb: $(OUT)/3_cts.odb openroad/route.tcl
	$(OR) -log $(OUT)/logs/route.log openroad/route.tcl
$(OUT)/5_final.odb: $(OUT)/4_route.odb openroad/final.tcl
	$(OR) -log $(OUT)/logs/final.log openroad/final.tcl

floorplan: $(OUT)/1_floorplan.odb
place:     $(OUT)/2_place.odb
cts:       $(OUT)/3_cts.odb
route:     $(OUT)/4_route.odb
final:     $(OUT)/5_final.odb

# ---------------------------------------------------------------- GDSII
gds: $(OUT)/$(TOP).gds
$(OUT)/$(TOP).gds: $(OUT)/5_final.odb klayout/stream.py
	$(KLAYOUT) -zz \
	  -rd tech_file=$(PDK_DIR)/sky130hd.lyt \
	  -rd tlef=$(PDK_DIR)/lef/sky130_fd_sc_hd.tlef \
	  -rd lef=$(PDK_DIR)/lef/sky130_fd_sc_hd_merged.lef \
	  -rd in_def=$(OUT)/$(TOP).def \
	  -rd std_gds=$(PDK_DIR)/gds/sky130_fd_sc_hd.gds \
	  -rd top=$(TOP) -rd out_gds=$@ \
	  -r klayout/stream.py

clean:
	rm -rf $(OUT)
