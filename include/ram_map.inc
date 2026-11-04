; ============================================================
; ram_map.inc - Mapa de memoria RAM del juego
; Rol: Input / Infraestructura
; ------------------------------------------------------------
; La SNES no tiene malloc. Cada variable vive en una direccion
; fija que nosotros elegimos. Este archivo es el contrato entre
; los tres: si alguien usa una direccion que no reservo aqui,
; tarde o temprano dos modulos escriben en el mismo byte y el
; bug es casi imposible de encontrar.
;
; Zona baja ($0000-$00FF) = direct page. Acceder aqui cuesta un
; ciclo menos y un byte menos por instruccion, asi que se
; reserva para lo que se toca en cada frame.
;
;   $00-$0F   scratch temporal (main.asm, cualquiera)
;   $10-$1F   estado de la pieza activa        -> Nicolas
;   $20-$3F   input y temporizacion            -> Manuel
;   $40-$5F   puntaje, nivel, lineas           -> Nicolas
;   $0100+    buffers grandes (tablero, OAM)
; ============================================================

; ---------- $20-$2F : entrada del control ----------
; Cada uno es de 16 bits porque el control devuelve 16 bits.
.DEFINE PAD1_HELD       $20   ; botones que estan presionados AHORA
.DEFINE PAD1_PREV       $22   ; como estaban el frame anterior
.DEFINE PAD1_PRESSED    $24   ; los que se acaban de presionar (flanco)
.DEFINE PAD1_RELEASED   $26   ; los que se acaban de soltar

; ---------- $28-$2F : temporizacion ----------
.DEFINE FRAME_COUNTER   $28   ; 16 bits, sube 1 por frame (60/seg)
.DEFINE NMI_READY       $2A   ; 1 = el NMI ya corrio, el frame avanzo
.DEFINE GRAVITY_TIMER   $2B   ; frames acumulados desde la ultima caida
.DEFINE GRAVITY_SPEED   $2C   ; cada cuantos frames cae la pieza
.DEFINE DAS_TIMER       $2D   ; auto-repeat del D-pad
.DEFINE DAS_DIR         $2E   ; direccion que se esta repitiendo
.DEFINE OAM_DIRTY       $2F   ; 1 = hay cambios de sprites por mandar

; ---------- Buffer espejo de OAM ----------
; No se puede escribir a OAM cuando la pantalla esta dibujando.
; Por eso el juego escribe en esta copia en RAM durante el frame,
; y el NMI la manda completa por DMA durante el V-Blank.
; 128 sprites x 4 bytes = 512, mas 32 bytes de la tabla alta.
.DEFINE OAM_BUFFER      $0400   ; 512 bytes: $0400-$05FF
.DEFINE OAM_BUFFER_HI   $0600   ; 32 bytes:  $0600-$061F
.DEFINE OAM_BUFFER_SIZE 544
