; ============================================================
; score.asm - Puntuacion, nivel y contador de lineas
; ------------------------------------------------------------
; LINES_TOTAL lo actualiza ActivePieceApplyGravity
; (game/piece.asm) con el resultado de BoardClearLines y luego
; llama a ScoreAddLines (puntaje y mejor puntaje) y a
; ScoreUpdateLevel, que sube LEVEL cada 10 lineas.
; DrawScoreCounter, DrawTopScoreCounter, DrawLinesCounter y
; DrawLevelCounter los dibujan en los cuadros "SCORE", "TOP",
; "LINES" y "LEVEL" del HUD.
; ============================================================


; Los dos cuadros comparten X: el interior negro va de x=9 a 70
; (assets/Background1-Tetris.png), con el centro en x=40. Cada
; glifo usa 6 px de ancho dentro de su tile de 8 (el ultimo
; digito deja 2 px vacios a la derecha), y 7 px de alto.

; LINES: interior y=132..159, centro (40, 146). 4 digitos =
; 30 px visibles -> X = 40 - 15 = 25. Y = 146 - 4 = 142.
.DEFINE LINES_COUNTER_X  25
.DEFINE LINES_COUNTER_Y  142
.DEFINE LINES_COUNTER_MAX    9999

; SCORE: interior y=36..63, centro (40, 50). 6 digitos =
; 46 px visibles -> X = 40 - 23 = 17. Y = 50 - 4 = 46.
.DEFINE SCORE_COUNTER_X  17
.DEFINE SCORE_COUNTER_Y  46

; TOP (columna derecha, debajo de NEXT): interior x=185..246,
; y=108..135, centro (216, 122). 6 digitos = 46 px visibles ->
; X = 216 - 23 = 193. Y = 122 - 4 = 118.
.DEFINE TOP_COUNTER_X    193
.DEFINE TOP_COUNTER_Y    118

; LEVEL: interior y=84..111, centro (40, 98). 2 digitos =
; 14 px visibles -> X = 40 - 7 = 33. Y = 98 - 4 = 94.
.DEFINE LEVEL_COUNTER_X  33
.DEFINE LEVEL_COUNTER_Y  94
.DEFINE LEVEL_MAX        99

; Cada cuantas lineas sube el nivel.
.DEFINE LINES_PER_LEVEL  10

; Sprites: 0-3 pieza activa, 4-7 siguiente pieza,
; 8-11 contador de lineas, 12-13 nivel, 14-19 puntaje,
; 20-25 mejor puntaje.
.DEFINE LINES_COUNTER_SPRITE_BASE 8
.DEFINE LEVEL_COUNTER_SPRITE_BASE 12
.DEFINE SCORE_COUNTER_SPRITE_BASE 14
.DEFINE TOP_COUNTER_SPRITE_BASE   20
.DEFINE SCORE_DIGITS              6     ; 3 bytes BCD

; Vueltas que faltan de la suma (nivel + 1) en ScoreAddLines.
.DEFINE SCORE_ADD_COUNT $07

; Puntero (16 bits) al numero BCD que dibuja DrawBcd6.
.DEFINE BCD_PTR $00

; Contador de veces que se resto la potencia de 10 = digito.
; Scratch $07-$08 (16 bits); OamSetSprite solo usa $02-$06.
.DEFINE DIGIT_VALUE $07


; ============================================================
; ScoreUpdateLevel
;
; LEVEL = LINES_TOTAL / 10 (topado en LEVEL_MAX). Si cambio,
; ajusta la velocidad de caida con TimingSetLevel
; (engine/timing.asm), que se topa en su propio nivel maximo.
;
; Solo se llama cuando cambian las lineas, asi que dividir
; restando 10 (a lo mucho ~1000 vueltas) no pesa.
; Preserva P, X y Y.
; ============================================================

ScoreUpdateLevel:
    PHP
    AI16
    PHX

    LDX #$0000                  ; X = cociente (nuevo nivel)
    LDA LINES_TOTAL
