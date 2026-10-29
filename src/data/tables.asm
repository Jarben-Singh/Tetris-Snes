;=====Direcciones de memoria RAM para cada proceso=====
;-----Que tipo de pieza está cayendo-----
.DEFINE ACTIVE_PIECE_TYPE      $10 

;------Tipo de rotación se está haciendo------
.DEFINE ACTIVE_PIECE_ROTATION  $11

;-----------Columna del grid-----------
.DEFINE ACTIVE_PIECE_X         $12

;-------------Fila del grid-------------
.DEFINE ACTIVE_PIECE_Y         $13

;=====Tablas de datos: formas de piezas, tablas de rotación, velocidades por nivel=====

: Orden de piezas del juego:
; Para:
;  0 = I
;  1 = O
;  2 = T
;  3 = S
;  4 = Z
;  5 = J
;  6 = L
;

; Cada rotación es de 4 bloques * 2 (dx, dy) = 8 bytes

; Para cada pieza se pueden hacer 4 rotaciones (4 * 8bytes = 32 bytes)

TetrominoRotations:
;====== Pieza I = 0 ======
;-------Rotación 0--------
.db 0,1 1,1 2,1 3,1 

;-------Rotación 1--------
.db 2,0 2,1 2,2, 2,3

;-------Rotación 2--------
.db 0,2 1,2 2,2 3,2

;-------Rotación 3--------
.db 1,0 1,1 1,2 1,3
