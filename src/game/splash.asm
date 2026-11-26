; ============================================================
; splash.asm - Pantallas que salen al encender
; ------------------------------------------------------------
; Antes del titulo se muestran, en este orden:
;   1. ShowCreditsScreen - aviso de proyecto de fans (assets/credits/)
;   2. ShowThanksScreen  - agradecimiento a Alekséi Pázhitnov
;                          (assets/thanks/)
; Cada una aparece desde negro subiendo el brillo (SplashFadeIn),
; se queda un rato con brillo maximo y se oscurece poco a poco
; con el brillo de INIDISP hasta quedar en negro (SplashFadeOut).
;
; Corren ANTES de cargar el resto de los graficos (main.asm): la
; imagen de Pázhitnov usa 547 tiles y las 8 paletas de BG, asi
; que pisan VRAM y CGRAM. main.asm limpia las dos justo despues,
; por eso aqui no importa donde caigan los datos.
;
; El NMI todavia esta apagado: los frames se cuentan leyendo el
; bit de V-Blank de HVBJOY directamente.
;
; Llamar con la pantalla en forced blank y X/Y en 16 bits.
; Salen con la pantalla en forced blank. Preservan P.
; Modifican A, X, Y y el scratch DMA_*.
; ============================================================

; VRAM temporal (se limpia despues, ver arriba)
.DEFINE VRAM_SPLASH_TILES $0000   ; Pázhitnov: 547 tiles = $2230 words
.DEFINE VRAM_SPLASH_MAP   $3000   ; multiplo de $0400 (BGnSC)

.DEFINE SPLASH_HOLD_FRAMES  120   ; ~2 s con brillo completo
.DEFINE SPLASH_FADE_FRAMES  8     ; frames por cada nivel de brillo
                                  ; (15 niveles -> ~2 s de fundido)
.DEFINE SPLASH_BLACK_FRAMES 30    ; ~0.5 s en negro antes de seguir

; ------------------------------------------------------------
; ShowCreditsScreen - aviso de proyecto de fans
;   2bpp -> BG3 del modo 1 (sus 4 colores = CGRAM 0-3).
; ------------------------------------------------------------
ShowCreditsScreen:
    PHP
    I16

    ; --- Tiles ---
    A16
    LDA #Credits_til
    STA DMA_SRC
    LDA #(Credits_tilend - Credits_til)
    STA DMA_SIZE
    LDA #VRAM_SPLASH_TILES
    STA DMA_DEST
    A8
    LDA #:Credits_til
    STA DMA_BANK
    JSR DmaToVram

    ; --- Tilemap ---
    A16
    LDA #Credits_map
    STA DMA_SRC
    LDA #(Credits_mapend - Credits_map)
    STA DMA_SIZE
    LDA #VRAM_SPLASH_MAP
    STA DMA_DEST
    A8
    LDA #:Credits_map
    STA DMA_BANK
    JSR DmaToVram

    ; --- Paleta (paleta 0 de BG3, CGRAM 0-3) ---
    A16
    LDA #Credits_pal
    STA DMA_SRC
    LDA #(Credits_palend - Credits_pal)
    STA DMA_SIZE
    LDA #CGRAM_BG_PAL0
    STA DMA_DEST
    A8
    LDA #:Credits_pal
    STA DMA_BANK
    JSR DmaToCgram

    ; --- Registros: modo 1, solo BG3 ---
    LDA #$01
    STA BGMODE
    LDA #((VRAM_SPLASH_MAP >> 8) & $FC)
    STA BG3SC
    LDA #(VRAM_SPLASH_TILES >> 12)  ; nibble bajo = BG3
    STA BG34NBA
    LDA #$00
    STA BG3HOFS
    STA BG3HOFS
    LDA #$FF                ; VOFS = -1, igual que los otros fondos
    STA BG3VOFS
    LDA #$03
    STA BG3VOFS
    LDA #$04
    STA TM                  ; solo BG3

    JSR SplashFadeIn        ; aparece desde negro
    JSR SplashFadeOut

    PLP
    RTS

