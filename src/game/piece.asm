; ============================================================
; piece.asm
; Logica relacionada con la pieza activa.
; ============================================================


; Posicion en pixeles de la celda (0,0) del tablero.
; NO es el tamano del tablero.
; Debe coincidir con el fondo (assets/Background1-Tetris.png):
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

; Tamano del tablero, en celdas. Ademas de estos limites,
; ActivePieceFits revisa las celdas ocupadas en BOARD
; (game/board.asm).
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
; Una vez calculado X, CAND_OFFSET ya no se usa y sus dos bytes
; sirven para calcular el indice de cada celda en BOARD.
.DEFINE CAND_CELL_X    $0E    ; columna de la celda
.DEFINE CAND_ROW2      $0F    ; fila*2


; ============================================================
; ActivePieceInit
;
; Arranca la secuencia de piezas: llena la primera bolsa, saca
; una pieza como "siguiente" y hace aparecer la primera activa
; (que a su vez saca otra de la bolsa para reemplazar esa
; "siguiente", igual que cualquier spawn posterior).
; ============================================================

ActivePieceInit:
    PHP
    A8

    JSR BagRefill             ; primera bolsa de la partida

    JSR BagDraw
    STA NEXT_PIECE_TYPE
    JSR ActivePieceSpawn

    PLP
    RTS


; ============================================================
; ActivePieceTakeNextType
;
; Devuelve en A (8 bits) el tipo de la pieza que sale ahora y
; deja en NEXT_PIECE_TYPE la que sale despues (sacada de la
; bolsa de 7 piezas).
; ============================================================

ActivePieceTakeNextType:
    PHP
    A8

    LDA NEXT_PIECE_TYPE
    PHA                     ; la que sale ahora

    JSR BagDraw
    STA NEXT_PIECE_TYPE

    PLA
    PLP
    RTS


; ============================================================
; Bolsa de 7 piezas (randomizer)
; ------------------------------------------------------------
; Reparte los 7 tipos de pieza en un orden al azar, pero SIN
; repetir ninguno hasta haber entregado los 7 (asi nunca pasan,
; por ejemplo, 15 piezas seguidas sin una I). Usa el generador
; de engine/random.asm.
; ============================================================

; ------------------------------------------------------------
; BagRefill - llena y revuelve la bolsa (Fisher-Yates)
; ------------------------------------------------------------
; PIECE_BAG queda con los tipos 0-6 en un orden al azar y
; BAG_INDEX vuelve a 0.
; ------------------------------------------------------------
BagRefill:
    PHP
    A8
    I8

    LDX #$00
BagRefill_Fill:
    TXA
    STA PIECE_BAG,X
    INX
    CPX #PIECE_TYPE_COUNT
    BNE BagRefill_Fill

    ; Fisher-Yates: de la ultima posicion (6) a la segunda (1),
    ; cada una se intercambia con una posicion al azar entre la
    ; primera (0) y ella misma, inclusive.
    LDX #$06
BagRefill_Shuffle:
    TXA
    INC A                    ; rango valido: 0..X, o sea X+1 posiciones
    JSR RandomRange           ; A (8 bits) = j, 0 <= j <= X
    TAY

    LDA PIECE_BAG,X
    PHA
    LDA PIECE_BAG,Y
    STA PIECE_BAG,X
    PLA
    STA PIECE_BAG,Y

    DEX
    CPX #$00
    BNE BagRefill_Shuffle

    STZ BAG_INDEX
    PLP
    RTS

; ------------------------------------------------------------
; BagDraw - entrega la siguiente pieza de la bolsa
; ------------------------------------------------------------
; Devuelve en A (8 bits) un tipo 0-6. Si la bolsa ya se repartio
; completa, la rellena y revuelve de nuevo antes de entregar.
; ------------------------------------------------------------
BagDraw:
    PHP
    A8
    I8

    LDA BAG_INDEX
    CMP #PIECE_TYPE_COUNT
    BCC BagDraw_HaveBag
    JSR BagRefill             ; bolsa agotada: rellenar y revolver

