# ============================================================
# Makefile - ProyectoTetris SNES
# Rol: Input / Infraestructura
# ------------------------------------------------------------
#   make          compila la ROM en build/main.sfc
#   make run      compila y abre Mesen
#   make clean    borra build/
#   make gfx      regenera los graficos de assets/gfx/ desde
#                 los PNG (requiere SuperFamiconv)
#
# En Windows los binarios estan en tools/. En Mac/Linux se
# espera wla-65816 y wlalink en el PATH (brew install wla-dx).
# ============================================================

ROOT := $(CURDIR)

ifeq ($(OS),Windows_NT)
    AS   := $(ROOT)/tools/wla-65816.exe
    LINK := $(ROOT)/tools/wlalink.exe
    SFC  := $(ROOT)/tools/superfamiconv.exe
    RUN  := powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/run-mesen.ps1 -Rom
else
    AS   := wla-65816
    LINK := wlalink
    SFC  := superfamiconv
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
           $(wildcard $(SRC_DIR)/data/*.as) \
           $(wildcard include/*.inc)

# ------------------------------------------------------------
# Graficos convertidos con SuperFamiconv (4bpp, tiles de 8x8).
# Los binarios de assets/gfx/ se versionan en git, asi que
# `make` NO los regenera: solo hace falta `make gfx` cuando
# cambia el PNG. -R conserva el orden de la paleta del PNG
# (el indice 0 es el color de fondo).
# ------------------------------------------------------------
GFX_DIR   := assets/gfx
GFX_FLAGS := -M snes -B 4 -R

BG1_PNG := assets/Background1-Tetris.png
BG1_OUT := $(GFX_DIR)/background_tetris1

# Pantalla de inicio: tambien en BG1, pero con sus propios tiles,
# tilemap y la paleta 2 de BG (-P 2), asi convive en VRAM con el
# fondo del juego (ver vram_map.inc).
TITLE_PNG := assets/Tetris-Start.png
TITLE_OUT := $(GFX_DIR)/title_start

# Si cambia un binario incluido con .incbin hay que reensamblar.
SOURCES += $(wildcard $(GFX_DIR)/*.pal) \
           $(wildcard $(GFX_DIR)/*.tiles) \
           $(wildcard $(GFX_DIR)/*.map) \
           $(wildcard assets/thanks/*) \
           $(wildcard assets/credits/*)

.PHONY: all run clean rebuild gfx

all: $(ROM)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(GFX_DIR):
	@mkdir -p $(GFX_DIR)

gfx: | $(GFX_DIR)
	@echo "[GFX ] $(BG1_PNG)"
	@$(SFC) -i $(BG1_PNG) -p $(BG1_OUT).pal -t $(BG1_OUT).tiles -m $(BG1_OUT).map $(GFX_FLAGS)
	@echo "[GFX ] $(TITLE_PNG)"
	@$(SFC) -i $(TITLE_PNG) -p $(TITLE_OUT).pal -t $(TITLE_OUT).tiles -m $(TITLE_OUT).map $(GFX_FLAGS) -P 2
	@echo "[OK  ] graficos en $(GFX_DIR)/"

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
