; ============================================================
; piece.asm
; Logica relacionada con la pieza activa.
; ============================================================


; Posicion fija donde comienza visualmente el tablero.
; NO es el tamano del tablero.
.DEFINE BOARD_ORIGIN_X 8
.DEFINE BOARD_ORIGIN_Y 16


; Los cuatro bloques de la pieza activa usan
; los sprites 0, 1, 2 y 3.
.DEFINE ACTIVE_PIECE_SPRITE_BASE 0


; ============================================================
; DrawActivePiece
;
; Usa:
;   ACTIVE_PIECE_TYPE
;   ACTIVE_PIECE_ROTATION
;   ACTIVE_PIECE_X
;   ACTIVE_PIECE_Y
;
; Flujo:
;
; tipo + rotacion
;       ↓
; buscar datos en TetrominoRotations
;       ↓
; leer 4 pares (dx,dy)
;       ↓
; convertir grid -> pixeles
;       ↓
; OamSetSprite
; ============================================================

DrawActivePiece:

    ; Trabajamos inicialmente con A, X y Y en 16 bits.
    ; Esto tambien permite llamar de forma segura OamSetSprite.
    AI16


    ; --------------------------------------------------------
    ; 1. Calcular offset de la pieza
    ;
    ; Cada pieza ocupa:
    ;
    ; 4 rotaciones * 8 bytes = 32 bytes
    ;
    ; offsetPieza = tipo * 32
    ; --------------------------------------------------------

    LDA ACTIVE_PIECE_TYPE
    AND #$00FF

    ASL
    ASL
    ASL
    ASL
    ASL                     ; tipo * 32

    STA $00                 ; $00-$01 = offset temporal


    ; --------------------------------------------------------
    ; 2. Calcular offset de la rotacion
    ;
    ; Cada rotacion ocupa 8 bytes.
    ;
    ; offsetRotacion = rotacion * 8
    ; --------------------------------------------------------

    LDA ACTIVE_PIECE_ROTATION
    AND #$00FF
    AND #$0003              ; permitir solamente 0-3

    ASL
    ASL
    ASL                     ; rotacion * 8

    CLC
    ADC $00                 ; tipo*32 + rotacion*8

    TAX                     ; X apunta al inicio de la rotacion


    ; --------------------------------------------------------
    ; Y guardara el tipo de pieza.
    ;
    ; Nos servira para consultar PieceTileTable.
    ; --------------------------------------------------------

    LDA ACTIVE_PIECE_TYPE
    AND #$00FF
    TAY


    ; A partir de aqui los valores son pequenos,
    ; asi que el acumulador puede trabajar en 8 bits.
    ;
    ; X/Y permanecen en 16 bits.
    A8


    ; --------------------------------------------------------
    ; Preparar loop de los cuatro bloques.
    ; --------------------------------------------------------

    LDA #$04
    STA $07                 ; quedan 4 bloques


    LDA #ACTIVE_PIECE_SPRITE_BASE
    STA $08                 ; sprite actual


DrawActivePieceLoop:


    ; ========================================================
    ; 3. Obtener dx y calcular X en pantalla
    ; ========================================================

    LDA.w TetrominoRotations,X     ; leer dx

    CLC
    ADC ACTIVE_PIECE_X             ; gridX = ActiveX + dx

    ; Cada celda mide 8 pixeles.
    ASL
    ASL
    ASL                            ; gridX * 8

    CLC
    ADC #BOARD_ORIGIN_X

    STA $03                        ; X para OamSetSprite


    ; ========================================================
    ; 4. Obtener dy y calcular Y en pantalla
    ; ========================================================

    LDA.w TetrominoRotations+1,X   ; leer dy

    CLC
    ADC ACTIVE_PIECE_Y             ; gridY = ActiveY + dy

    ASL
    ASL
    ASL                            ; gridY * 8

    CLC
    ADC #BOARD_ORIGIN_Y

    STA $04                        ; Y para OamSetSprite


    ; ========================================================
    ; 5. Numero de sprite
    ; ========================================================

    LDA $08
    STA $02


    ; ========================================================
    ; 6. Tile correspondiente al tipo de pieza
    ; ========================================================

    LDA.w PieceTileTable,Y
    STA $05


    ; ========================================================
    ; 7. Atributos del sprite
    ;
    ; Por ahora:
    ; paleta base, sin flip.
    ; ========================================================

    LDA #$00
    STA $06


    ; ========================================================
    ; 8. Pedirle a la infraestructura que dibuje el sprite
    ; ========================================================

    JSR OamSetSprite


    ; Cada bloque usa dos bytes:
    ;
    ; dx, dy
    ;
    ; avanzar al siguiente.
    INX
    INX


    ; siguiente numero de sprite
    INC $08


    ; repetir hasta dibujar 4 bloques
    DEC $07
    BNE DrawActivePieceLoop


    RTS