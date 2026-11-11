; ============================================================
; hardware.inc - Registros de hardware de la SNES
; Rol: Input / Infraestructura
; ------------------------------------------------------------
; Estos nombres son SOLO alias de direcciones. El ensamblador
; los sustituye en tiempo de compilacion: no ocupan memoria ni
; cuestan ciclos. Sirven para que el codigo diga INIDISP en vez
; de $2100 y se pueda leer sin tener el manual al lado.
; ============================================================

; ---------- PPU: pantalla y graficos ----------
.DEFINE INIDISP     $2100   ; brillo + forced blank
.DEFINE OBSEL       $2101   ; tamano y base de sprites
.DEFINE OAMADDL     $2102   ; direccion OAM (low)
.DEFINE OAMADDH     $2103   ; direccion OAM (high)
.DEFINE OAMDATA     $2104   ; puerto de escritura a OAM
.DEFINE BGMODE      $2105   ; modo de fondo
.DEFINE BG1SC       $2107   ; BG1: direccion y tamano del tilemap
.DEFINE BG12NBA     $210B   ; BG1/BG2: direccion base de los tiles
.DEFINE BG1HOFS     $210D   ; BG1: scroll horizontal (escritura doble)
.DEFINE BG1VOFS     $210E   ; BG1: scroll vertical (escritura doble)
.DEFINE VMAIN       $2115   ; control de incremento de VRAM
.DEFINE VMADDL      $2116   ; direccion VRAM (low)
.DEFINE VMADDH      $2117   ; direccion VRAM (high)
.DEFINE VMDATAL     $2118   ; dato VRAM (low)
.DEFINE VMDATAH     $2119   ; dato VRAM (high)
.DEFINE CGADD       $2121   ; indice de color en CGRAM
.DEFINE CGDATA      $2122   ; dato de color
.DEFINE TM          $212C   ; capas visibles en la pantalla principal

; ---------- CPU: interrupciones y joypad ----------
.DEFINE NMITIMEN    $4200   ; habilita NMI, IRQ y lectura automatica del control
.DEFINE RDNMI       $4210   ; leer aqui limpia la bandera de NMI
.DEFINE TIMEUP      $4211   ; leer aqui limpia la bandera de IRQ
.DEFINE HVBJOY      $4212   ; bit0 = lectura de joypad en curso
.DEFINE JOY1L       $4218   ; control 1, byte bajo
.DEFINE JOY1H       $4219   ; control 1, byte alto

; ---------- DMA canal 0 ----------
.DEFINE DMAP0       $4300   ; modo de transferencia
.DEFINE BBAD0       $4301   ; registro destino ($21xx)
.DEFINE A1T0L       $4302   ; direccion origen (low)
.DEFINE A1T0H       $4303   ; direccion origen (high)
.DEFINE A1B0        $4304   ; banco origen
.DEFINE DAS0L       $4305   ; tamano (low)
.DEFINE DAS0H       $4306   ; tamano (high)
.DEFINE MDMAEN      $420B   ; disparar canales DMA

; ---------- DMA canal 1 ----------
; El NMI usa el canal 0 para la OAM. Las cargas de graficos
; (engine/dma.asm) usan el canal 1 para no pisarse con el NMI.
.DEFINE DMAP1       $4310   ; modo de transferencia
.DEFINE BBAD1       $4311   ; registro destino ($21xx)
.DEFINE A1T1L       $4312   ; direccion origen (low)
.DEFINE A1T1H       $4313   ; direccion origen (high)
.DEFINE A1B1        $4314   ; banco origen
.DEFINE DAS1L       $4315   ; tamano (low)
.DEFINE DAS1H       $4316   ; tamano (high)

; ---------- Mascaras de botones del control ----------
; El control devuelve 16 bits. Cada bit es un boton.
; Ojo con el orden: NO es alfabetico ni intuitivo, es el orden
; en que el hardware desplaza los bits hacia afuera.
.DEFINE BTN_B       $8000
.DEFINE BTN_Y       $4000
.DEFINE BTN_SELECT  $2000
.DEFINE BTN_START   $1000
.DEFINE BTN_UP      $0800
.DEFINE BTN_DOWN    $0400
.DEFINE BTN_LEFT    $0200
.DEFINE BTN_RIGHT   $0100
.DEFINE BTN_A       $0080
.DEFINE BTN_X       $0040
.DEFINE BTN_L       $0020
.DEFINE BTN_R       $0010

; Mascara combinada izquierda+derecha (para el auto-repeat lateral)
.DEFINE BTN_LEFTRIGHT $0300

; ---------- Prioridad de sprites (bits 4-5 del atributo OAM) ----------
; En modo 1, de adelante hacia atras:
;   OBJ3 > BG1 alta > BG2 alta > OBJ2 > BG1 baja > BG2 baja > OBJ1 > BG3 > OBJ0
; Con prioridad 0 un sprite queda DETRAS de BG1 y BG2.
.DEFINE OBJ_PRIO_0  $00
.DEFINE OBJ_PRIO_1  $10
.DEFINE OBJ_PRIO_2  $20
.DEFINE OBJ_PRIO_3  $30   ; encima de todos los fondos
