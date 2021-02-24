;
; FinalProyecto3.asm

.include "m16adef.inc"
.org 0 
RJMP main
.org 0x16
RJMP Rx  ; Interrupcion de recepcion

.def dato_recibido = R17
.def vel_motorA = R18
.def vel_motorB = R19

main:
;Pila
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16
    LDI R16, LOW(RAMEND)
    OUT SPL, R16

;salidas
SBI DDRD, 4   ;salida OC1B
SBI DDRD, 5      ;salida 0C1A 
SER R16
OUT DDRA, R16 ;salida puerto A (direcciones)

; Programar tope (ESTE TOPE FUNCIONA)
LDI R16, HIGH(300)
OUT ICR1H, R16
LDI R16, LOW(300)
OUT ICR1L, R16

CLR dato_recibido


;Inicializar recepción de serial (interrupcion)
LDI R16, 0b10000110        ;Asíncrono (6). Disable (5 4). 1 stop bit (3). 8 character size (2 1). No Polaridad (0)
OUT UCSRC, R16            
LDI R16, 0b10010000        ;Habilita Interrupción cuando Buffer de Recepción lleno, habitlita recepcion
OUT UCSRB, R16
LDI R16, 51
OUT UBRRL, R16            ;9600 baud rate
SEI 


FIN : RJMP FIN

Rx:    
    IN R16, SREG
    PUSH R16

    IN dato_recibido, UDR ; en UDR se guarda lo que se recibioo 
    

    direccionSeleccionada: ; Pregunto la direccion seleccionada y la velocidad que fue recibida por serial
    CPI dato_recibido, 21
    BREQ norm_Adelante
    CPI dato_recibido, 22
    BREQ norm_Atras
    CPI dato_recibido, 24
    BREQ norm_Izquierda
    CPI dato_recibido, 28
    BREQ norm_Derecha
    CPI dato_recibido, 31
    BREQ max_Adelante
    CPI dato_recibido, 32
    BREQ max_Atras
    CPI dato_recibido, 34
    BREQ max_Izquierda
    CPI dato_recibido, 38
    BREQ max_Derecha
    CPI dato_recibido, 40
    BRSH stop
    
    RJMP salir ; s no es ninguna de estas opciones salte

norm_Adelante: ; Genera PWM con velocidad normal hacia adelante
    
    
    LDI R16, 0B00001010
    OUT PORTA, R16
    LDI vel_motorA, 193
    LDI vel_motorB, 193
    CALL PWM
    
    RJMP salir
    
norm_Atras: ; Genera PWM con velocidad normal hacia atras
    
    LDI R16, 0B00000101
    OUT PORTA, R16
    LDI vel_motorA, 193
    LDI vel_motorB, 193
    CALL PWM

    RJMP salir

norm_Izquierda: ;Genera PWM con velocidad normal hacia la izquierda

    LDI R16, 0B00001010
    OUT PORTA, R16
    LDI vel_motorA, 96 ; minimo
    LDI vel_motorB, 193 ; medio
    CALL PWM

    RJMP salir

norm_Derecha: ;Genera PWM con velocidad normal hacia la izquierda

    LDI R16, 0B00001010
    OUT PORTA, R16
    LDI vel_motorA, 193 ; medio
    LDI vel_motorB, 96 ; min
    CALL PWM

    RJMP salir

max_Adelante: ;Genera PWM con velocidad normal hacia la izquierda

    LDI R16, 0B00001010
    OUT PORTA, R16
    LDI vel_motorA, 255 ; max
    LDI vel_motorB, 255 ; max
    CALL PWM

    RJMP salir


max_Atras: ;Genera PWM con velocidad normal hacia la izquierda

    LDI R16, 0B00000101
    OUT PORTA, R16
    LDI vel_motorA, 255 ;max
    LDI vel_motorB, 255 ;max
    CALL PWM

    RJMP salir

max_Izquierda: ;Genera PWM con velocidad normal hacia la izquierda

    LDI R16, 0B00001010
    OUT PORTA, R16
    LDI vel_motorA, 193 ; medio
    LDI vel_motorB, 255 ; maximo
    CALL PWM

    RJMP salir

max_Derecha: ;Genera PWM con velocidad normal hacia la izquierda

    LDI R16, 0B00001010
    OUT PORTA, R16
    LDI vel_motorA, 255 ; 
    LDI vel_motorB, 193 ; 
    CALL PWM

    RJMP salir

stop:
    
    CLR R16
    OUT PORTA, R16
    LDI vel_motorA, 0 ; 
    LDI vel_motorB, 0 ; 
    CALL PWM

    RJMP salir


    
    PWM:

    STS 0X60, vel_motorA
    STS 0X61, vel_motorB

    LDS R16, HIGH(0X60);LÍMITE SUPERIOR
    OUT OCR1AH, R16
    LDS R16, LOW(0X60)
    OUT OCR1AL, R16

    LDS R16, HIGH(0X61);LIMITE INFERIOR
    OUT OCR1BH, R16
    LDS R16, LOW(0X61)
    OUT OCR1BL, R16

    LDI R16, 0B10100010 ; palabra de control timer1, no invertido, modo 14 fast PWM
    OUT TCCR1A, R16
    LDI R16, 0B00011101 ; palabra de control timer1, modo 14 fast PWM, sin preescaler
    OUT TCCR1B, R16
    
    RET


    salir:
    POP R16
    OUT SREG, R16
    RETI
