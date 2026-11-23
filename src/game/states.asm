; ============================================================
; states.asm - Maquina de estados del juego
; ------------------------------------------------------------
; GAME_STATE (ram_map.inc) dice en que pantalla estamos y el
; bucle principal (main.asm) decide que correr cada frame:
;
;   STATE_TITLE    pantalla de inicio: solo espera START
;   STATE_PLAYING  partida en curso (piezas, gravedad, HUD)
;
; TODO: pantalla de game over. Por ahora, al perder, la partida
; nueva empieza de inmediato (ActivePieceSpawn en piece.asm).
; ============================================================

.DEFINE STATE_TITLE   0
.DEFINE STATE_PLAYING 1


; ============================================================
; TitleUpdate
;
; Se llama cada frame en la pantalla de inicio. Si se acaba de
; presionar START, empieza la partida.
; Preserva P.
; ============================================================

TitleUpdate:
    PHP
    A16
    LDA PAD1_PRESSED
    AND #BTN_START
    A8                          ; SEP no toca Z
    BEQ TitleUpdate_Done
    JSR StartGame

TitleUpdate_Done:
    PLP
    RTS


; ============================================================
; StartGame
;
; Pasa de la pantalla de inicio a la partida:
;   - BG1 muestra el fondo del juego (ShowGameScreen)
;   - siembra el generador aleatorio: FRAME_COUNTER depende de
;     cuanto tardo el jugador en presionar START, asi que cada
;     partida tiene una secuencia de piezas distinta
;   - puntaje, lineas y nivel en 0, gravedad del nivel 0
;   - primera bolsa, siguiente pieza y pieza activa
; Preserva P.
; ============================================================

StartGame:
    PHP
    A8

    JSR ShowGameScreen
    JSR RandomSeed
    JSR ScoreReset
    LDA GRAVITY_SPEED
    STA GRAVITY_TIMER           ; primera caida con el tiempo completo
    JSR ActivePieceInit

    LDA #STATE_PLAYING
    STA GAME_STATE

    PLP
    RTS
