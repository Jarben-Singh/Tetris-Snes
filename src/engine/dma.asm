; ============================================================
; dma.asm - Transferencias DMA hacia VRAM y CGRAM
; ------------------------------------------------------------
; Rutinas genericas para cargar graficos: tiles, tilemaps,
; fuentes, paletas... Cualquier carga nueva deberia pasar por
; aqui en vez de repetir la configuracion del DMA a mano.
;
; Usan el canal 1. El canal 0 es del NMI (OamFlush): si una de
; estas rutinas corre con el NMI activo y este la interrumpe,
; cada uno tiene sus propios registros y no se pisan.
;
; OJO: VRAM y CGRAM solo se pueden escribir con la pantalla en
; forced blank o durante el V-Blank. Fuera de eso la escritura
; se pierde o sale basura.
;
; Parametros (direct page, ver ram_map.inc):
;   DMA_SRC  (16) = direccion origen     -> LDA #Etiqueta
;   DMA_BANK (8)  = banco origen         -> LDA #:Etiqueta
;   DMA_SIZE (16) = tamano en bytes      -> fin - inicio
;                   (0 = 65536 bytes, comportamiento del hardware)
;   DMA_DEST (16) = destino (ver cada rutina)
;
; Ejemplo:
;   A16
;   LDA #MisTiles
;   STA DMA_SRC
;   LDA #(MisTiles_end - MisTiles)
;   STA DMA_SIZE
;   LDA #VRAM_BG1_TILES
;   STA DMA_DEST
;   A8
;   LDA #:MisTiles
;   STA DMA_BANK
;   JSR DmaToVram
;
; Preservan P (tamano de registros). Modifican A.
; ============================================================

; ------------------------------------------------------------
; DmaToVram - copia DMA_SIZE bytes a VRAM
;   DMA_DEST = direccion de VRAM en WORDS
; ------------------------------------------------------------
DmaToVram:
    PHP
    A8
    LDA #$80
    STA VMAIN               ; incrementar tras escribir el byte alto

    A16
    LDA DMA_DEST
    STA VMADDL              ; 16 bits: cubre VMADDL/VMADDH
    LDA DMA_SRC
    STA A1T1L
    LDA DMA_SIZE
    STA DAS1L

    A8
    LDA DMA_BANK
    STA A1B1
    LDA #$01
    STA DMAP1               ; modo 1: 2 registros alternados ($2118/$2119)
    LDA #(VMDATAL & $FF)
    STA BBAD1               ; destino = VMDATAL
    LDA #$02
    STA MDMAEN              ; disparar canal 1
    PLP
    RTS

; ------------------------------------------------------------
; DmaToCgram - copia DMA_SIZE bytes a CGRAM
;   DMA_DEST = indice del primer color (0-255, byte bajo)
;   Cada color ocupa 2 bytes: 16 colores = 32 bytes.
; ------------------------------------------------------------
DmaToCgram:
    PHP
    A8
    LDA DMA_DEST
    STA CGADD

    A16
    LDA DMA_SRC
    STA A1T1L
    LDA DMA_SIZE
    STA DAS1L

    A8
    LDA DMA_BANK
    STA A1B1
    LDA #$00
    STA DMAP1               ; modo 0: 1 registro, escrituras seguidas
    LDA #(CGDATA & $FF)
    STA BBAD1               ; destino = CGDATA
    LDA #$02
    STA MDMAEN              ; disparar canal 1
    PLP
    RTS