ScoreUpdateLevel_Div:
    CMP #LINES_PER_LEVEL
    BCC ScoreUpdateLevel_GotLevel
    SBC #LINES_PER_LEVEL        ; carry = 1 por el CMP
    INX
    BRA ScoreUpdateLevel_Div

ScoreUpdateLevel_GotLevel:
    TXA
    CMP #(LEVEL_MAX + 1)
    BCC ScoreUpdateLevel_InRange
    LDA #LEVEL_MAX
ScoreUpdateLevel_InRange:
    A8
    CMP LEVEL
    BEQ ScoreUpdateLevel_Done   ; mismo nivel: nada que cambiar
    STA LEVEL
    JSR TimingSetLevel          ; A (8 bits) = nivel -> velocidad

ScoreUpdateLevel_Done:
    PLX
    PLP
    RTS


; ============================================================
; ScoreAddLines
;
; Suma al puntaje lo que vale borrar A lineas (8 bits, 0-4),
; con el sistema clasico de NES:
;
;   1 linea  (single):   40 x (nivel + 1)
;   2 lineas (double):  100 x (nivel + 1)
;   3 lineas (triple):  300 x (nivel + 1)
;   4 lineas (tetris): 1200 x (nivel + 1)
;
; El puntaje esta en BCD, asi que la multiplicacion se hace
; sumando el valor base (nivel + 1) veces en modo decimal (SED):
; el ADC del 65816 ya ajusta cada nibble a 0-9. Son a lo mucho
; 100 vueltas y solo cuando se borran lineas.
; Si pasa de 999999 se queda en 999999.
;
; Al final actualiza TOP_SCORE si se supero (ScoreUpdateTop).
;
; Llamar ANTES de ScoreUpdateLevel: cuenta el nivel en el que
; se borraron las lineas. Preserva P, X y Y.
; ============================================================

ScoreAddLines:
    PHP
    AI16
    PHX

    A8
    CMP #$00
    BEQ ScoreAddLines_Done      ; 0 lineas: no suma nada

    DEC A
    ASL                         ; (lineas - 1) * 2 = indice en la tabla
    A16
    AND #$00FF
    TAX

    A8
    LDA LEVEL
    INC A
    STA SCORE_ADD_COUNT         ; nivel + 1 (LEVEL <= 99)

    SED                         ; ADC en decimal (BCD)
ScoreAddLines_Loop:
    A16
    LDA SCORE
    CLC
    ADC.w LineClearPointsBcd,X  ; digitos 1-4
    STA SCORE
    A8
    LDA SCORE+2
    ADC #$00                    ; acarreo a los digitos 5-6
    STA SCORE+2
    BCS ScoreAddLines_Max       ; se paso de 999999
    DEC SCORE_ADD_COUNT
    BNE ScoreAddLines_Loop
    BRA ScoreAddLines_Done

ScoreAddLines_Max:
    A16
    LDA #$9999
    STA SCORE
    A8
    LDA #$99
    STA SCORE+2

ScoreAddLines_Done:
    CLD                         ; de vuelta a binario
    JSR ScoreUpdateTop
    PLX
    PLP
    RTS

; Puntos base por lineas borradas, en BCD: 1, 2, 3 y 4 lineas.
LineClearPointsBcd:
.dw $0040, $0100, $0300, $1200


; ============================================================
; ScoreUpdateTop
;
; Si SCORE > TOP_SCORE, copia SCORE a TOP_SCORE y lo guarda en
; SRAM (engine/sram.asm). Asi el cuadro TOP sube en vivo cuando
; se rompe el record y el record sobrevive al apagar.
;
; En BCD cada digito ocupa su nibble en orden, asi que comparar
; como binario sin signo da el mismo resultado que comparar los
; numeros decimales. Se compara de la parte alta a la baja:
; primero los bytes 1-2 (digitos 3-6), luego el byte 0.
; Preserva P.
; ============================================================

