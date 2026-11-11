; ============================================================
; piece.asm
; Logica relacionada con la pieza activa.
; ============================================================


; Posicion en pixeles de la celda (0,0) del tablero.
; NO es el tamano del tablero.
; Debe coincidir con el fondo (assets/Background-Tetris1.png):
; el interior del tablero son los tiles 11-20 en X y 4-23 en Y
; (10x20 celdas), asi que empieza en (11*8, 4*8).
.DEFINE BOARD_ORIGIN_X 88
.DEFINE BOARD_ORIGIN_Y 32


; Los cuatro bloques de la pieza activa usan
; los sprites 0, 1, 2 y 3.
.DEFINE ACTIVE_PIECE_SPRITE_BASE 0


; Posicion inicial de la pieza activa (en celdas del grid).
; Es la esquina de la caja 4x4 de la pieza: X=3 la centra en
; las 10 columnas (3 libres a cada lado) e Y=0 la hace aparecer
; arriba, desde donde la gravedad la va bajando.
.DEFINE ACTIVE_PIECE_START_X 3
.DEFINE ACTIVE_PIECE_START_Y 0

; Cantidad de tipos de pieza (I, O, T, S, Z, J, L).
.DEFINE PIECE_TYPE_COUNT 7

; Tamano del tablero, en celdas. board.asm todavia no existe
; (semana 8), asi que por ahora estos limites solo evitan que la
; pieza se salga del tablero dibujado en el fondo; no hay
; colision contra otras piezas.
.DEFINE BOARD_WIDTH  10
.DEFINE BOARD_HEIGHT 20

; Pieza candidata (scratch $09-$0F) para ActivePieceFits.
; Se copia el estado actual, se modifica un campo (X, Y,
; rotacion o tipo) y solo se aplica si las 4 celdas caben.
.DEFINE CAND_TYPE      $09
.DEFINE CAND_ROTATION  $0A
.DEFINE CAND_X         $0B
.DEFINE CAND_Y         $0C
.DEFINE CAND_COUNT     $0D    ; bloques que faltan revisar
.DEFINE CAND_OFFSET    $0E    ; 16 bits: tipo*32 temporal


; ============================================================
; ActivePieceInit
;
; Deja la pieza activa en su estado inicial:
; pieza T, rotacion 0, en la posicion de inicio.
; ============================================================

ActivePieceInit:
    PHP
    A8

    LDA #$02                ; T
    STA ACTIVE_PIECE_TYPE
    STZ ACTIVE_PIECE_ROTATION

    LDA #ACTIVE_PIECE_START_X
    STA ACTIVE_PIECE_X
    LDA #ACTIVE_PIECE_START_Y
    STA ACTIVE_PIECE_Y

    PLP
    RTS


; ============================================================
; ActivePieceUpdate
;
; Lee los botones recien presionados (PAD1_PRESSED) y
; actualiza la pieza activa:
;
;   A      -> rotar en sentido horario      (rotacion + 1)
;   B      -> rotar en sentido antihorario  (rotacion - 1)
;   SELECT -> cambiar a la siguiente pieza (prueba)
;
; La rotacion siempre queda entre 0 y 3.
; Cada cambio solo se aplica si las 4 celdas de la pieza quedan
; dentro del tablero (ActivePieceFits). Sin colision contra
; otras piezas todavia.
; ============================================================

ActivePieceUpdate:
    PHP


    ; --------------------------------------------------------
    ; Movimiento horizontal (D-pad, con auto-repeat via DAS)
    ; --------------------------------------------------------

    JSR InputDAS             ; A (8 bits): 0 nada, 1 izq, 2 der

    CMP #$01
    BNE ActivePieceUpdate_CheckMoveRight
    JSR ActivePieceLoadCandidate
    DEC CAND_X
    JSR ActivePieceTryCommit
    BRA ActivePieceUpdate_CheckSelect

ActivePieceUpdate_CheckMoveRight:
    CMP #$02
    BNE ActivePieceUpdate_CheckSelect
    JSR ActivePieceLoadCandidate
    INC CAND_X
    JSR ActivePieceTryCommit


ActivePieceUpdate_CheckSelect:

    ; --------------------------------------------------------
    ; SELECT: siguiente tipo de pieza, rotacion vuelve a 0
    ; --------------------------------------------------------

    A16
    LDA PAD1_PRESSED
    AND #BTN_SELECT
    BEQ ActivePieceUpdate_CheckA

    A8
    JSR ActivePieceLoadCandidate
    LDA CAND_TYPE
    INC A
    CMP #PIECE_TYPE_COUNT
    BCC ActivePieceUpdate_SetType
    LDA #$00                ; despues de L vuelve a I

ActivePieceUpdate_SetType:
    STA CAND_TYPE
    STZ CAND_ROTATION
    JSR ActivePieceTryCommit


