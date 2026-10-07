VERILATOR ?= verilator
TOP       := tb_graphics_microcontroller
BUILD_DIR := build
RTL       := ../rtl/command_fifo.sv ../rtl/graphics_microcontroller.sv
TB        := ../tb/tb_graphics_microcontroller.sv

.PHONY: all lint test clean
all: test

lint:
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal --top-module graphics_microcontroller $(RTL)

test:
	$(VERILATOR) --binary --timing -Wall -Wno-fatal --top-module $(TOP) --Mdir $(BUILD_DIR) $(RTL) $(TB)
	./$(BUILD_DIR)/V$(TOP)

clean:
	rm -rf $(BUILD_DIR)
