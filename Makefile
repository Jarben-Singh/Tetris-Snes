# ============================================================
# Makefile - ProyectoTetris SNES
# Rol: Input / Infraestructura
# ------------------------------------------------------------
#   make          compila la ROM en build/main.sfc
#   make run      compila y abre Mesen
#   make clean    borra build/
#
# En Windows los binarios estan en tools/. En Mac/Linux se
# espera wla-65816 y wlalink en el PATH (brew install wla-dx).
# ============================================================

ROOT := $(CURDIR)

ifeq ($(OS),Windows_NT)
    AS   := $(ROOT)/tools/wla-65816.exe
    LINK := $(ROOT)/tools/wlalink.exe
    RUN  := powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/run-mesen.ps1 -Rom
else
    AS   := wla-65816
    LINK := wlalink
    RUN  := bash tools/run-mesen.sh
endif

SRC_DIR   := src
BUILD_DIR := build
ROM       := $(BUILD_DIR)/main.sfc
OBJ       := $(BUILD_DIR)/main.o

# main.asm incluye el resto de modulos, pero si cualquiera de
# ellos cambia hay que reensamblar. Por eso se listan todos
# como dependencias.
SOURCES := $(wildcard $(SRC_DIR)/*.asm) \
           $(wildcard $(SRC_DIR)/*/*.asm) \
           $(wildcard include/*.inc)

.PHONY: all run clean rebuild

all: $(ROM)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(OBJ): $(SOURCES) | $(BUILD_DIR)
	@echo "[ASM ] main.asm"
	@cd $(SRC_DIR) && $(AS) -o "$(ROOT)/$(OBJ)" main.asm

$(ROM): $(OBJ) linkfile
	@echo "[LINK] $(ROM)"
	@cd $(SRC_DIR) && $(LINK) -S -r "$(ROOT)/linkfile" "$(ROOT)/$(ROM)"
	@echo "[OK  ] ROM lista: $(ROM)"

run: $(ROM)
	$(RUN) $(ROM)

clean:
	@rm -rf $(BUILD_DIR)
	@echo "[CLEAN] build/ eliminado"

rebuild: clean all
