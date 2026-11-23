; Pantalla de inicio Tetris-Start (generada con `make gfx` / SuperFamiconv)
; 4bpp, tiles de 8x8, tilemap de 32x28 con paleta 2 de BG (-P 2),
; paleta de 16 colores BGR555 (va a CGRAM_BG_PAL2).

TitleStart_til:
.incbin "../assets/gfx/title_start.tiles"
TitleStart_tilend:

TitleStart_map:
.incbin "../assets/gfx/title_start.map"
TitleStart_mapend:

TitleStart_pal:
.incbin "../assets/gfx/title_start.pal"
TitleStart_palend:
