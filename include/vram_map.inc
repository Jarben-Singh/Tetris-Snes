; ============================================================
; vram_map.inc - Distribucion de VRAM y CGRAM
; ------------------------------------------------------------
; Igual que ram_map.inc, pero para la memoria de video. Cada
; grafico vive en una direccion fija elegida aqui; los DMA y
; los registros de la PPU (BG12NBA, BG1SC, OBSEL) se calculan a
; partir de estas constantes, asi nunca se desincronizan.
;
; Las direcciones de VRAM son en WORDS (64 KB = $0000-$7FFF).
;
;   $0000-$0FFF   tiles de sprites (OBJ, 8 KB)
;   $2000-$2FFF   tiles de BG1 (4bpp)
;   $3000-$33FF   tilemap de BG1 (32x32)
;   $3400-$37FF   tilemap de BG2 (32x32) - bloques fijos
;   $3800-$3BFF   tilemap de la pantalla de inicio (BG1, 32x32)
;   $4000-$407F   tiles de BG2 (4bpp) - tile 0 vacio + 7 piezas
;   $5000-$53FF   tiles de la pantalla de inicio (BG1, 4bpp)
; ============================================================

.DEFINE VRAM_OBJ_TILES  $0000   ; OBSEL name base = 0 (main.asm)
.DEFINE VRAM_BG1_TILES  $2000   ; multiplo de $1000 (BG12NBA)
.DEFINE VRAM_BG1_MAP    $3000   ; multiplo de $0400 (BG1SC)

; BG2 = capa de los bloques fijos del tablero (game/board.asm).
; El tile N de BG2 es el tile N-1 de las piezas: el tile 0 se
; queda en ceros (transparente) para las celdas vacias.
.DEFINE VRAM_BG2_TILES  $4000   ; multiplo de $1000 (BG12NBA)
.DEFINE VRAM_BG2_MAP    $3400   ; multiplo de $0400 (BG2SC)

; Cuantos tiles de TetrisPieces se copian a BG2 (a partir del
; tile 1). Debe cubrir el indice mas alto de PieceTileTable + 1;
; board.asm lo comprueba contra PIECE_TYPE_COUNT.
.DEFINE BG2_PIECE_TILES 7

; Digitos 0-9 del HUD (src/data/digits.asm), como tiles de
; sprite. Van despues de los tiles de TetrisPieces (que solo usa
; los tiles 0-6): el tile N de OBJ esta en VRAM_OBJ_TILES + N*16.
.DEFINE HUD_DIGIT_TILE_BASE 16
.DEFINE VRAM_HUD_DIGITS (VRAM_OBJ_TILES + HUD_DIGIT_TILE_BASE * 16)

; Pantalla de inicio: tambien se muestra en BG1. Tiene sus
; propios tiles y tilemap para no pisar los del juego; pasar de
; una a otra es solo cambiar BG1SC y BG12NBA (ShowTitleScreen /
; ShowGameScreen en engine/ppu.asm), sin volver a copiar nada.
.DEFINE VRAM_TITLE_TILES $5000  ; multiplo de $1000 (BG12NBA)
.DEFINE VRAM_TITLE_MAP   $3800  ; multiplo de $0400 (BG1SC)

; BG12NBA tiene un nibble por capa: bajo = BG1, alto = BG2.
; Siempre se escribe con los dos: si cada capa lo escribiera
; por separado, la segunda borraria a la primera.
.DEFINE BG12NBA_VALUE   (((VRAM_BG2_TILES >> 12) << 4) | (VRAM_BG1_TILES >> 12))
.DEFINE BG12NBA_TITLE   (((VRAM_BG2_TILES >> 12) << 4) | (VRAM_TITLE_TILES >> 12))

; ---------- CGRAM (indice de color, 0-255) ----------
; 0-127 = paletas de fondo (8 x 16), 128-255 = sprites.
.DEFINE CGRAM_BG_PAL0   $00     ; paleta 0 de BG (color 0 = backdrop)
.DEFINE CGRAM_BG_PAL1   $10     ; paleta 1 de BG = colores de las piezas
.DEFINE CGRAM_BG_PAL2   $20     ; paleta 2 de BG = pantalla de inicio
.DEFINE CGRAM_OBJ_PAL0  $80     ; paleta 0 de sprites

; ---------- Comprobaciones en tiempo de ensamblado ----------
; La PPU ignora los bits bajos: una direccion mal alineada no da
; error, simplemente muestra basura. Mejor que falle al compilar.
.IF (VRAM_BG1_TILES & $0FFF) != 0
    .FAIL "VRAM_BG1_TILES debe ser multiplo de $1000"
.ENDIF
.IF (VRAM_BG1_MAP & $03FF) != 0
    .FAIL "VRAM_BG1_MAP debe ser multiplo de $0400"
.ENDIF
.IF (VRAM_BG2_TILES & $0FFF) != 0
    .FAIL "VRAM_BG2_TILES debe ser multiplo de $1000"
.ENDIF
.IF (VRAM_BG2_MAP & $03FF) != 0
    .FAIL "VRAM_BG2_MAP debe ser multiplo de $0400"
.ENDIF
.IF (VRAM_TITLE_TILES & $0FFF) != 0
    .FAIL "VRAM_TITLE_TILES debe ser multiplo de $1000"
.ENDIF
.IF (VRAM_TITLE_MAP & $03FF) != 0
    .FAIL "VRAM_TITLE_MAP debe ser multiplo de $0400"
.ENDIF
