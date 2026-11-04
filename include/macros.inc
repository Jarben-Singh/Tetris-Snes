; ============================================================
; macros.inc - Macros reutilizables
; Rol: Input / Infraestructura
; ------------------------------------------------------------
; El 65816 puede tratar A, X e Y como registros de 8 o de 16
; bits, y se cambia en tiempo de ejecucion con SEP/REP. El
; problema es que el ensamblador tambien necesita saberlo, con
; .ACCU / .INDEX, para elegir cuantos bytes ocupa un inmediato.
; Olvidar uno de los dos es LA fuente clasica de bugs en 65816:
; el codigo ensambla sin error y la ROM se cuelga.
;
; Estas macros atan las dos cosas, asi no se pueden desincronizar.
; ============================================================

.MACRO A8           ; acumulador a 8 bits
    SEP #$20
    .ACCU 8
.ENDM

.MACRO A16          ; acumulador a 16 bits
    REP #$20
    .ACCU 16
.ENDM

.MACRO I8           ; indices X/Y a 8 bits
    SEP #$10
    .INDEX 8
.ENDM

.MACRO I16          ; indices X/Y a 16 bits
    REP #$10
    .INDEX 16
.ENDM

.MACRO AI8          ; todo a 8 bits
    SEP #$30
    .ACCU 8
    .INDEX 8
.ENDM

.MACRO AI16         ; todo a 16 bits
    REP #$30
    .ACCU 16
    .INDEX 16
.ENDM
