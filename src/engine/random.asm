; ============================================================
; random.asm - Generador de numeros pseudoaleatorios
; Rol: Input / Infraestructura  (Manuel)
; ------------------------------------------------------------
; El 65816 no tiene ninguna fuente de aleatoriedad real: hay que
; fabricarla con un xorshift de 16 bits (desplazamientos 7, 9, 8).
; Esta variante especifica ya se verifico que recorre los 65535
; estados posibles antes de repetirse, siempre que el estado
; nunca llegue a valer 0 (un xorshift en 0 se queda en 0 para
; siempre: 0 XOR lo-que-sea-desplazado-de-0 sigue siendo 0).
;
; Para convertir eso en "un numero entre 0 y n-1" (por ejemplo,
; una posicion de la bolsa de piezas) se usa el multiplicador por
; hardware: byte_aleatorio * n, y se toma el byte alto del
; resultado de 16 bits. Es el mismo truco que usan muchos juegos
; de SNES: evita el residuo de division (el 65816 no divide) y
; siempre tarda el mismo numero de ciclos, sin importar n.
; ============================================================

; Constante impar fija para combinar con FRAME_COUNTER al armar
; la semilla. Solo tiene que ser distinta de 0.
.DEFINE RNG_SEED_CONST $ACE1

; ------------------------------------------------------------
; RandomSeed - arranca el generador con una semilla
; ------------------------------------------------------------
; Combina FRAME_COUNTER (cuantos frames llevan corridos) con
; RNG_SEED_CONST. Si el resultado fuera 0 (xorshift no puede
; arrancar en 0), se usa la constante sola, que nunca es 0.
;
; Hoy se llama una vez en Start, porque todavia no hay pantalla
; de titulo. Esta pensada para moverse al futuro handler de
; START en esa pantalla: ahi la semilla dependeria de cuanto
; tardo el jugador en presionar START, que es mucho menos
; predecible que un numero de frame fijo al encender.
; ------------------------------------------------------------
RandomSeed:
    PHP
    A16

    LDA FRAME_COUNTER
    EOR #RNG_SEED_CONST
    BNE RandomSeed_Store
    LDA #RNG_SEED_CONST      ; evitar semilla 0

RandomSeed_Store:
    STA RNG_STATE

    PLP
    RTS

; ------------------------------------------------------------
; RandomAdvance - un paso del xorshift (x^=x<<7; x^=x>>9; x^=x<<8)
; ------------------------------------------------------------
; El 65816 no tiene desplazamiento por N bits de una sola vez,
; asi que cada paso se hace repitiendo ASL/LSR en un scratch de
; 16 bits ($00-$01) y luego se mezcla con XOR sobre RNG_STATE.
;
; Usa Y como contador de cada loop y NO lo preserva. A proposito
; no toca X: BagRefill (game/piece.asm) guarda la posicion de la
; bolsa en X mientras pide numeros aleatorios, y X tiene que
; seguir intacto cuando esta funcion (llamada indirectamente via
; RandomByte/RandomRange) regresa.
;
; Se llama una vez por frame desde MainLoop: eso ata el momento
; exacto en que se revuelve cada bolsa a cuando el jugador mueve
; o deja caer piezas, que es justo lo que hace que cada partida
; se sienta distinta aunque la semilla inicial sea predecible.
; ------------------------------------------------------------
RandomAdvance:
    PHP
    AI16                      ; A y Y en 16 bits; X no se toca

    ; x ^= x << 7
    LDA RNG_STATE
    STA $00
    LDY #$0007
RandomAdvance_Shift7:
    ASL $00
    DEY
    BNE RandomAdvance_Shift7
    LDA RNG_STATE
    EOR $00
    STA RNG_STATE

    ; x ^= x >> 9
    STA $00
    LDY #$0009
RandomAdvance_Shift9:
    LSR $00
    DEY
    BNE RandomAdvance_Shift9
    LDA RNG_STATE
    EOR $00
    STA RNG_STATE

    ; x ^= x << 8
    STA $00
    LDY #$0008
RandomAdvance_Shift8:
    ASL $00
    DEY
    BNE RandomAdvance_Shift8
    LDA RNG_STATE
    EOR $00
    STA RNG_STATE

    PLP
    RTS

; ------------------------------------------------------------
; RandomByte - avanza el generador y devuelve un byte fresco
; ------------------------------------------------------------
; Devuelve en A (8 bits) el byte bajo del nuevo estado.
;
; Cada llamada avanza el estado, asi que pedir varios bytes en
; el mismo frame (por ejemplo, revolver la bolsa completa) si da
; valores distintos entre si.
;
; Igual que el resto de funciones de infraestructura: el PLP de
; aqui adentro deja las banderas de ANTES de la llamada, no las
; del valor devuelto. Quien llame y necesite ramificar debe
; releerlas con un CMP/ORA propio en vez de un BEQ/BNE directo.
; ------------------------------------------------------------
RandomByte:
    PHP
    JSR RandomAdvance

    A16
    LDA RNG_STATE
    A8

    PLP
    RTS

; ------------------------------------------------------------
; RandomRange - numero aleatorio uniforme en [0, n-1]
; ------------------------------------------------------------
; Entrada: A (8 bits) = n (limite superior, EXCLUSIVO). n esta
;          pensado para valores chicos (p.ej. 7, para la bolsa);
;          con n=0 el resultado no tiene sentido (no se usa asi).
; Salida:  A (8 bits) = (RandomByte() * n) / 256
;
; Multiplicar por n y quedarse con el byte alto reparte un byte
; 0-255 en n cubetas casi parejas sin dividir: es exactamente el
; truco que pide el ticket, usando WRMPYA/WRMPYB/RDMPYH.
; ------------------------------------------------------------
RandomRange:
    PHP
    A8
    STA $0F                 ; guardar n (RandomByte usa $00-$01)

    JSR RandomByte           ; A (8 bits) = byte aleatorio fresco
    A8
    STA WRMPYA

    LDA $0F
    STA WRMPYB               ; dispara la multiplicacion 8x8

    NOP                       ; darle tiempo al multiplicador
    NOP                       ; (listo en ~8 ciclos de reloj)

    LDA RDMPYH                ; byte alto = resultado / 256

    PLP
    RTS
