; Las variables de la pieza activa (ACTIVE_PIECE_*) se definen en include/ram_map.inc

;=====Tablas de datos: formas de piezas, tablas de rotación, velocidades por nivel=====

; Orden de piezas del juego:
; Para:
;  0 = I
;  1 = O
;  2 = T
;  3 = S
;  4 = Z
;  5 = J
;  6 = L


; Cada rotación es de 4 bloques * 2 (dx, dy) = 8 bytes

; Para cada pieza se pueden hacer 4 rotaciones (4 * 8bytes = 32 bytes)

TetrominoRotations:
;====== Pieza I = 0 ======
;-------Rotación 0--------
.db 0,1, 1,1, 2,1, 3,1 

;-------Rotación 1--------
.db 2,0, 2,1, 2,2, 2,3

;-------Rotación 2--------
.db 0,2, 1,2, 2,2, 3,2

;-------Rotación 3--------
.db 1,0, 1,1, 1,2, 1,3



;====== Pieza O = 1 ======
;-------Rotación 0, 1, 2, 3--------
;No cambia visualmente la pieza O al rotar
.db 1,0, 2,0, 1,1, 2,1
.db 1,0, 2,0, 1,1, 2,1
.db 1,0, 2,0, 1,1, 2,1
.db 1,0, 2,0, 1,1, 2,1


;====== Pieza T = 2 ======
;-------Rotación 0--------
.db 1,0, 0,1, 1,1, 2,1 

;-------Rotación 1--------
.db 1,0, 1,1, 2,1, 1,2

;-------Rotación 2--------
.db 0,1, 1,1, 2,1, 1,2

;-------Rotación 3--------
.db 1,0, 0,1, 1,1, 1,2


;====== Pieza S = 3 ======
;-------Rotación 0--------
.db 1,0, 2,0, 0,1, 1,1 

;-------Rotación 1--------
.db 1,0, 1,1, 2,1, 2,2

;-------Rotación 2--------
.db 1,1, 2,1, 0,2, 1,2

;-------Rotación 3--------
.db 0,0, 0,1, 1,1, 1,2


;====== Pieza Z = 4 ======
;-------Rotación 0--------
.db 0,0, 1,0, 1,1, 2,1

;-------Rotación 1--------
.db 2,0, 1,1, 2,1, 1,2

;-------Rotación 2--------
.db 0,1, 1,1, 1,2, 2,2

;-------Rotación 3--------
.db 1,0, 0,1, 1,1, 0,2



;====== Pieza J = 5 ======
;-------Rotación 0--------
.db 0,0, 0,1, 1,1, 2,1

;-------Rotación 1--------
.db 1,0, 2,0, 1,1, 1,2

;-------Rotación 2--------
.db 0,1, 1,1, 2,1, 2,2

;-------Rotación 3--------
.db 1,0, 1,1, 0,2, 1,2



;====== Pieza L = 6 ======
;-------Rotación 0--------
.db 2,0, 0,1, 1,1, 2,1

;-------Rotación 1--------
.db 1,0, 1,1, 1,2, 2,2

;-------Rotación 2--------
.db 0,1, 1,1, 2,1, 0,2

;-------Rotación 3--------
.db 0,0, 1,0, 1,1, 1,2