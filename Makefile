VERILATOR ?= verilator
NODE ?= node
.PHONY: lint test
lint:
	$(VERILATOR) --lint-only --timing -Wno-fatal --top-module CHIP rtl/CHIP.v
test:
	$(NODE) --test tests/*.test.js
