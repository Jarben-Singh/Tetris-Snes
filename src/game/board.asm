; ============================================================
; board.asm
; Logica del tablero: matriz de piezas fijas y su dibujo.
; (line clear pendiente)
;
; El tablero vive en BOARD (ram_map.inc): 10x20 bytes,
; indice = fila * 10 + columna, 0 = vacia, 1-7 = tipo + 1.
;
; Usa BOARD_WIDTH, BOARD_HEIGHT y BOARD_ORIGIN_* de piece.asm,
; por eso se incluye despues de el.
; ============================================================


; El indice de celda se calcula como fila*8 + fila*2 (= fila*10).
.IF BOARD_WIDTH != 10
    .FAIL "board.asm asume BOARD_WIDTH = 10 (fila*8 + fila*2)"
.ENDIF

.DEFINE BOARD_CELLS (BOARD_WIDTH * BOARD_HEIGHT)

; Los bloques fijos usan los sprites 4-127 (los 0-3 son de la
; pieza activa). Si hay mas de 124 bloques, los sobrantes no se
; dibujan (siguen contando para la colision).
.DEFINE BOARD_SPRITE_BASE 4
.DEFINE OAM_SPRITE_COUNT  128


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
; BoardDraw
;
; Redibuja todos los bloques fijos en el buffer de OAM, a
; partir del sprite BOARD_SPRITE_BASE, y esconde los sprites
; que sobran (Y = 224). Solo hace falta llamarla cuando el
; tablero cambia: los sprites se quedan en el buffer.
;
; Entradas de OamSetSprite ($02-$06) usadas como contadores:
;   $02 = sprite actual, $03/$04 = X/Y en pixeles.
; Usa $07 (columnas restantes) y $08 (filas restantes).
; ============================================================

BoardDraw:
    PHP
    AI16
    PHX
    PHY

    A8
    LDA #BOARD_SPRITE_BASE
    STA $02

    LDY #$0000                      ; indice de celda
    LDA #BOARD_ORIGIN_Y
    STA $04
    LDA #BOARD_HEIGHT
    STA $08

BoardDraw_Row:
    LDA #BOARD_ORIGIN_X
    STA $03
    LDA #BOARD_WIDTH
    STA $07

BoardDraw_Col:
    LDA $02
    CMP #OAM_SPRITE_COUNT
    BCS BoardDraw_Next              ; ya no quedan sprites libres

    LDA.w BOARD,Y
    BEQ BoardDraw_Next              ; celda vacia

    DEC A                           ; valor - 1 = tipo de pieza
    A16
    AND #$00FF
    TAX
    A8
    LDA.w PieceTileTable,X
    STA $05
    LDA #OBJ_PRIO_3
    STA $06
    JSR OamSetSprite
    INC $02

BoardDraw_Next:
    INY
    LDA $03
    CLC
    ADC #$08
    STA $03
    DEC $07
    BNE BoardDraw_Col

    LDA $04
    CLC
    ADC #$08
    STA $04
    DEC $08
    BNE BoardDraw_Row

    ; --------------------------------------------------------
    ; Esconder los sprites que no se usaron (igual que
    ; OamBufferInit: Y = 224, fuera de la pantalla).
    ; --------------------------------------------------------
    STZ $03
    LDA #$E0
    STA $04
    STZ $05
    STZ $06

BoardDraw_Hide:
    LDA $02
    CMP #OAM_SPRITE_COUNT
    BCS BoardDraw_Done
    JSR OamSetSprite
    INC $02
    BRA BoardDraw_Hide

BoardDraw_Done:
    PLY
    PLX
    PLP
    RTS
