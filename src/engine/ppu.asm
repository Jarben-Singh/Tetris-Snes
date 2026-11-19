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
    ; BG12NBA (base de tiles) NO se escribe aqui: comparte
    ; registro con BG2 y main.asm lo escribe una sola vez con
    ; BG12NBA_VALUE (vram_map.inc).

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

; ------------------------------------------------------------
; LoadBoardLayer - capa de los bloques fijos del tablero en BG2
;   Tiles   -> VRAM_BG2_TILES + 1 tile (los BG2_PIECE_TILES
;              primeros tiles de las piezas; el tile 0 se queda
;              en ceros = transparente, la VRAM ya se limpio)
;   Paleta  -> CGRAM_BG_PAL1 (copia de la paleta de sprites)
;   Tilemap -> VRAM_BG2_MAP, ya en ceros = todo vacio. Durante
;              el juego lo actualiza el NMI desde BG2_SHADOW.
; El formato 4bpp de sprites y de fondos es el mismo, asi que
; se reusan los tiles de TetrisPieces sin convertir nada.
; Preserva P. Modifica A y el scratch DMA_*.
; ------------------------------------------------------------
LoadBoardLayer:
    PHP

    ; --- Tiles (a partir del tile 1 = 16 words) ---
    A16
    LDA #TetrisPieces_til
    STA DMA_SRC
    LDA #(BG2_PIECE_TILES * 32)
    STA DMA_SIZE
    LDA #(VRAM_BG2_TILES + 16)
    STA DMA_DEST
    A8
    LDA #:TetrisPieces_til
    STA DMA_BANK
    JSR DmaToVram

    ; --- Paleta ---
    A16
    LDA #TetrisPieces_pal
    STA DMA_SRC
    LDA #(TetrisPieces_palend - TetrisPieces_pal)
    STA DMA_SIZE
    LDA #CGRAM_BG_PAL1
    STA DMA_DEST
    A8
    LDA #:TetrisPieces_pal
    STA DMA_BANK
    JSR DmaToCgram

    ; --- Registros de BG2 ---
    LDA #((VRAM_BG2_MAP >> 8) & $FC)
    STA BG2SC

    ; Mismo scroll que BG1 (VOFS = -1). Si no, los bloques fijos
    ; quedan una linea mas abajo que la pieza activa (sprites).
    LDA #$00
    STA BG2HOFS
    STA BG2HOFS
    LDA #$FF
    STA BG2VOFS
    LDA #$03
    STA BG2VOFS

    PLP
    RTS