; ------------------------------------------------------------
; ShowThanksScreen - agradecimiento a Alekséi Pázhitnov
;   4bpp -> BG1 del modo 1 (8 paletas, CGRAM 0-127).
; ------------------------------------------------------------
ShowThanksScreen:
    PHP
    I16

    ; --- Tiles ---
    A16
    LDA #Thanks_til
    STA DMA_SRC
    LDA #(Thanks_tilend - Thanks_til)
    STA DMA_SIZE
    LDA #VRAM_SPLASH_TILES
    STA DMA_DEST
    A8
    LDA #:Thanks_til
    STA DMA_BANK
    JSR DmaToVram

    ; --- Tilemap ---
    A16
    LDA #Thanks_map
    STA DMA_SRC
    LDA #(Thanks_mapend - Thanks_map)
    STA DMA_SIZE
    LDA #VRAM_SPLASH_MAP
    STA DMA_DEST
    A8
    LDA #:Thanks_map
    STA DMA_BANK
    JSR DmaToVram

    ; --- Paleta (8 paletas de BG, CGRAM 0-127) ---
    A16
    LDA #Thanks_pal
    STA DMA_SRC
    LDA #(Thanks_palend - Thanks_pal)
    STA DMA_SIZE
    LDA #CGRAM_BG_PAL0
    STA DMA_DEST
    A8
    LDA #:Thanks_pal
    STA DMA_BANK
    JSR DmaToCgram

    ; --- Registros: modo 1, solo BG1 ---
    LDA #$01
    STA BGMODE
    LDA #((VRAM_SPLASH_MAP >> 8) & $FC)
    STA BG1SC
    LDA #(VRAM_SPLASH_TILES >> 12)  ; nibble bajo = BG1
    STA BG12NBA
    LDA #$00
    STA BG1HOFS
    STA BG1HOFS
    LDA #$FF                ; VOFS = -1, igual que los otros fondos
    STA BG1VOFS
    LDA #$03
    STA BG1VOFS
    LDA #$01
    STA TM                  ; solo BG1

    JSR SplashFadeIn        ; aparece desde negro
    JSR SplashFadeOut

    PLP
    RTS

; ------------------------------------------------------------
; SplashFadeIn - enciende la pantalla en negro y sube el brillo
; de 0 a 15, un nivel cada SPLASH_FADE_FRAMES frames (el mismo
; ritmo que el fundido de salida, ~2 s).
; Llamar con A en 8 bits y X/Y en 16. Modifica A, X, Y.
; ------------------------------------------------------------
SplashFadeIn:
    .ACCU 8
    .INDEX 16

    JSR SplashWaitVBlank
    LDA #$00                ; sin forced blank, brillo 0 = negro
    STA INIDISP

    LDY #$0000
SplashFadeInStep:
    LDX #SPLASH_FADE_FRAMES
SplashFadeInWait:
    JSR SplashWaitVBlank
    DEX
    BNE SplashFadeInWait
    INY
    TYA                     ; A (8 bits) = nuevo brillo
    STA INIDISP             ; seguimos dentro del V-Blank
    CPY #$000F
    BNE SplashFadeInStep
    RTS

; ------------------------------------------------------------
; SplashFadeOut - con la pantalla ya en brillo completo, la deja
; SPLASH_HOLD_FRAMES, baja el brillo de 15 a 0 y espera
; SPLASH_BLACK_FRAMES en negro. Sale en forced blank.
; Llamar con A en 8 bits y X/Y en 16. Modifica A, X, Y.
; ------------------------------------------------------------
SplashFadeOut:
    .ACCU 8
    .INDEX 16

    LDX #SPLASH_HOLD_FRAMES
SplashHold:
    JSR SplashWaitVBlank
    DEX
    BNE SplashHold

    ; --- Fundido a negro: brillo 15 -> 0 ---
    LDY #$000F
SplashFadeStep:
    LDX #SPLASH_FADE_FRAMES
SplashFadeWait:
    JSR SplashWaitVBlank
    DEX
    BNE SplashFadeWait
    DEY
    TYA                     ; A (8 bits) = nuevo brillo
    STA INIDISP             ; seguimos dentro del V-Blank
    BNE SplashFadeStep      ; Z viene del TYA

    LDX #SPLASH_BLACK_FRAMES
SplashBlack:
    JSR SplashWaitVBlank
    DEX
    BNE SplashBlack

    LDA #$8F                ; forced blank para lo que siga
    STA INIDISP
    RTS

; ------------------------------------------------------------
; SplashWaitVBlank - espera al inicio del siguiente V-Blank
; leyendo HVBJOY (bit 7 = en V-Blank). Sirve sin NMI.
; Preserva P. Modifica A.
; ------------------------------------------------------------
SplashWaitVBlank:
    PHP
    A8
SplashWaitVBlank_Out:       ; si ya estamos en V-Blank, esperar a que acabe
    LDA HVBJOY
    BMI SplashWaitVBlank_Out
SplashWaitVBlank_In:        ; y luego a que empiece el siguiente
    LDA HVBJOY
    BPL SplashWaitVBlank_In
    PLP
    RTS
