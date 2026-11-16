PDK ?= ihp-sg13g2
PDK_NAME := $(patsubst %/,%,$(PDK))
PDK_ROOT ?= /foss/pdks
CHIP ?= a
JOBS ?= 2

SIM_TEST := sim/tb.v
RTL := rtl/emg_mav.v rtl/emg_chip.v

ifeq ($(CHIP),c)
SIM_DEFINES := -DEMG_PARALLEL -DEMG_FOUR_CHANNEL
SIM_TEST := sim/tb-c.v
RTL += rtl/emg_mav4.v
else ifeq ($(CHIP),b)
SIM_DEFINES := -DEMG_PARALLEL
else ifneq ($(CHIP),a)
$(error CHIP debe ser a, b o c)
endif

CONFIG := librelane/chip-$(CHIP).yaml
TAG ?= emg-$(CHIP)-layout
LANE = librelane $(CONFIG) --pdk $(PDK_NAME) --pdk-root "$(PDK_ROOT)" --manual-pdk
BUILD = _OPENLANE_MAX_CORES=$(JOBS) OMP_NUM_THREADS=$(JOBS) $(LANE) --jobs $(JOBS)
PAD_MODEL := $(PDK_ROOT)/$(PDK_NAME)/libs.ref/sg13g2_io/verilog/sg13g2_io.v
SIM_DIR := sim/build/$(CHIP)
GDS = $(wildcard librelane/runs/$(TAG)/*-klayout-streamout/emg_chip.gds)

.DEFAULT_GOAL := sim
.PHONY: sim waves pad-dims synth layout full openroad klayout

sim:
	mkdir -p "$(SIM_DIR)"
	iverilog -g2012 -DFUNCTIONAL $(SIM_DEFINES) -s tb -o "$(SIM_DIR)/tb" $(RTL) "$(PAD_MODEL)" "$(SIM_TEST)"
	cd "$(SIM_DIR)" && vvp tb

waves:
	gtkwave "$(SIM_DIR)/emg.vcd"

pad-dims:
	awk '/^MACRO/{name=$$2} / SIZE / && name ~ /^sg13g2_(IOPadIn$$|IOPadOut4mA$$|IOPad.*Vdd$$|IOPad.*Vss$$|Corner$$|Filler)/ {print name, $$0}' "$(PDK_ROOT)/$(PDK_NAME)/libs.ref/sg13g2_io/lef/sg13g2_io.lef"

synth:
	$(BUILD) --run-tag emg-$(CHIP)-synth --to Yosys.Synthesis

layout:
	$(BUILD) --run-tag "$(TAG)" --to KLayout.StreamOut

full:
	$(BUILD) --run-tag "emg-$(CHIP)-full" --save-views-to "final/$(CHIP)"

openroad:
	$(LANE) --run-tag "$(TAG)" --flow OpenInOpenROAD

klayout:
	@test -n "$(GDS)" || { echo "Primero ejecuta make CHIP=$(CHIP) layout"; exit 1; }
	klayout "$(lastword $(GDS))"