BagDraw_HaveBag:
    LDX BAG_INDEX
    LDA PIECE_BAG,X            ; INC de memoria no toca A: el valor queda
    INC BAG_INDEX               ; a salvo mientras avanzamos el indice

    PLP
    RTS


; ============================================================
; ActivePieceSpawn
;
; Saca la siguiente pieza arriba del tablero: rotacion 0, en la
; posicion de inicio.
;
; Si no cabe, el tablero se lleno (game over). Mientras no
; exista la maquina de estados (states.asm) se vacia el tablero
; y se sigue jugando.
; ============================================================

ActivePieceSpawn:
    PHP
    A8

    JSR ActivePieceTakeNextType
    STA ACTIVE_PIECE_TYPE
    STZ ACTIVE_PIECE_ROTATION

    LDA #ACTIVE_PIECE_START_X
    STA ACTIVE_PIECE_X
    LDA #ACTIVE_PIECE_START_Y
    STA ACTIVE_PIECE_Y

    JSR ActivePieceLoadCandidate
    JSR ActivePieceFits
    BCS ActivePieceSpawn_Done

    ; TODO(states.asm): aqui va el game over (y reiniciar
    ; LINES_TOTAL / puntaje para la nueva partida).
    JSR BoardClear
    JSR BoardRender

ActivePieceSpawn_Done:
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
;
; La rotacion siempre queda entre 0 y 3.
; Cada cambio solo se aplica si las 4 celdas de la pieza quedan
; dentro del tablero y libres (ActivePieceFits).
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
    BRA ActivePieceUpdate_CheckA

ActivePieceUpdate_CheckMoveRight:
    CMP #$02
    BNE ActivePieceUpdate_CheckA
    JSR ActivePieceLoadCandidate
    INC CAND_X
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
; Si no puede bajar (toco el suelo o una pieza fija), la pieza
; se fija en el tablero, se borran las filas llenas (bajando lo
; de arriba), se redibujan los bloques fijos y sale la
; siguiente pieza.
; ============================================================

ActivePieceApplyGravity:
    PHP
    A8

    JSR ActivePieceLoadCandidate
    INC CAND_Y
    JSR ActivePieceTryCommit
    BCS ActivePieceApplyGravity_Done

    JSR BoardLockPiece
    JSR BoardClearLines         ; A = lineas borradas (0-4)

    ; Contadores para score.asm (TODO: puntaje por nivel).
    STA LINES_CLEARED_LAST
    A16
    AND #$00FF                  ; el byte alto de A es basura
    CLC
    ADC LINES_TOTAL
    STA LINES_TOTAL
    A8

    JSR BoardRender
    JSR ActivePieceSpawn

ActivePieceApplyGravity_Done:
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
;
; Devuelve: carry = 1 se aplico, carry = 0 no cabia.
; ============================================================

ActivePieceTryCommit:
    PHP
    A8

    JSR ActivePieceFits
    BCC ActivePieceTryCommit_No

    LDA CAND_TYPE
    STA ACTIVE_PIECE_TYPE
    LDA CAND_ROTATION
    STA ACTIVE_PIECE_ROTATION
    LDA CAND_X
    STA ACTIVE_PIECE_X
    LDA CAND_Y
    STA ACTIVE_PIECE_Y

    PLP                 ; PLP restaura el carry: fijarlo despues
    SEC
    RTS

ActivePieceTryCommit_No:
    PLP
    CLC
    RTS


; ============================================================
; ActivePieceFits
;
; Revisa las 4 celdas de la pieza candidata:
;   0 <= CAND_X + dx < BOARD_WIDTH
;   0 <= CAND_Y + dy < BOARD_HEIGHT
;   BOARD[fila*10 + columna] == 0     (celda libre)
;
; X/Y son de 8 bits sin signo: una celda "negativa" da $FF..$FD,
; que es >= al ancho/alto, asi que una sola comparacion sin
; signo cubre los dos bordes. La caja 4x4 puede quedar en X
; negativa (p.ej. la I vertical) mientras sus celdas caben.
;
; Devuelve: carry = 1 cabe, carry = 0 se sale o choca.
; Usa X. Preserva Y.
; ============================================================

