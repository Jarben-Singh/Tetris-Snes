; ============================================================
; timing.asm - Temporizacion del juego
; Rol: Input / Infraestructura  (Manuel)
; ------------------------------------------------------------
; La SNES no tiene reloj en segundos: la unica unidad natural es
; el frame (1/60 de segundo en NTSC). Toda la velocidad del juego
; se expresa contando frames.
;
; La gravedad de Tetris es un contador descendente: cada frame se
; resta 1, y cuando llega a 0 la pieza baja una fila y el contador
; se recarga. Subir de nivel = recargar con un numero mas chico.
; ============================================================

; Frames entre caidas para cada nivel (0 a 9).
; Nivel 0: casi un segundo por fila. Nivel 9: 4 frames.
GravityTable:
.db 48, 43, 38, 33, 28, 23, 18, 13, 8, 4

.DEFINE GRAVITY_MAX_LEVEL 9

; ------------------------------------------------------------
; TimingInit - arranca el juego en el nivel 0
; ------------------------------------------------------------
TimingInit:
    PHP
    A8
    LDA #$00
    STA NMI_READY
    LDA.w GravityTable      ; nivel 0 = primer valor de la tabla
    STA GRAVITY_SPEED
    STA GRAVITY_TIMER
    A16
    LDA #$0000
    STA FRAME_COUNTER
    PLP
    RTS

; ------------------------------------------------------------
; TimingSetLevel - cambia la velocidad de caida
; Entrada: A (8 bits) = nivel deseado
; ------------------------------------------------------------
TimingSetLevel:
    PHP
    PHX
    A8
    I16
    CMP #GRAVITY_MAX_LEVEL+1
    BCC TimingLevelOK
    LDA #GRAVITY_MAX_LEVEL  ; topar en el nivel maximo
TimingLevelOK:
    AND #$FF
    TAX
    LDA.w GravityTable,X
    STA GRAVITY_SPEED
    PLX
    PLP
    RTS

; ------------------------------------------------------------
; TimingTickGravity - avanza el reloj de caida un frame
; ------------------------------------------------------------
; Devuelve en A (8 bits):
;   0 = todavia no toca bajar
;   1 = la pieza debe bajar una fila AHORA
;
; Lo llama el bucle principal una vez por frame. La logica de
; que pasa al bajar (colision, fijar pieza) es de game/piece.asm:
; este modulo solo dice cuando.
; ------------------------------------------------------------
TimingTickGravity:
    PHP
    A8
    DEC GRAVITY_TIMER
    BEQ TimingGravityFire
    BMI TimingGravityFire   ; por si quedo en negativo
    LDA #$00
    PLP
    RTS

TimingGravityFire:
    LDA GRAVITY_SPEED
    STA GRAVITY_TIMER       ; recargar el contador
    LDA #$01
    PLP
    RTS

; ------------------------------------------------------------
; WaitFrame - detiene el bucle principal hasta el siguiente frame
; ------------------------------------------------------------
; WAI apaga la CPU hasta que llega una interrupcion. Esto hace
; dos cosas: sincroniza el juego a 60 fps exactos sin importar
; cuanto tarden los calculos, y baja el consumo.
; ------------------------------------------------------------
WaitFrame:
    PHP
    A8
    STZ NMI_READY
WaitFrameLoop:
    WAI                     ; dormir hasta la proxima interrupcion
    LDA NMI_READY
    BEQ WaitFrameLoop       ; si no fue el NMI, seguir durmiendo
    PLP
    RTS