ActivePieceUpdate_CheckA:

    ; --------------------------------------------------------
    ; A: rotar en sentido horario
    ; --------------------------------------------------------

    ; Re-afirmar A16: el ensamblador lleva el tamano de A en
    ; orden de texto, y la rama anterior lo dejo en 8 bits.
    A16
    LDA PAD1_PRESSED
    AND #BTN_A
    BEQ ActivePieceUpdate_CheckB

    A8
    JSR ActivePieceLoadCandidate
    LDA CAND_ROTATION
    INC A
    BRA ActivePieceUpdate_Wrap


ActivePieceUpdate_CheckB:

    ; --------------------------------------------------------
    ; B: rotar en sentido antihorario
    ; --------------------------------------------------------

    A16
    LDA PAD1_PRESSED
    AND #BTN_B
    BEQ ActivePieceUpdate_Done

    A8
    JSR ActivePieceLoadCandidate
    LDA CAND_ROTATION
    DEC A


ActivePieceUpdate_Wrap:

    ; 3 + 1 = 4 -> 0   y   0 - 1 = $FF -> 3
    A8
    AND #$03
    STA CAND_ROTATION
    JSR ActivePieceTryCommit


ActivePieceUpdate_Done:
    PLP
    RTS


; ============================================================
; ActivePieceApplyGravity
;
; Baja la pieza activa una fila. La llama el bucle principal
; cuando GravityShouldFall (engine/timing.asm) dice que toca.
;
; Se detiene cuando alguna celda llegaria a la ultima fila del
; tablero. Cuando exista board.asm se agrega la colision contra
; las piezas fijas.
; ============================================================

ActivePieceApplyGravity:
    PHP
    A8

    JSR ActivePieceLoadCandidate
    INC CAND_Y
    JSR ActivePieceTryCommit

    PLP
    RTS


; ============================================================
; ActivePieceLoadCandidate
;
; Copia el estado de la pieza activa a la candidata.
; ============================================================

ActivePieceLoadCandidate:
    PHP
    A8

    LDA ACTIVE_PIECE_TYPE
    STA CAND_TYPE
    LDA ACTIVE_PIECE_ROTATION
    STA CAND_ROTATION
    LDA ACTIVE_PIECE_X
    STA CAND_X
    LDA ACTIVE_PIECE_Y
    STA CAND_Y

    PLP
    RTS


; ============================================================
; ActivePieceTryCommit
;
; Si la candidata cabe en el tablero, pasa a ser la pieza
; activa. Si no, la pieza activa no cambia.
; ============================================================

ActivePieceTryCommit:
    PHP
    A8

    JSR ActivePieceFits
    BCC ActivePieceTryCommit_Done

    LDA CAND_TYPE
    STA ACTIVE_PIECE_TYPE
    LDA CAND_ROTATION
    STA ACTIVE_PIECE_ROTATION
    LDA CAND_X
    STA ACTIVE_PIECE_X
    LDA CAND_Y
    STA ACTIVE_PIECE_Y

ActivePieceTryCommit_Done:
    PLP
    RTS


; ============================================================
; ActivePieceFits
;
; Revisa las 4 celdas de la pieza candidata:
;   0 <= CAND_X + dx < BOARD_WIDTH
;   0 <= CAND_Y + dy < BOARD_HEIGHT
;
; X/Y son de 8 bits sin signo: una celda "negativa" da $FF..$FD,
; que es >= al ancho/alto, asi que una sola comparacion sin
; signo cubre los dos bordes. La caja 4x4 puede quedar en X
; negativa (p.ej. la I vertical) mientras sus celdas caben.
;
; Devuelve: carry = 1 cabe, carry = 0 se sale.
; Usa X.
; ============================================================

ActivePieceFits:
    PHP
    AI16

    ; X = tipo*32 + rotacion*8 (igual que DrawActivePiece)
    LDA CAND_TYPE
    AND #$00FF
    ASL
    ASL
    ASL
    ASL
    ASL
    STA CAND_OFFSET

    LDA CAND_ROTATION
    AND #$0003
    ASL
    ASL
    ASL
    CLC
    ADC CAND_OFFSET
    TAX

    A8
    LDA #$04
    STA CAND_COUNT

ActivePieceFits_Loop:
    LDA.w TetrominoRotations,X     ; dx
    CLC
    ADC CAND_X
    CMP #BOARD_WIDTH
    BCS ActivePieceFits_No

    LDA.w TetrominoRotations+1,X   ; dy
    CLC
    ADC CAND_Y
    CMP #BOARD_HEIGHT
    BCS ActivePieceFits_No

    INX
    INX
    DEC CAND_COUNT
    BNE ActivePieceFits_Loop

    PLP                 ; PLP restaura el carry: fijarlo despues
    SEC
    RTS

ActivePieceFits_No:
    PLP
    CLC
    RTS


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
    ; paleta base, sin flip, prioridad 3 (encima del fondo BG1).
    ; ========================================================

    LDA #OBJ_PRIO_3
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