ActivePieceFits:
    PHP
    AI16
    PHY

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
    STA CAND_CELL_X

    LDA.w TetrominoRotations+1,X   ; dy
    CLC
    ADC CAND_Y
    CMP #BOARD_HEIGHT
    BCS ActivePieceFits_No

    ; indice = fila*10 + columna (fila*8 + fila*2)
    ASL                            ; fila*2
    STA CAND_ROW2
    ASL
    ASL                            ; fila*8
    CLC
    ADC CAND_ROW2
    CLC
    ADC CAND_CELL_X

    A16
    AND #$00FF
    TAY
    A8
    LDA.w BOARD,Y
    BNE ActivePieceFits_No         ; celda ocupada por una pieza fija

    INX
    INX
    DEC CAND_COUNT
    BNE ActivePieceFits_Loop

    PLY
    PLP                 ; PLP restaura el carry: fijarlo despues
    SEC
    RTS

ActivePieceFits_No:
    PLY
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

; ============================================================
; DrawNextPiece
;
; Dibuja la pieza NEXT_PIECE_TYPE (rotacion 0) centrada en el
; cuadro "NEXT" del HUD, arriba a la derecha.
;
; El interior negro del cuadro en el fondo
; (assets/Background1-Tetris.png) va de x=185..246 e
; y=36..87, con el centro en (216, 62). Como cada pieza tiene
; una caja distinta en la rotacion 0, NextPieceOriginX/Y dan,
; por tipo, el pixel de la celda (0,0) que la deja centrada.
;
; Usa los sprites 4-7 (los 0-3 son de la pieza activa).
; Preserva P, X y Y.
; ============================================================

.DEFINE NEXT_PIECE_SPRITE_BASE 4

DrawNextPiece:
    PHP
    AI16
    PHX
    PHY

    LDA NEXT_PIECE_TYPE
    AND #$00FF
    TAY                     ; Y = tipo (para las tablas por tipo)

    ASL
    ASL
    ASL
    ASL
    ASL                     ; tipo * 32 = rotacion 0 de la pieza
    TAX

    A8

    LDA.w NextPieceOriginX,Y
    STA $00                 ; X en pixeles de la celda (0,0)
    LDA.w NextPieceOriginY,Y
    STA $01                 ; Y en pixeles de la celda (0,0)

    LDA.w PieceTileTable,Y
    STA $05                 ; tile (OamSetSprite no lo toca)
    LDA #OBJ_PRIO_3
    STA $06                 ; atributos

    LDA #$04
    STA $07                 ; quedan 4 bloques
    LDA #NEXT_PIECE_SPRITE_BASE
    STA $08                 ; sprite actual

DrawNextPieceLoop:
    LDA.w TetrominoRotations,X     ; dx
    ASL
    ASL
    ASL                            ; dx * 8
    CLC
    ADC $00
    STA $03

    LDA.w TetrominoRotations+1,X   ; dy
    ASL
    ASL
    ASL                            ; dy * 8
    CLC
    ADC $01
    STA $04

    LDA $08
    STA $02

    JSR OamSetSprite

    INX
    INX
    INC $08
    DEC $07
    BNE DrawNextPieceLoop

    PLY
    PLX
    PLP
    RTS


; Origen (celda 0,0) en pixeles para centrar cada pieza en el
; cuadro NEXT. Orden: I, O, T, S, Z, J, L.
;   I    : 4x1 celdas en (0..3, 1)    -> X=216-16, Y=62-12
;   O    : 2x2 celdas en (1..2, 0..1) -> X=216-16, Y=62-8
;   resto: 3x2 celdas en (0..2, 0..1) -> X=216-12, Y=62-8
NextPieceOriginX:
.db 200, 200, 204, 204, 204, 204, 204
NextPieceOriginY:
.db 50, 54, 54, 54, 54, 54, 54