ScoreUpdateTop:
    PHP
    A16
    LDA SCORE+1
    CMP TOP_SCORE+1
    BCC ScoreUpdateTop_Done     ; menor en la parte alta
    BNE ScoreUpdateTop_Copy     ; mayor en la parte alta
    A8
    LDA SCORE
    CMP TOP_SCORE
    BCC ScoreUpdateTop_Done
    BEQ ScoreUpdateTop_Done     ; igual: nada que copiar

ScoreUpdateTop_Copy:
    A16
    LDA SCORE
    STA TOP_SCORE               ; bytes 0-1
    A8
    LDA SCORE+2
    STA TOP_SCORE+2             ; byte 2
    JSR SramSaveTopScore        ; que sobreviva al apagar

ScoreUpdateTop_Done:
    PLP
    RTS


; ============================================================
; ScoreReset
;
; Vuelve a 0 el puntaje, las lineas y el nivel para una partida nueva, y
; regresa la velocidad de caida a la del nivel 0. Los HUD se
; actualizan solos en el siguiente frame (DrawLinesCounter y
; DrawLevelCounter leen estas variables cada frame).
; Preserva P.
; ============================================================

ScoreReset:
    PHP
    A16
    STZ LINES_TOTAL
    STZ SCORE                   ; digitos 1-4
    A8
    STZ SCORE+2                 ; digitos 5-6
    STZ LINES_CLEARED_LAST
    STZ LEVEL
    LDA #$00
    JSR TimingSetLevel          ; velocidad del nivel 0
    PLP
    RTS


; ============================================================
; DrawLinesCounter / DrawLevelCounter
;
; Dibujan LINES_TOTAL (4 digitos) y LEVEL (2 digitos) con
; ceros a la izquierda. Preservan P, X y Y.
; ============================================================

DrawLinesCounter:
    PHP
    AI16
    PHX
    PHY

    LDA LINES_TOTAL
    CMP #(LINES_COUNTER_MAX + 1)
    BCC DrawLinesCounter_InRange
    LDA #LINES_COUNTER_MAX
DrawLinesCounter_InRange:
    TAY
    A8
    LDA #LINES_COUNTER_SPRITE_BASE
    STA $02
    LDA #LINES_COUNTER_X
    STA $03
    LDA #LINES_COUNTER_Y
    STA $04
    LDX #DECIMAL_4_DIGITS
    JSR DrawDecimal

    PLY
    PLX
    PLP
    RTS


DrawLevelCounter:
    PHP
    AI16
    PHX
    PHY

    LDA LEVEL                   ; LEVEL ya esta topado en 99
    AND #$00FF
    TAY
    A8
    LDA #LEVEL_COUNTER_SPRITE_BASE
    STA $02
    LDA #LEVEL_COUNTER_X
    STA $03
    LDA #LEVEL_COUNTER_Y
    STA $04
    LDX #DECIMAL_2_DIGITS
    JSR DrawDecimal

    PLY
    PLX
    PLP
    RTS


; ============================================================
; DrawScoreCounter / DrawTopScoreCounter
;
; Dibujan SCORE y TOP_SCORE (6 digitos BCD, con ceros a la
; izquierda) en los cuadros SCORE y TOP. Preservan P, X y Y.
; ============================================================

DrawScoreCounter:
    PHP
    AI16
    PHX
    PHY
    LDA #SCORE
    STA BCD_PTR
    A8
    LDA #SCORE_COUNTER_SPRITE_BASE
    STA $02
    LDA #SCORE_COUNTER_X
    STA $03
    LDA #SCORE_COUNTER_Y
    STA $04
    JSR DrawBcd6
    PLY
    PLX
    PLP
    RTS

DrawTopScoreCounter:
    PHP
    AI16
    PHX
    PHY
    LDA #TOP_SCORE
    STA BCD_PTR
    A8
    LDA #TOP_COUNTER_SPRITE_BASE
    STA $02
    LDA #TOP_COUNTER_X
    STA $03
    LDA #TOP_COUNTER_Y
    STA $04
    JSR DrawBcd6
    PLY
    PLX
    PLP
    RTS


