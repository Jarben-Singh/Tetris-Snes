; ============================================================
; nmi.asm - Rutina de interrupcion NMI (V-Blank)
; Rol: Input / Infraestructura  (Manuel)
; ------------------------------------------------------------
; La PPU dibuja la pantalla de arriba hacia abajo 60 veces por
; segundo. Al terminar, hay una pausa corta (V-Blank) antes de
; volver a empezar: es el UNICO momento del frame en que se
; puede escribir a VRAM, CGRAM y OAM sin que salga basura.
;
; El hardware avisa de ese momento disparando el NMI. Por eso el
; NMI es el latido del juego: todo lo que tenga que ver con
; "una vez por frame" cuelga de aqui.
;
; Regla de oro: el NMI debe ser CORTO. El V-Blank dura muy poco
; (~ 1/15 del frame). Si nos pasamos, la escritura se corta a la
; mitad y se ven glitches. Por eso aqui NO va logica de juego:
; solo transferencias y lectura de control. Los calculos van en
; el bucle principal.
; ============================================================

VBlankHandler:
    ; --- Guardar TODO el contexto ---
    ; Una interrupcion puede caer en cualquier instruccion. Si
    ; modificamos A, X, Y o las banderas sin restaurarlos, el
    ; codigo interrumpido continua con valores corruptos y el bug
    ; aparece en un lugar que no tiene nada que ver.
    PHP
    PHB                     ; banco de datos

    ; Guardar A, X, Y siempre en 16 bits: al final se restauran
    ; en 16 bits, y si aqui se guardaran en 8, el stack quedaria
    ; desfasado y el RTI regresaria a una direccion basura.
    AI16
    PHA
    PHX
    PHY

    PHD                     ; direct page
    LDA #$0000
    TCD                     ; forzar direct page = 0, por si acaso
    A8
    PHK
    PLB                     ; banco de datos = banco de programa

    ; --- Limpiar la bandera de NMI ---
    ; Leer RDNMI es obligatorio: si no, el hardware cree que no
    ; atendimos la interrupcion.
    LDA RDNMI

    ; --- Mandar los sprites por DMA ---
    ; Esto va PRIMERO porque es lo que mas urge que ocurra dentro
    ; del V-Blank. El resto puede esperar.
    LDA OAM_DIRTY
    BEQ VBlank_SkipOAM
    JSR OamFlush
    STZ OAM_DIRTY

VBlank_SkipOAM:
    ; --- Leer el control ---
    JSR InputUpdate

    ; --- Avanzar el reloj del juego ---
    A16
    INC FRAME_COUNTER
    A8
    LDA #$01
    STA NMI_READY           ; avisa al bucle principal: hay frame nuevo

    ; --- Restaurar el contexto exactamente al reves ---
    AI16
    PLD
    PLY
    PLX
    PLA
    PLB
    PLP
    RTI

; ------------------------------------------------------------
; OamFlush - copia el buffer espejo de OAM a la OAM real por DMA
; ------------------------------------------------------------
; Por DMA porque es ~5 veces mas rapido que un bucle de escrituras:
; 544 bytes con STA no caben en un V-Blank, por DMA si.
; ------------------------------------------------------------
OamFlush:
    PHP
    A8
    LDX #$0000
    STX OAMADDL             ; empezar desde el sprite 0

    LDA #$00
    STA DMAP0               ; modo 0: 1 registro, escrituras seguidas
    LDA #$04
    STA BBAD0               ; destino = $2104 (OAMDATA)

    A16
    LDA #OAM_BUFFER
    STA A1T0L               ; origen: nuestro buffer en RAM
    A8
    LDA #$00
    STA A1B0                ; banco 0 (WRAM baja)

    A16
    LDA #OAM_BUFFER_SIZE
    STA DAS0L               ; 544 bytes
    A8

    LDA #$01
    STA MDMAEN              ; disparar canal 0
    PLP
    RTS
