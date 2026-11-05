; ============================================================
; ProyectoTetris - main.asm
; Prueba de compilación base con WLA-DX para SNES (65816)
; Objetivo: verificar que el toolchain compila y arma un ROM
;           válido. Solo pone un color de fondo en pantalla.
; ============================================================

.INCLUDE "header.asm"

; --- Infraestructura (Manuel) -------------------------------
.INCLUDE "../include/hardware.inc"
.INCLUDE "../include/ram_map.inc"
.INCLUDE "../include/macros.inc"

.BANK 0 SLOT 0
.ORG 0
.SECTION "MainCode"

; ------------------------------------------------------------
; Handlers vacíos (por ahora no usamos COP/BRK/ABORT/IRQ)
; ------------------------------------------------------------
EmptyHandler:
    RTI

; ------------------------------------------------------------
; Rutina de VBlank (NMI) - por ahora vacía, solo confirma
; que la interrupción no rompe nada
; ------------------------------------------------------------
VBlank:
    JMP VBlankHandler

; ------------------------------------------------------------
; Punto de entrada
; ------------------------------------------------------------
Start:
    SEI                 ; deshabilitar interrupciones IRQ
    CLC
    XCE                 ; entrar en modo nativo 65816

    REP #$18            ; A y X/Y a 16 bits, modo decimal off
    .ACCU 16
    .INDEX 16

    LDX #$1FFF
    TXS                 ; inicializar stack pointer

    ; --------------------------------------------------------
    ; La WRAM arranca con basura: si no se limpia, variables
    ; como OAM_DIRTY tienen valores aleatorios y el NMI manda
    ; un buffer de OAM lleno de basura a la pantalla.
    ; --------------------------------------------------------
    JSR ClearWRAM

    ; --------------------------------------------------------
    ; Apagar la pantalla mientras inicializamos
    ; --------------------------------------------------------
    SEP #$20
    .ACCU 8
    LDA #$8F            ; forced blank, brillo 0
    STA $2100           ; INIDISP

    LDA #$00
    STA $4200           ; NMITIMEN - deshabilitar NMI por ahora

    ; --------------------------------------------------------
    ; Limpiar VRAM completa (evita basura al encender)
    ; VRAM son 64KB = 0x8000 words; cada STZ de 16 bits a
    ; $2118 escribe un word completo (low->$2118, high->$2119)
    ; y el puerto autoincrementa la dirección.
    ; --------------------------------------------------------
    SEP #$20
    .ACCU 8
    LDA #$80
    STA $2115           ; VMAIN: incrementar tras escribir high byte ($2119)
    REP #$20
    .ACCU 16
    LDA #$0000
    STA $2116           ; VMADD = 0 (16 bits, cubre $2116/$2117)

    LDX #$8000          ; 0x8000 words = 64KB
ClearVRAMLoop:
    STZ $2118
    DEX
    BNE ClearVRAMLoop

    ; --------------------------------------------------------
    ; Limpiar CGRAM (paletas) a 0
    ; OJO: a diferencia de VRAM ($2118/$2119, que SÍ son dos
    ; registros distintos y consecutivos), CGDATA ($2122) es
    ; UN SOLO registro que se escribe dos veces seguidas (low,
    ; luego high) para completar un color. Una escritura de 16
    ; bits aquí escribiría por error en $2123 (otro registro,
    ; W12SEL), así que esto debe hacerse en modo de 8 bits.
    ; 256 colores x 2 bytes = 512 escrituras de 1 byte.
    ; --------------------------------------------------------
    SEP #$20
    .ACCU 8
    LDA #$00
    STA $2121           ; CGADD = 0
    LDX #$0200          ; 512 bytes (256 colores x 2 bytes)