; ============================================================
; DrawBcd6
;
; Dibuja un numero BCD de 3 bytes (6 digitos). Como ya esta en
; BCD no hay que convertir: cada nibble es un digito. Va del
; byte mas alto al mas bajo, primero el nibble alto y luego el
; bajo de cada uno.
;
; Entrada (A 8 bits, X/Y 16 bits):
;   BCD_PTR = direccion del byte bajo del numero
;   $02 = primer sprite, $03 = X en pantalla, $04 = Y
; Modifica A, Y, $02-$06.
; ============================================================

DrawBcd6:
    LDA #OBJ_PRIO_3
    STA $06

    LDY #(SCORE_DIGITS / 2 - 1)  ; Y = byte actual (2, 1, 0)

DrawBcd6_Byte:
    LDA (BCD_PTR),Y
    LSR
    LSR
    LSR
    LSR                         ; nibble alto
    JSR DrawScoreDigit

    LDA (BCD_PTR),Y
    AND #$0F                    ; nibble bajo
    JSR DrawScoreDigit

    DEY
    BPL DrawBcd6_Byte           ; hasta pasar del byte 0
    RTS

; A (8 bits) = digito 0-9. Dibuja el sprite $02 en ($03, $04)
; y avanza al siguiente sprite, 8 px a la derecha.
DrawScoreDigit:
    CLC
    ADC #HUD_DIGIT_TILE_BASE
    STA $05
    JSR OamSetSprite
    LDA $03
    CLC
    ADC #$08
    STA $03
    INC $02
    RTS


; ============================================================
; DrawDecimal
;
; Dibuja un numero en decimal, un sprite por digito, de
; izquierda a derecha, con los tiles de LoadHudDigits
; (engine/ppu.asm). Cada digito se saca restando la potencia
; de 10 que le toca tantas veces como quepa.
;
; Entrada (A 8 bits, X/Y 16 bits):
;   Y   = valor (debe caber en los digitos pedidos)
;   X   = DECIMAL_n_DIGITS: por cual potencia de 10 empezar
;   $02 = primer sprite, $03 = X en pantalla, $04 = Y
; Modifica A, X, Y, $02-$08.
; ============================================================

; Indice en DecimalPowers (2 bytes por entrada) donde empieza
; un numero de n digitos.
.DEFINE DECIMAL_4_DIGITS 0      ; 1000, 100, 10, 1
.DEFINE DECIMAL_2_DIGITS 4      ; 10, 1
.DEFINE DECIMAL_POWERS_END 8    ; 4 entradas x 2 bytes

DrawDecimal:
    LDA #OBJ_PRIO_3
    STA $06                     ; atributos: paleta 0, encima de todo

DrawDecimal_Digit:
    A16
    STZ DIGIT_VALUE
    TYA
DrawDecimal_Sub:
    CMP.w DecimalPowers,X
    BCC DrawDecimal_GotDigit
    SEC
    SBC.w DecimalPowers,X
    INC DIGIT_VALUE
    BRA DrawDecimal_Sub

DrawDecimal_GotDigit:
    TAY                         ; resto para el siguiente digito
    A8
    LDA DIGIT_VALUE
    CLC
    ADC #HUD_DIGIT_TILE_BASE
    STA $05                     ; tile del digito

    JSR OamSetSprite            ; preserva X y P, no toca Y

    LDA $03
    CLC
    ADC #$08
    STA $03                     ; siguiente digito, 8 px a la derecha
    INC $02                     ; siguiente sprite

    INX
    INX
    CPX #DECIMAL_POWERS_END
    BNE DrawDecimal_Digit
    RTS


; Potencias de 10, de la mas alta a la mas baja; una por digito.
DecimalPowers:
.dw 1000, 100, 10, 1
