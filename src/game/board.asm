; ============================================================
; board.asm
; Logica del tablero: matriz de piezas fijas y su dibujo.
;
; El tablero vive en BOARD (ram_map.inc): 10x20 bytes,
; indice = fila * 10 + columna, 0 = vacia, 1-7 = tipo + 1.
;
; Los bloques fijos se dibujan como TILES de BG2, no como
; sprites: la SNES solo tiene 128 sprites (y 32 por linea), y
; un tablero lleno son 200 bloques. BoardRender escribe el
; tilemap en BG2_SHADOW y el NMI lo manda con Bg2Flush.
; La pieza activa sigue siendo sprites (0-3).
;
; Usa BOARD_WIDTH, BOARD_HEIGHT y BOARD_ORIGIN_* de piece.asm,
; por eso se incluye despues de el.
; ============================================================


; El indice de celda se calcula como fila*8 + fila*2 (= fila*10).
.IF BOARD_WIDTH != 10
    .FAIL "board.asm asume BOARD_WIDTH = 10 (fila*8 + fila*2)"
.ENDIF

.DEFINE BOARD_CELLS (BOARD_WIDTH * BOARD_HEIGHT)

; Celda (0,0) del tablero en tiles del mapa de BG2.
.DEFINE BOARD_TILE_X (BOARD_ORIGIN_X / 8)
.DEFINE BOARD_TILE_Y (BOARD_ORIGIN_Y / 8)

; Ancho del tilemap de BG2 (32x32) en entradas.
.DEFINE BG2_MAP_WIDTH 32

; Entrada del tilemap de un bloque, sin el numero de tile:
;   bit 13    = prioridad alta (encima de BG1, que va en baja)
;   bits 10-12 = paleta 1 de BG (CGRAM_BG_PAL1)
.DEFINE BG2_BLOCK_ATTR ($2000 | ((CGRAM_BG_PAL1 / 16) << 10))

; El tablero tiene que caer en el grid de 8x8 del mapa.
.IF (BOARD_ORIGIN_X & 7) != 0
    .FAIL "BOARD_ORIGIN_X debe ser multiplo de 8 (tiles de BG2)"
.ENDIF
.IF (BOARD_ORIGIN_Y & 7) != 0
    .FAIL "BOARD_ORIGIN_Y debe ser multiplo de 8 (tiles de BG2)"
.ENDIF
.IF BG2_SHADOW_SIZE != (BOARD_HEIGHT * BG2_MAP_WIDTH * 2)
    .FAIL "BG2_SHADOW_SIZE no coincide con BOARD_HEIGHT x 32 x 2"
.ENDIF
.IF BG2_PIECE_TILES < PIECE_TYPE_COUNT
    .FAIL "BG2_PIECE_TILES debe cubrir los tiles de las 7 piezas"
.ENDIF


; ============================================================
; BoardClear
;
; Deja todas las celdas del tablero vacias.
; ============================================================

BoardClear:
    PHP
    AI16
    PHX

    LDX #$0000
    LDA #$0000
BoardClear_Loop:
    STA.w BOARD,X
    INX
    INX
    CPX #BOARD_CELLS
    BCC BoardClear_Loop

    PLX
    PLP
    RTS


; ============================================================
; BoardLockPiece
;
; Copia las 4 celdas de la pieza activa al tablero
; (valor = ACTIVE_PIECE_TYPE + 1).
;
; Se llama cuando la pieza ya no puede bajar. Las celdas ya
; fueron validadas por ActivePieceFits, asi que siempre caen
; dentro del tablero.
;
; Usa el scratch $00-$01 (offset) y $07-$08.
; ============================================================

BoardLockPiece:
    PHP
    AI16
    PHX
    PHY

    ; X = tipo*32 + rotacion*8 (igual que DrawActivePiece)
    LDA ACTIVE_PIECE_TYPE
    AND #$00FF
    ASL
    ASL
    ASL
    ASL
    ASL
    STA $00

    LDA ACTIVE_PIECE_ROTATION
    AND #$0003
    ASL
    ASL
    ASL
    CLC
    ADC $00
    TAX

    A8
    LDA #$04
    STA $07                         ; quedan 4 bloques

BoardLockPiece_Loop:
    ; fila*10
    LDA.w TetrominoRotations+1,X    ; dy
    CLC
    ADC ACTIVE_PIECE_Y
    ASL                             ; fila*2
    STA $08
    ASL
    ASL                             ; fila*8
    CLC
    ADC $08
    STA $08                         ; fila*10

    ; + columna
    LDA.w TetrominoRotations,X      ; dx
    CLC
    ADC ACTIVE_PIECE_X
    CLC
    ADC $08

    A16
    AND #$00FF
    TAY                             ; Y = indice de la celda
    A8

    LDA ACTIVE_PIECE_TYPE
    INC A                           ; 0 queda reservado para "vacia"
    STA.w BOARD,Y

    INX
    INX
    DEC $07
    BNE BoardLockPiece_Loop

    PLY
    PLX
    PLP
    RTS


; ============================================================
; BoardClearLines
;
; Borra las filas llenas y baja todo lo que estaba encima, en
; una sola pasada de abajo hacia arriba:
;
;   r = w = ultima fila
;   mientras r >= 0:
;       si la fila r esta llena -> se salta (lineas + 1)
;       si no -> se copia a la fila w, y w sube una fila
;       r sube una fila
;   las filas 0..w quedan vacias (las que "entran" arriba)
;
; Copiar una fila sobre si misma (r = w, sin lineas borradas
; todavia) no cambia nada, asi que no se revisa ese caso.
;
; Salida: A (8 bits) = lineas borradas (0-4).
; X y Y guardan los offsets de r y w (fila*10) en 16 bits; al
; pasar de la fila 0 quedan negativos, por eso se usa BMI.
; Usa $07 (contador de lineas). No llama a BoardRender: quien
; llama redibuja cuando termina de cambiar el tablero.
; ============================================================

