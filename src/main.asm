; ============================================================
; ProyectoTetris - main.asm
; Prueba de compilación base con WLA-DX para SNES (65816)
; Objetivo: verificar que el toolchain compila y arma un ROM
;           válido. Solo pone un color de fondo en pantalla.
; ============================================================

.MEMORYMAP
    SLOTSIZE $8000
    DEFAULTSLOT 0
    SLOT 0 $8000
.ENDME

.ROMBANKMAP
    BANKSTOTAL 8
    BANKSIZE $8000
    BANKS 8
.ENDRO

.SNESHEADER
    ID "SNES"
    NAME "PROYECTO TETRIS      "
    SLOWROM
    LOROM

    CARTRIDGETYPE $00
    ROMSIZE $08
    SRAMSIZE $00
    COUNTRY $01
    LICENSEECODE $00
    VERSION $00
.ENDSNES

.SNESNATIVEVECTOR
    COP EmptyHandler
    BRK EmptyHandler
    ABORT EmptyHandler
    NMI VBlank
    IRQ EmptyHandler
.ENDNATIVEVECTOR

.SNESEMUVECTOR
    COP EmptyHandler
    ABORT EmptyHandler
    NMI EmptyHandler
    RESET Start
    IRQBRK EmptyHandler
.ENDEMUVECTOR

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
    RTI

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
    ; Limpiar toda la tabla OAM antes de dibujar nuestro sprite
    ; real, moviendo los 128 sprites fuera de la pantalla
    ; visible (Y = $F0) para que no aparezca basura.
    ; --------------------------------------------------------
    LDA #$00
    STA $2102
    STA $2103           ; OAMADD = 0

    REP #$20
    .ACCU 16
    LDX #$0080          ; 128 sprites
ClearOAMLoop:
    SEP #$20
    .ACCU 8
    LDA #$00
    STA $2104           ; X = 0
    LDA #$F0
    STA $2104           ; Y = 240 (fuera de pantalla)
    LDA #$00
    STA $2104           ; tile = 0
    STA $2104           ; atributos = 0
    REP #$20
    .ACCU 16
    DEX
    BNE ClearOAMLoop

    SEP #$20
    .ACCU 8
    LDX #$20            ; 32 bytes de la tabla alta de OAM
ClearOAMHighLoop:
    LDA #$00
    STA $2104
    DEX
    BNE ClearOAMHighLoop

    ; --------------------------------------------------------
    ; Construir las 7 piezas (I,O,T,S,Z,J,L) con 4 sprites de
    ; 8x8 cada una (28 sprites en total). Cada bloque se coloca en:
    ;   X = OrigenX[pieza] + dx*8      Y = OrigenY[pieza] + dy*8
    ; con (dx,dy) tomado de PieceShapes. Solo prueba visual: sin
    ; movimiento, rotación ni lógica de juego.
    ; Temporales en direct page: $00 = pieza, $01 = bloques restantes
    ; --------------------------------------------------------
    LDA #$00
    STA $2102
    STA $2103           ; OAMADD = 0 (empezamos en el sprite 0)

    SEP #$10
    .INDEX 8
    STZ $00             ; pieza actual = 0
    LDX #$00            ; X = índice en PieceShapes (2 bytes por bloque)
BuildPieceLoop:
    LDA #$04
    STA $01             ; 4 bloques por pieza
    LDY $00             ; Y = pieza actual
BuildBlockLoop:
    LDA.w PieceShapes,X     ; dx (en celdas)
    ASL
    ASL
    ASL                     ; dx * 8 píxeles
    CLC
    ADC.w PieceOriginX,Y
    STA $2104               ; X del sprite

    LDA.w PieceShapes+1,X   ; dy (en celdas)
    ASL
    ASL
    ASL
    CLC
    ADC.w PieceOriginY,Y
    STA $2104               ; Y del sprite

    LDA.w PieceTileTable,Y
    STA $2104               ; tile (color) de la pieza
    LDA #$00
    STA $2104               ; atributos: paleta 0, sin flip/prioridad

    INX
    INX
    DEC $01
    BNE BuildBlockLoop

    INC $00
    LDA $00
    CMP #$07
    BNE BuildPieceLoop

    REP #$10
    .INDEX 16
    ; La tabla alta de OAM quedó en 0 (tamaño chico = 8x8).

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
    ; Habilitar NMI (VBlank) para futuro uso
    ; --------------------------------------------------------
    LDA #$80
    STA $4200

    CLI                 ; habilitar interrupciones

MainLoop:
    WAI                 ; esperar interrupción (ahorra ciclos)
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

.ENDS

; ------------------------------------------------------------
; Datos gráficos (generados por gfx4snes)
; ------------------------------------------------------------
.BANK 1 SLOT 0
.ORG 0
.SECTION "GraphicsData"
.INCLUDE "data/TetrisPieces_data.as"
.ENDS
