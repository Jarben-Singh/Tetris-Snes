; ============================================================
; init.asm - Inicializacion del sistema
; Rol: Input / Infraestructura  (Manuel)
; ------------------------------------------------------------
; Al encender, la SNES arranca en "modo emulacion": se comporta
; como un 6502 de 8 bits para ser compatible con el hardware
; viejo. El 65816 completo (registros de 16 bits, banco de datos,
; direccionamiento largo) solo existe en "modo nativo", y hay que
; pedirlo explicitamente. Eso es lo primero que hace SysInit.
;
; Ademas, la RAM y la VRAM arrancan con basura aleatoria. Si no
; se limpian, se ven pixeles sueltos y variables con valores
; imposibles que parecen bugs de logica.
; ============================================================

; ------------------------------------------------------------
; SysInit - pone la consola en un estado conocido
; Llamar como PRIMERA instruccion despues del reset.
; ------------------------------------------------------------
SysInit:
    SEI                     ; sin interrupciones mientras configuramos
    CLC
    XCE                     ; C=0 + XCE => entrar en modo nativo 65816

    AI16
    LDX #$1FFF
    TXS                     ; stack al tope de la RAM baja

    LDA #$0000
    TCD                     ; direct page en $0000

    A8
    PHK
    PLB                     ; banco de datos = banco de programa

    LDA #$8F
    STA INIDISP             ; pantalla apagada (forced blank)
    LDA #$00
    STA NMITIMEN            ; NMI e IRQ apagados por ahora
    RTS

; ------------------------------------------------------------
; ClearWRAM - pone a cero las variables del juego
; Limpia $0000-$1FFF, que es donde viven direct page, el stack
; y nuestros buffers.
; ------------------------------------------------------------
ClearWRAM:
    PHP
    AI16
    LDX #$0000
    LDA #$0000
ClearWRAMLoop:
    STA $0000,X
    INX
    INX
    CPX #$1F00              ; parar antes del stack, que ya usamos
    BNE ClearWRAMLoop
    PLP
    RTS

; ------------------------------------------------------------
; OamBufferInit - esconde los 128 sprites fuera de pantalla
; ------------------------------------------------------------
; Un sprite "apagado" no existe en la SNES: los 128 siempre se
; dibujan. La forma estandar de ocultarlos es mandarlos a Y=224,
; debajo del area visible.
; ------------------------------------------------------------
OamBufferInit:
    PHP
    AI16
    LDX #$0000
OamInitLoop:
    A8
    LDA #$00
    STA OAM_BUFFER,X        ; X del sprite
    INX
    LDA #$E0                ; Y = 224, fuera de la pantalla visible
    STA OAM_BUFFER,X
    INX
    LDA #$00
    STA OAM_BUFFER,X        ; numero de tile
    INX
    STA OAM_BUFFER,X        ; atributos
    INX
    A16
    CPX #$0200              ; 512 bytes = 128 sprites x 4
    BNE OamInitLoop

    ; Tabla alta: 2 bits por sprite (bit de X alta + tamano).
    ; En cero = todos los sprites son chicos (8x8), que es lo que
    ; usan nuestros bloques de tetromino.
    LDX #$0000
    A8
OamInitHiLoop:
    LDA #$00
    STA OAM_BUFFER_HI,X
    INX
    CPX #$0020              ; 32 bytes
    BNE OamInitHiLoop

    LDA #$01
    STA OAM_DIRTY           ; marcar para que el proximo NMI lo mande
    PLP
    RTS

; ------------------------------------------------------------
; OamSetSprite - escribe un sprite en el buffer espejo
; ------------------------------------------------------------
; Entradas (en direct page, 8 bits):
;   $02 = numero de sprite (0-127)
;   $03 = X en pixeles
;   $04 = Y en pixeles
;   $05 = numero de tile
;   $06 = atributos (paleta, prioridad, flip)
;
; Esta es la funcion que usaran Jared y Nicolas para dibujar.
; Nadie deberia escribir a $2104 directamente durante el juego:
; todo pasa por aqui y el NMI se encarga de mandarlo.
; ------------------------------------------------------------
OamSetSprite:
    PHP
    PHX
    AI16
    LDA #$0000
    SEP #$20
    .ACCU 8
    LDA $02
    REP #$20
    .ACCU 16
    AND #$00FF
    ASL
    ASL                     ; indice x 4 (cada sprite ocupa 4 bytes)
    TAX

    A8
    LDA $03
    STA OAM_BUFFER,X        ; X
    INX
    LDA $04
    STA OAM_BUFFER,X        ; Y
    INX
    LDA $05
    STA OAM_BUFFER,X        ; tile
    INX
    LDA $06
    STA OAM_BUFFER,X        ; atributos

    LDA #$01
    STA OAM_DIRTY
    PLX
    PLP
    RTS