BoardClearLines:
    PHP
    AI16
    PHX
    PHY

    A8
    STZ $07                         ; lineas borradas
    LDX #((BOARD_HEIGHT - 1) * BOARD_WIDTH)  ; r = ultima fila
    TXY                             ; w = r

BoardClearLines_Row:
    ; Fila llena = ninguna de sus celdas vale 0.
    .REPT BOARD_WIDTH INDEX COL
    LDA.w BOARD+COL,X
    BEQ BoardClearLines_Keep
    .ENDR

    INC $07                         ; fila llena: no se copia
    BRA BoardClearLines_Next

BoardClearLines_Keep:
    .REPT BOARD_WIDTH INDEX COL
    LDA.w BOARD+COL,X
    STA.w BOARD+COL,Y
    .ENDR

    A16
    TYA
    SEC
    SBC #BOARD_WIDTH                ; w = fila de arriba
    TAY
    A8

BoardClearLines_Next:
    A16
    TXA
    SEC
    SBC #BOARD_WIDTH                ; r = fila de arriba
    TAX                             ; N = 1 si ya se paso de la fila 0
    A8                              ; (SEP no toca N)
    BMI BoardClearLines_Fill
    JMP BoardClearLines_Row         ; muy lejos para un BPL

BoardClearLines_Fill:
    ; Vaciar las filas 0..w: son (w + 1) * 10 = Y + 10 bytes.
    A16
    TYA
    CLC
    ADC #BOARD_WIDTH
    TAX                             ; Z = 1 si no hay nada que vaciar
    A8
    BEQ BoardClearLines_Done

BoardClearLines_FillLoop:
    DEX
    STZ.w BOARD,X                   ; STZ no toca las banderas:
    BNE BoardClearLines_FillLoop    ; Z viene del DEX

BoardClearLines_Done:
    LDA $07

    PLY
    PLX
    PLP
    RTS



; ============================================================
; BoardRender
;
; Redibuja todos los bloques fijos en BG2_SHADOW (el espejo del
; tilemap de BG2) a partir de BOARD, y marca BG2_DIRTY para que
; el siguiente NMI lo mande a VRAM (Bg2Flush). Solo hace falta
; llamarla cuando el tablero cambia.
;
; Celda (fila, col) -> entrada (fila*32 + BOARD_TILE_X + col)
; del shadow. Vacia = $0000 (tile 0, transparente); ocupada =
; BG2_BLOCK_ATTR | (PieceTileTable[valor-1] + 1).
;
; BG2_DIRTY se apaga al empezar y se prende al terminar: si el
; NMI cae a la mitad, no manda un tilemap a medio construir.
;
; Usa $07 (columnas restantes) y $08 (filas restantes).
; ============================================================

BoardRender:
    PHP
    AI16
    PHX
    PHY

    A8
    STZ BG2_DIRTY

    LDX #$0000                      ; indice de celda en BOARD
    LDY #(BOARD_TILE_X * 2)         ; offset en bytes en el shadow
    LDA #BOARD_HEIGHT
    STA $08

BoardRender_Row:
    LDA #BOARD_WIDTH
    STA $07

BoardRender_Col:
    LDA.w BOARD,X
    BEQ BoardRender_Empty

    DEC A                           ; valor - 1 = tipo de pieza
    PHX
    A16
    AND #$00FF
    TAX
    LDA.w PieceTileTable,X          ; byte alto = basura, se descarta
    AND #$00FF
    INC A                           ; tile 0 de BG2 = vacio
    ORA #BG2_BLOCK_ATTR
    PLX
    BRA BoardRender_Store

BoardRender_Empty:
    A16
    LDA #$0000

BoardRender_Store:
    STA.w BG2_SHADOW,Y
    A8
    INX
    INY
    INY
    DEC $07
    BNE BoardRender_Col

    ; Saltar las columnas del mapa fuera del tablero hasta el
    ; inicio de la siguiente fila (se quedan siempre en 0).
    A16
    TYA
    CLC
    ADC #((BG2_MAP_WIDTH - BOARD_WIDTH) * 2)
    TAY
    A8
    DEC $08
    BNE BoardRender_Row

    LDA #$01
    STA BG2_DIRTY

    PLY
    PLX
    PLP
    RTS


; ============================================================
; Bg2Flush
;
; Manda BG2_SHADOW al tilemap de BG2 por DMA (canal 0, el del
; NMI), a partir de la fila BOARD_TILE_Y del mapa. Solo se
; llama desde el NMI (core/nmi.asm), durante el V-Blank.
; Preserva P. Modifica A.
; ============================================================

Bg2Flush:
    PHP
    A8
    LDA #$80
    STA VMAIN                       ; incrementar tras el byte alto

    A16
    LDA #(VRAM_BG2_MAP + BOARD_TILE_Y * BG2_MAP_WIDTH)
    STA VMADDL                      ; 16 bits: VMADDL/VMADDH
    LDA #BG2_SHADOW
    STA A1T0L
    LDA #BG2_SHADOW_SIZE
    STA DAS0L

    A8
    LDA #$00
    STA A1B0                        ; banco 0 (WRAM baja)
    LDA #$01
    STA DMAP0                       ; modo 1: $2118/$2119 alternados
    LDA #(VMDATAL & $FF)
    STA BBAD0
    LDA #$01
    STA MDMAEN                      ; disparar canal 0
    PLP
    RTS
