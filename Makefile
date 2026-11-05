VERILATOR ?= verilator
NODE ?= node
.PHONY: lint test
lint:
	$(VERILATOR) --lint-only --timing -Wno-fatal --top-module CHIP rtl/CHIP.v
test:
	$(NODE) --test tests/*.test.js

WORKLOAD ?= QSort_uncompressed
.PHONY: rtl-test
rtl-test:
	mkdir -p build/$(WORKLOAD)
	$(VERILATOR) --binary --timing -Wno-fatal -j 4 --Mdir build/$(WORKLOAD) --top-module Final_tb +define+$(WORKLOAD) sim/Final_tb.v sim/slow_memory.sv rtl/CHIP.v
	./build/$(WORKLOAD)/VFinal_tb