ClearCGRAMLoop:
    STZ $2122
    DEX
    BNE ClearCGRAMLoop

    ; --------------------------------------------------------
    ; Poner un color de fondo (backdrop) visible como prueba
    ; Color índice 0 de CGRAM = color de fondo cuando no hay
    ; capas encima. Lo ponemos en azul para confirmar que
    ; la PPU está viva.
    ; --------------------------------------------------------
    SEP #$20
    .ACCU 8
    LDA #$00
    STA $2121           ; CGADD = 0 (color de backdrop)
    ; Formato BGR555: bits 0-4=rojo, 5-9=verde, 10-14=azul
    ; Azul puro (31) => valor = 0x7C00
    LDA #$00            ; low byte
    STA $2122
    LDA #$7C            ; high byte
    STA $2122

    ; --------------------------------------------------------
    ; DMA: transferir los tiles de las piezas a VRAM
    ; Los ponemos en la dirección word $0000, que coincide con
    ; "name base" = 0 que configuraremos en OBSEL más abajo.
    ; Canal DMA 0, modo 1 (2 registros, 1 escritura c/u,
    ; alternando) hacia VMDATAL/VMDATAH ($2118/$2119).
    ; --------------------------------------------------------
    LDA #$00
    STA $2116           ; VMADDL = 0
    STA $2117           ; VMADDH = 0
    LDA #$80
    STA $2115           ; VMAIN: incrementar tras escribir high byte

    LDA #$01
    STA $4300           ; DMAP0: modo 1
    LDA #$18
    STA $4301           ; BBAD0: destino = $2118 (VMDATAL)

    REP #$20
    .ACCU 16
    LDA #TetrisPieces_til
    STA $4302           ; A1T0L/H: dirección origen (16 bits)
    SEP #$20
    .ACCU 8
    LDA #:TetrisPieces_til
    STA $4304           ; A1B0: banco de origen

    REP #$20
    .ACCU 16
    LDA #(TetrisPieces_tilend-TetrisPieces_til)
    STA $4305           ; DAS0L/H: tamaño de la transferencia

    SEP #$20
    .ACCU 8
    LDA #$01
    STA $420B           ; MDMAEN: disparar canal 0

    ; --------------------------------------------------------
    ; DMA: transferir la paleta a CGRAM
    ; Las paletas de sprites ocupan las entradas 128-255 de
    ; CGRAM. La primera paleta de sprite (paleta 0 de OBJ)
    ; empieza en la entrada 128 ($80).
    ; Modo 0 (1 registro, 1 escritura) hacia CGDATA ($2122).
    ; --------------------------------------------------------
    LDA #$80
    STA $2121           ; CGADD = 128 (primera paleta de sprite)

    LDA #$00
    STA $4300           ; DMAP0: modo 0
    LDA #$22
    STA $4301           ; BBAD0: destino = $2122 (CGDATA)

    REP #$20
    .ACCU 16
    LDA #TetrisPieces_pal
    STA $4302
    SEP #$20
    .ACCU 8
    LDA #:TetrisPieces_pal
    STA $4304

    REP #$20
    .ACCU 16
    LDA #(TetrisPieces_palend-TetrisPieces_pal)
    STA $4305

    SEP #$20
    .ACCU 8
    LDA #$01
    STA $420B           ; disparar canal 0 otra vez

    ; --------------------------------------------------------
    ; OBSEL: tamaño de sprite = 8x8 (chico) / 16x16 (grande).
    ; Como ahora TODOS nuestros diseños son de 8x8, vamos a usar
    ; siempre el tamaño "chico" (size bit = 0 en OAM), así que
    ; esta selección 0..7 no importa demasiado, pero la dejamos
    ; en 0 (8x8/16x16) por si luego necesitas piezas grandes.
    ; name select = 0, name base = 0 (coincide con el DMA de
    ; arriba, que puso los tiles en word $0000 de VRAM)
    ; --------------------------------------------------------
    LDA #$00
    STA $2101

    ; --------------------------------------------------------
    ; Esconder los 128 sprites en el buffer espejo de OAM.
    ; Todo el dibujo de sprites pasa por OAM_BUFFER (con
    ; OamSetSprite) y el NMI lo manda a la OAM real.
    ; --------------------------------------------------------
    JSR OamBufferInit

    ; --------------------------------------------------------
    ; Construir las 7 piezas (I,O,T,S,Z,J,L) con 4 sprites de
    ; 8x8 cada una (28 sprites en total). Cada bloque se coloca en:
    ;   X = OrigenX[pieza] + dx*8      Y = OrigenY[pieza] + dy*8
    ; con (dx,dy) tomado de PieceShapes. Solo prueba visual: sin
    ; movimiento, rotación ni lógica de juego.
    ; Temporales en direct page: $00 = pieza, $01 = bloques
    ; restantes, $08 = sprite actual ($02-$06 = entradas de
    ; OamSetSprite). X/Y en 16 bits, como pide OamSetSprite.
    ; Empieza en el sprite 4: los sprites 0-3 son de la pieza
    ; activa (ACTIVE_PIECE_SPRITE_BASE en game/piece.asm).
    ; --------------------------------------------------------
    STZ $00             ; pieza actual = 0
    LDA #$04
    STA $08             ; sprite actual = 4
    LDX #$0000          ; X = índice en PieceShapes (2 bytes por bloque)
BuildPieceLoop:
    LDA #$04
    STA $01             ; 4 bloques por pieza
    REP #$20
    .ACCU 16
    LDA $00
    AND #$00FF
    TAY                 ; Y = pieza actual
    SEP #$20
    .ACCU 8
