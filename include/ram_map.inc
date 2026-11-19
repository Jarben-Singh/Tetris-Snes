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
;   $0100+    buffers grandes (tablero, OAM, tilemap de BG2)
; ============================================================


; ---------- $00-$0F : scratch ----------
; Parametros de DmaToVram / DmaToCgram (engine/dma.asm).
; Son temporales: el que llama los escribe justo antes del JSR.
.DEFINE DMA_SRC         $00   ; 16 bits: direccion origen
.DEFINE DMA_BANK        $02   ; 8 bits:  banco origen
.DEFINE DMA_SIZE        $03   ; 16 bits: tamano en bytes
.DEFINE DMA_DEST        $05   ; 16 bits: destino (word VRAM / indice CGRAM)


; ---------- $10-$1F : estado de la pieza activa ----------

.DEFINE ACTIVE_PIECE_TYPE      $10
.DEFINE ACTIVE_PIECE_ROTATION  $11
.DEFINE ACTIVE_PIECE_X         $12
.DEFINE ACTIVE_PIECE_Y         $13
.DEFINE NEXT_PIECE_TYPE        $14   ; tipo que saldra en el proximo spawn



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

; ---------- $30-$39 : generador aleatorio / bolsa de piezas ----------
.DEFINE RNG_STATE       $30   ; 16 bits: estado del xorshift, nunca 0
.DEFINE PIECE_BAG       $32   ; 7 bytes: bolsa con los tipos 0-6 revueltos
.DEFINE BAG_INDEX       $39   ; siguiente posicion a repartir (0-6)

; ---------- $3A : tablero en BG2 ----------
.DEFINE BG2_DIRTY       $3A   ; 1 = hay que mandar BG2_SHADOW a VRAM

; ---------- $40-$5F : puntaje, nivel, lineas ----------
; Los llena ActivePieceApplyGravity (game/piece.asm) con el
; resultado de BoardClearLines; score.asm los usara para el
; puntaje y el nivel.
.DEFINE LINES_CLEARED_LAST $40   ; lineas borradas por la ultima pieza (0-4)
.DEFINE LINES_TOTAL        $41   ; 16 bits: lineas borradas en la partida

; ---------- Tablero (game/board.asm) ----------
; 10 x 20 celdas, una por byte, fila por fila:
;   indice = fila * 10 + columna
; 0 = vacia, 1-7 = bloque fijo (tipo de pieza + 1).
.DEFINE BOARD           $0100   ; 200 bytes: $0100-$01C7

; ---------- Buffer espejo de OAM ----------
; No se puede escribir a OAM cuando la pantalla esta dibujando.
; Por eso el juego escribe en esta copia en RAM durante el frame,
; y el NMI la manda completa por DMA durante el V-Blank.
; 128 sprites x 4 bytes = 512, mas 32 bytes de la tabla alta.
.DEFINE OAM_BUFFER      $0400   ; 512 bytes: $0400-$05FF
.DEFINE OAM_BUFFER_HI   $0600   ; 32 bytes:  $0600-$061F
.DEFINE OAM_BUFFER_SIZE 544

; ---------- Buffer espejo del tilemap de BG2 ----------
; Los bloques fijos se dibujan como tiles de BG2, no como
; sprites (la SNES solo tiene 128). Mismo patron que la OAM:
; BoardRender (game/board.asm) escribe aqui y el NMI lo manda.
; Son las 20 filas del tablero con el ancho completo del mapa
; (32 entradas de 2 bytes), para mandarlo en un solo DMA.
.DEFINE BG2_SHADOW      $0700   ; 1280 bytes: $0700-$0BFF
.DEFINE BG2_SHADOW_SIZE 1280    ; 20 filas x 32 entradas x 2 bytes
