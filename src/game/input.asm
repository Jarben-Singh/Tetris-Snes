; ============================================================
; input.asm - Lectura y procesamiento del control
; Rol: Input / Infraestructura  (Manuel)
; ------------------------------------------------------------
; La SNES puede leer el control sola: si en NMITIMEN activamos
; el bit 0, el hardware lee los dos controles al empezar cada
; V-Blank y deja el resultado en $4218/$4219. Nosotros solo
; tenemos que esperar a que termine y copiar el valor.
;
; Leer el valor crudo no alcanza para un juego. Tetris necesita
; distinguir tres cosas distintas:
;   HELD     -> el boton esta abajo (para mantener la caida rapida)
;   PRESSED  -> se acaba de presionar este frame (para rotar una
;               sola vez aunque dejes el boton apretado)
;   RELEASED -> se acaba de soltar
;
; Eso se llama deteccion de flancos y se calcula comparando el
; estado de este frame contra el del frame anterior:
;   PRESSED  = actual AND (NOT anterior)
;   RELEASED = anterior AND (NOT actual)
; ============================================================

; ------------------------------------------------------------
; InputInit - deja el estado del control en limpio.
; Llamar una sola vez, antes de habilitar el NMI.
; ------------------------------------------------------------
InputInit:
    PHP
    AI16
    LDA #$0000
    STA PAD1_HELD
    STA PAD1_PREV
    STA PAD1_PRESSED
    STA PAD1_RELEASED
    A8
    STZ DAS_TIMER
    STZ DAS_DIR
    PLP
    RTS

; ------------------------------------------------------------
; InputUpdate - lee el control y calcula los flancos.
; Se llama UNA vez por frame, desde el NMI.
; Destruye: nada (guarda y restaura A, X, Y y el status)
; ------------------------------------------------------------
InputUpdate:
    PHP
    A16                     ; guardar A siempre en 16 bits: el PLA del
    PHA                     ; final corre en 16 y debe sacar lo mismo
    PHX

    ; --- Esperar a que el hardware termine de leer el control ---
    ; HVBJOY bit 0 vale 1 mientras la lectura automatica esta en
    ; curso (dura unos 3 scanlines). Si leemos antes, obtenemos
    ; datos a medio formar.
    A8
InputWaitAuto:
    LDA HVBJOY
    AND #$01
    BNE InputWaitAuto

    ; --- Guardar el estado anterior y leer el nuevo ---
    A16
    LDA PAD1_HELD
    STA PAD1_PREV           ; lo de este frame pasa a ser "lo anterior"

    LDA JOY1L               ; lectura de 16 bits: toma $4218 y $4219
    STA PAD1_HELD

    ; --- PRESSED = actual AND (NOT anterior) ---
    ; EOR #$FFFF invierte todos los bits: es el NOT del 65816,
    ; que no tiene una instruccion NOT dedicada.
    LDA PAD1_PREV
    EOR #$FFFF
    AND PAD1_HELD
    STA PAD1_PRESSED

    ; --- RELEASED = anterior AND (NOT actual) ---
    LDA PAD1_HELD
    EOR #$FFFF
    AND PAD1_PREV
    STA PAD1_RELEASED

    PLX
    PLA
    PLP
    RTS

; ------------------------------------------------------------
; InputDAS - auto-repeat lateral (Delayed Auto Shift)
; ------------------------------------------------------------
; Sin esto, mover una pieza 5 columnas obliga a dar 5 toques.
; Con esto: el primer toque mueve de inmediato, y si mantienes
; la direccion, tras DAS_DELAY frames empieza a repetir cada
; DAS_RATE frames. Es exactamente como se siente el Tetris real.
;
; Devuelve en A (8 bits):
;   0 = no mover,  1 = mover izquierda,  2 = mover derecha
; ------------------------------------------------------------
.DEFINE DAS_DELAY   16      ; frames antes de empezar a repetir
.DEFINE DAS_RATE     6      ; frames entre repeticiones

InputDAS:
    PHP
    A16

    ; Toque nuevo a la izquierda: mover ya y arrancar el contador
    LDA PAD1_PRESSED
    AND #BTN_LEFT
    BEQ InputDAS_CheckRightNew
    A8
    LDA #DAS_DELAY
    STA DAS_TIMER
    LDA #$01
    STA DAS_DIR
    PLP
    RTS

InputDAS_CheckRightNew:
    ; Re-afirmar A16: el ensamblador lleva el tamano de A en orden
    ; de TEXTO, no de ejecucion. El A8 de la rama anterior lo dejo
    ; marcado como 8 bits aunque en runtime aqui es de 16.
    A16
    LDA PAD1_PRESSED
    AND #BTN_RIGHT
    BEQ InputDAS_CheckHeld
    A8
    LDA #DAS_DELAY
    STA DAS_TIMER
    LDA #$02
    STA DAS_DIR
    PLP
    RTS

InputDAS_CheckHeld:
    ; No hubo toque nuevo. Ver si siguen manteniendo la direccion.
    A16
    LDA PAD1_HELD
    AND #BTN_LEFTRIGHT
    BNE InputDAS_Repeat

    ; Soltaron: apagar el repetidor
    A8
    STZ DAS_DIR
    STZ DAS_TIMER
    LDA #$00
    PLP
    RTS

InputDAS_Repeat:
    A8
    .ACCU 8
    LDA DAS_TIMER
    BEQ InputDAS_Fire       ; llego a 0 -> toca repetir
    DEC DAS_TIMER
    LDA #$00                ; todavia no
    PLP
    RTS

InputDAS_Fire:
    LDA #DAS_RATE
    STA DAS_TIMER           ; recargar para la siguiente repeticion
    LDA DAS_DIR             ; devolver la direccion activa
    PLP
    RTS