BuildBlockLoop:
    LDA.w PieceShapes,X     ; dx (en celdas)
    ASL
    ASL
    ASL                     ; dx * 8 píxeles
    CLC
    ADC.w PieceOriginX,Y
    STA $03                 ; X del sprite

    LDA.w PieceShapes+1,X   ; dy (en celdas)
    ASL
    ASL
    ASL
    CLC
    ADC.w PieceOriginY,Y
    STA $04                 ; Y del sprite

    LDA.w PieceTileTable,Y
    STA $05                 ; tile (color) de la pieza
    STZ $06                 ; atributos: paleta 0, sin flip/prioridad

    LDA $08
    STA $02                 ; número de sprite
    JSR OamSetSprite
    INC $08

    INX
    INX
    DEC $01
    BNE BuildBlockLoop

    INC $00
    LDA $00
    CMP #$07
    BNE BuildPieceLoop

    ; --------------------------------------------------------
    ; Mandar el buffer a la OAM ya, mientras la pantalla sigue
    ; apagada (forced blank), para que el primer frame no
    ; muestre lo que haya quedado en la OAM real.
    ; --------------------------------------------------------
    JSR OamFlush
    STZ OAM_DIRTY

    ; --------------------------------------------------------
    ; Configurar modo de fondo simple (modo 1) y activar
    ; la capa de sprites (OBJ) además del backdrop
    ; --------------------------------------------------------
    LDA #$01
    STA $2105           ; BGMODE = modo 1

    LDA #$10
    STA $212C           ; TM: bit4 = activar capa OBJ

    ; --------------------------------------------------------
    ; Encender pantalla con brillo máximo
    ; --------------------------------------------------------
    LDA #$0F            ; brillo completo, sin forced blank
    STA $2100

    ; --------------------------------------------------------
    ; Infraestructura: input + temporizacion  (Manuel)
    ; --------------------------------------------------------
    JSR InputInit
    JSR TimingInit

    ; --------------------------------------------------------
    ; Logica de piezas
    ; --------------------------------------------------------
    JSR ActivePieceInit

    ; Habilitar NMI (bit7) + lectura automatica del control (bit0)
    LDA #$81
    STA NMITIMEN

    CLI                 ; habilitar interrupciones

    ; --------------------------------------------------------
    ; Bucle principal: una vuelta por frame.
    ; El NMI ya leyó el control; aquí se actualiza la pieza
    ; y se dibuja en el buffer de OAM (el siguiente NMI lo
    ; manda a la pantalla).
    ; --------------------------------------------------------
MainLoop:
    JSR WaitFrame       ; esperar al siguiente frame
    JSR ActivePieceUpdate
    JSR DrawActivePiece
    SEP #$20            ; DrawActivePiece no restaura P:
    .ACCU 8             ; deja A en 8 bits y X/Y en 16
    REP #$10
    .INDEX 16
    JMP MainLoop

; ------------------------------------------------------------
; Tablas de las piezas. Orden: I, O, T, S, Z, J, L
; PieceShapes: 4 pares (dx,dy) en celdas de 8x8 por pieza.
; PieceTileTable: tile del bloque de cada pieza. Ajústala si el
; color no coincide con la pieza esperada.
; ------------------------------------------------------------
PieceShapes:
.db 0,0, 1,0, 2,0, 3,0      ; I
.db 0,0, 1,0, 0,1, 1,1      ; O
.db 1,0, 0,1, 1,1, 2,1      ; T
.db 1,0, 2,0, 0,1, 1,1      ; S
.db 0,0, 1,0, 1,1, 2,1      ; Z
.db 0,0, 0,1, 1,1, 2,1      ; J
.db 2,0, 0,1, 1,1, 2,1      ; L

PieceOriginX:
.db 16, 72, 112, 160, 40, 96, 152

PieceOriginY:
.db 64, 64, 64, 64, 128, 128, 128

PieceTileTable:
.db 0, 1, 2, 3, 4, 5, 6


; ------------------------------------------------------------
; Modulos de infraestructura (Manuel)
; ------------------------------------------------------------

.INCLUDE "core/init.asm"
.INCLUDE "core/nmi.asm"
.INCLUDE "core/irq.asm"
.INCLUDE "engine/timing.asm"
.INCLUDE "game/input.asm"


; ------------------------------------------------------------
; Datos y logica de piezas
; ------------------------------------------------------------

.INCLUDE "data/tables.asm"
.INCLUDE "game/piece.asm"


.ENDS


; ------------------------------------------------------------
; Datos graficos (generados por gfx4snes)
; ------------------------------------------------------------

.BANK 1 SLOT 0
.ORG 0
.SECTION "GraphicsData"

.INCLUDE "data/TetrisPieces_data.as"

.ENDS