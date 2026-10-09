; Cabecera de la ROM SNES: modo de mapeo, vectores de interrupción, checksum

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
