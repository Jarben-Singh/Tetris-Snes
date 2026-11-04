; ============================================================
; irq.asm - Rutina de interrupcion IRQ
; Rol: Input / Infraestructura  (Manuel)
; ------------------------------------------------------------
; El IRQ se dispara en una linea o pixel concreto DENTRO del
; frame, no al final como el NMI. Sirve para efectos que cambian
; a media pantalla (barra de HUD con otro scroll, cambio de
; paleta por franja).
;
; Tetris no lo necesita para el MVP, pero el vector tiene que
; apuntar a algo valido: si el IRQ se dispara por accidente y el
; vector apunta a basura, la consola se cuelga. Este handler
; limpia la bandera y regresa sin hacer nada.
; ============================================================

IRQHandler:
    PHA
    PHP
    A8
    LDA TIMEUP              ; leer limpia la bandera de IRQ
    PLP
    PLA
    RTI
