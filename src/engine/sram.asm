; ============================================================
; sram.asm - Guardado del Top Score en SRAM (con bateria)
; ------------------------------------------------------------
; El cartucho declara 2 KB de SRAM con bateria (header.asm:
; CARTRIDGETYPE $02, SRAMSIZE $01). En LoROM la SRAM aparece en
; el banco $70, direcciones $0000-$7FFF, y se lee/escribe con
; direccionamiento largo (LDA.l / STA.l).
;
; La primera vez que se enciende un cartucho (o un emulador sin
; archivo .srm) la SRAM trae basura. Para no mostrar un record
; inventado, el bloque guardado lleva:
;
;   $700000  4 bytes  firma "TTRS"
;   $700004  3 bytes  TOP_SCORE en BCD (mismo formato que RAM)
;   $700007  1 byte   checksum = byte0 ^ byte1 ^ byte2 ^ $A5
;
; Si la firma o el checksum no cuadran, el record empieza en 0 y
; se reescribe el bloque. El checksum se escribe al final: si se
; apaga la consola a la mitad de un guardado, el bloque queda
; invalido en vez de con un record a medias.
; ============================================================

.DEFINE SRAM_BASE        $700000
.DEFINE SRAM_MAGIC       (SRAM_BASE + 0)     ; 4 bytes
.DEFINE SRAM_TOP_SCORE   (SRAM_BASE + 4)     ; 3 bytes BCD
.DEFINE SRAM_CHECKSUM    (SRAM_BASE + 7)     ; 1 byte
.DEFINE SRAM_MAGIC_SIZE  4
.DEFINE SRAM_CHECK_SEED  $A5


; ============================================================
; SramLoadTopScore
;
; Lee el record de SRAM a TOP_SCORE. Si el bloque no es valido,
; deja TOP_SCORE en 0 y guarda un bloque nuevo.
; Llamar al arrancar, despues de ClearWRAM. Preserva P y X.
; ============================================================

SramLoadTopScore:
    PHP
    AI16
    PHX
    A8

    ; --- Firma ---
    LDX #$0000
SramLoadTopScore_Magic:
    LDA.l SRAM_MAGIC,X
    CMP.w SramMagicText,X
    BNE SramLoadTopScore_Invalid
    INX
    CPX #SRAM_MAGIC_SIZE
    BNE SramLoadTopScore_Magic

    ; --- Checksum ---
    LDA.l SRAM_TOP_SCORE
    EOR.l SRAM_TOP_SCORE+1
    EOR.l SRAM_TOP_SCORE+2
    EOR #SRAM_CHECK_SEED
    CMP.l SRAM_CHECKSUM
    BNE SramLoadTopScore_Invalid

    ; --- Bloque valido: copiar el record ---
    LDA.l SRAM_TOP_SCORE
    STA TOP_SCORE
    LDA.l SRAM_TOP_SCORE+1
    STA TOP_SCORE+1
    LDA.l SRAM_TOP_SCORE+2
    STA TOP_SCORE+2
    BRA SramLoadTopScore_Done

SramLoadTopScore_Invalid:
    STZ TOP_SCORE
    STZ TOP_SCORE+1
    STZ TOP_SCORE+2
    JSR SramSaveTopScore

SramLoadTopScore_Done:
    PLX
    PLP
    RTS


; ============================================================
; SramSaveTopScore
;
; Escribe TOP_SCORE en SRAM: firma, record y al final el
; checksum. La llama ScoreUpdateTop (game/score.asm) cada vez
; que se rompe el record. Preserva P y X.
; ============================================================

SramSaveTopScore:
    PHP
    AI16
    PHX
    A8

    LDX #$0000
SramSaveTopScore_Magic:
    LDA.w SramMagicText,X
    STA.l SRAM_MAGIC,X
    INX
    CPX #SRAM_MAGIC_SIZE
    BNE SramSaveTopScore_Magic

    LDA TOP_SCORE
    STA.l SRAM_TOP_SCORE
    LDA TOP_SCORE+1
    STA.l SRAM_TOP_SCORE+1
    LDA TOP_SCORE+2
    STA.l SRAM_TOP_SCORE+2

    ; checksum al final (ver cabecera)
    LDA TOP_SCORE
    EOR TOP_SCORE+1
    EOR TOP_SCORE+2
    EOR #SRAM_CHECK_SEED
    STA.l SRAM_CHECKSUM

    PLX
    PLP
    RTS


SramMagicText:
.db "TTRS"
