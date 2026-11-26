; Pantallas que salen al encender, antes del titulo
; (game/splash.asm).

; --- Creditos / aviso de proyecto de fans, assets/credits/ ---
; 2bpp, tiles de 8x8 (80 tiles), tilemap de 32x32 con paleta 0,
; paleta de 4 colores. Se muestra en BG3 (la capa 2bpp del modo 1).

Credits_til:
.incbin "../assets/credits/credits.pic"
Credits_tilend:

Credits_map:
.incbin "../assets/credits/credits.map"
Credits_mapend:

Credits_pal:
.incbin "../assets/credits/credits.pal"
Credits_palend:

; --- Agradecimiento (Alekséi Pázhitnov), assets/thanks/ ---
; 4bpp, tiles de 8x8 (547 tiles), tilemap de 32x32 que usa las
; 8 paletas de BG: la paleta ocupa CGRAM 0-127 completa.

Thanks_til:
.incbin "../assets/thanks/gracias.pic"
Thanks_tilend:

Thanks_map:
.incbin "../assets/thanks/gracias.map"
Thanks_mapend:

Thanks_pal:
.incbin "../assets/thanks/gracias.pal"
Thanks_palend:
