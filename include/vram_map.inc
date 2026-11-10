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
; ============================================================

.DEFINE VRAM_OBJ_TILES  $0000   ; OBSEL name base = 0 (main.asm)
.DEFINE VRAM_BG1_TILES  $2000   ; multiplo de $1000 (BG12NBA)
.DEFINE VRAM_BG1_MAP    $3000   ; multiplo de $0400 (BG1SC)

; ---------- CGRAM (indice de color, 0-255) ----------
; 0-127 = paletas de fondo (8 x 16), 128-255 = sprites.
.DEFINE CGRAM_BG_PAL0   $00     ; paleta 0 de BG (color 0 = backdrop)
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
