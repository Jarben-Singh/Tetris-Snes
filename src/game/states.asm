; ============================================================
; states.asm - Maquina de estados del juego
; ------------------------------------------------------------
; GAME_STATE (ram_map.inc) dice en que pantalla estamos y el
; bucle principal (main.asm) decide que correr cada frame:
;
;   STATE_TITLE    pantalla de inicio: solo espera START
;   STATE_PLAYING  partida en curso (piezas, gravedad, HUD)
;
; Al perder (ActivePieceSpawn en piece.asm) GameOver regresa a
; STATE_TITLE.
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


; ============================================================
; GameOver
;
; La pieza nueva ya no cabe: regresa a la pantalla de inicio.
;   - vacia el tablero (BG2 queda limpio para la siguiente
;     partida; en el titulo BG2 esta apagado)
;   - esconde todos los sprites (pieza, NEXT y contadores)
;   - BG1 muestra la pantalla de inicio (ShowTitleScreen)
; El puntaje se queda como estaba hasta que StartGame llama a
; ScoreReset. TOP_SCORE ya se guardo en la SRAM al superarse
; (ScoreAddLines).
; Preserva P.
; ============================================================

GameOver:
    PHP
    A8

    JSR BoardClear
    JSR BoardRender
    JSR OamBufferInit           ; todos los sprites fuera de pantalla
    JSR ShowTitleScreen

    LDA #STATE_TITLE
    STA GAME_STATE

    PLP
    RTS
