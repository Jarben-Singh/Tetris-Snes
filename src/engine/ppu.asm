; ============================================================
; ppu.asm - Configuracion de fondos de la PPU
; ------------------------------------------------------------
; Cada fondo tiene su rutina Load*: manda tiles, tilemap y
; paleta con las rutinas de engine/dma.asm y configura los
; registros de la capa. Las direcciones salen de vram_map.inc.
;
; Llamar SOLO con la pantalla en forced blank (INIDISP bit 7).
; Activar la capa en TM es responsabilidad de quien llama.
; ============================================================

; ------------------------------------------------------------
; LoadBackgroundTetris1 - fondo del tablero en BG1
;   Tiles   -> VRAM_BG1_TILES  (4bpp, modo 1)
;   Tilemap -> VRAM_BG1_MAP    (32x28 dentro de un mapa 32x32)
;   Paleta  -> CGRAM_BG_PAL0   (paleta 0 de fondo, 16 colores)
; Preserva P. Modifica A y el scratch DMA_*.
; ------------------------------------------------------------
LoadBackgroundTetris1:
    PHP

    ; --- Tiles ---
    A16
    LDA #BackgroundTetris1_til
    STA DMA_SRC
    LDA #(BackgroundTetris1_tilend - BackgroundTetris1_til)
    STA DMA_SIZE
    LDA #VRAM_BG1_TILES
    STA DMA_DEST
    A8
    LDA #:BackgroundTetris1_til
    STA DMA_BANK
    JSR DmaToVram

    ; --- Tilemap ---
    A16
    LDA #BackgroundTetris1_map
    STA DMA_SRC
    LDA #(BackgroundTetris1_mapend - BackgroundTetris1_map)
    STA DMA_SIZE
    LDA #VRAM_BG1_MAP
    STA DMA_DEST
    A8
    LDA #:BackgroundTetris1_map
    STA DMA_BANK
    JSR DmaToVram

    ; --- Paleta ---
    A16
    LDA #BackgroundTetris1_pal
    STA DMA_SRC
    LDA #(BackgroundTetris1_palend - BackgroundTetris1_pal)
    STA DMA_SIZE
    LDA #CGRAM_BG_PAL0
    STA DMA_DEST
    A8
    LDA #:BackgroundTetris1_pal
    STA DMA_BANK
    JSR DmaToCgram

    ; --- Registros de BG1 ---
    ; BG1SC: bits 7-2 = base del mapa en unidades de $400 words,
    ;        bits 1-0 = tamano (00 = 32x32 tiles)
    LDA #((VRAM_BG1_MAP >> 8) & $FC)
    STA BG1SC
    ; BG12NBA: nibble bajo = base de tiles de BG1 en unidades
    ;          de $1000 words (el nibble alto es BG2)
    LDA #(VRAM_BG1_TILES >> 12)
    STA BG12NBA

    ; Scroll: registros de escritura doble (byte bajo, luego alto).
    ; La PPU empieza a dibujar en la linea 1 del fondo, asi que
    ; VOFS = -1 ($03FF) alinea la fila 0 del mapa con la pantalla.
    LDA #$00
    STA BG1HOFS
    STA BG1HOFS
    LDA #$FF
    STA BG1VOFS
    LDA #$03
    STA BG1VOFS

    PLP
    RTS
