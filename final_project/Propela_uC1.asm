/*
DISPOSITIVO: ATmega16A 40-pin-PDIP
PUERTOS:
	Puerto A: PA0 a Potenciómetro con ADC single-ended.
	Puerto B: -
	Puerto C:
		PC7 PC6 PC5 PC4 PC3 PC2 PC1 PC0
		DB7 DB6 DB5 DB4  -  E	RW	RS
	Puerto D: PD1 (Tx). PD2 (INT0). Incremento de Cantidad PD3 (INT1). Decremento de Cantidad
	PD5. Selector de Color
	PD6. Selector para editar Unidades Minuto
	PB7. Selector para editar Unidades Hora	
	AVCC a VCC
LCD:
	16x2.
	Ejemplo
						;;;;;;;;;;;;;;;;;
						;Blue	100%	;
						;	00:00:00	;
						;;;;;;;;;;;;;;;;;
						;;;;;;;;;;;;;;;;;
						;Green	100%	;
						;	16:43:15	;
						;;;;;;;;;;;;;;;;;
INTERRUPCIONES:
 TIMER:
	TIMER0: cuenta 256ms (25.6ms * 10).
		cte = 25.6ms/(125ns * 1024) - 1 =  200 - 1 = 199
		Modo CT
		Prescaler 1024
	TIMER1: cuenta un segundo
		cte = 1/(125ns * 256) - 1 = 31,249
		TX
	ADC:
		ADC0 single-ended
	EXTERNAS:
		INT0. Activo en Flanco de Bajada
		INT1. Activo en Flanco de Bajada
RAM:
	00:00:00
	0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87
	Color - 0x88
	ADC - 0x89
*/

.INCLUDE "M16ADEF.INC"
.EQU LCD_DDRx = DDRC
.EQU LCD_PORT = PORTC
.EQU LCD_PIN = PINC
.DEF sendLCD_Reg = R25
.DEF XY = R24
.DEF cont = R23
.DEF cont256ms = R22
.ORG 0x00
RJMP main
.ORG 0x02			; INT0
RJMP incremento
.ORG 0x04			; INT1
RJMP decremento
.ORG 0x0C			; Compare A. Un segundo
RJMP conteoSegundo
.ORG 0x1C			; Interrupción ADC
RJMP brilloADC		
.ORG 0x26			; Compare Timer 0. 25.6ms 
RJMP RFSH

main:
//Pila
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
//Puertos
	SER R16
	OUT LCD_DDRx, R16
	SBI DDRD, 1		; Tx
	SBI PORTD, 2	; Pull-up botón de incremento
	SBI PORTD, 3	; Pull-up botón de decremento
	SBI PORTD, 5	; Pull-up selector de color (0 - Rojo, 1 - Azul)
	SBI PORTD, 6	; Pull-up del Switch de Unidades Minuto
	SBI PORTD, 7	; Pull-up del Switch de Unidades Hora
//Inicializar LCD
	RCALL init_LCD
//Escribir números en espacios de Memoria
	RCALL editRAM
//Escribir en LCD 
	; Hora Inicial
	RCALL actualizarHora
//Timers
	//TIMER0
		LDI R16, 199
		OUT OCR0, R16
		LDI R16, 0b00001101
		OUT TCCR0, R16
	//TIMER1
		LDI R16, HIGH(31249)
		OUT OCR1AH, R16
		LDI R16, LOW(31249)
		OUT OCR1AL, R16
		CLR R16
		OUT TCCR1A, R16
		LDI R16, 0b00001100
		OUT TCCR1B, R16
//ADC
	LDI R16, 0b01000000				; AVCC Ref. ADC0+ GND-
	OUT ADMUX, R16
	LDI R16, 0b10001111				
	OUT ADCSRA, R16
//Serial
	LDI R16, 0b10000110				; Asíncrono (6). Disable (5 4). 1 stop bit (3). 8 character size (2 1). No Polaridad (0)
	OUT UCSRC, R16			
	LDI R16, 0b00001000				; Enable Tx
	OUT UCSRB, R16
	LDI R16, 51
	OUT UBRRL, R16					; 9600 baud rate
//Interrupciones
	//Interrupción Timer
		LDI R16, 0b00010010			; OCIE0, 0CIE1A
		OUT TIMSK, R16
	//Interrupción Externa
		LDI R16, 0b11000000			; INT1-INT0 Habilitados
		OUT GICR, R16
		LDI R16, 0b00001010			; Flanco de Bajada en ambos
		OUT MCUCR, R16
//Inicialización
		LDI cont256ms, 10			; Entrar 10 veces a Interrupción Timer0 para 256ms
		SBI ADSC, ADCSRA				;Iniciar conversión
RCALL cursorOff_LCD
SEI				
fin: RJMP fin

;***************INTERRUPCIONES EXTERNAS****
//INT0
incremento:
IN R16, SREG
PUSH R16
RCALL delay10ms
RCALL delay10ms
SBIC PIND, 2
RJMP salir				; Antirrebote 

SBIS PIND, 6			; 0 significa que quieres cambiar Unidades de Minutos
CALL incrementoUnidadMinuto
SBIS PIND, 7			; 0 significa que quieres cambiar Unidades de Horas
CALL incrementoUnidadHora

salir: POP R16
OUT SREG, R16
RETI
//INT1
decremento:
IN R16, SREG
PUSH R16
RCALL delay10ms
RCALL delay10ms
SBIC PIND, 3
RJMP salirInt2			; Antirrebote 

SBIS PIND, 6			; 0 significa que quieres cambiar Unidades de Minutos
CALL decrementoUnidadMinuto
SBIS PIND, 7			; 0 significa que quieres cambiar Unidades de Horas
CALL decrementoUnidadHora

salirInt2:
POP R16
OUT SREG, R16
RETI
;***************INTERRUPCIONES EXTERNAS****
;***************INTERRUPCIÓN TIMER*********
//TIMER0
RFSH:IN R16, SREG
PUSH R16
DEC cont256ms
BRNE salirRFSH
LDI cont256ms, 10		; Ya pasaron 256ms
	RCALL actualizarHora
	RCALL seleccionColor
	RCALL envioSerial
	SBI ADSC, ADCSRA	; Iniciar siguiente conversión de ADC
salirRFSH:
POP R16
OUT SREG, R16
RETI
//TIMER1
conteoSegundo: IN R16, SREG
PUSH R16
	RCALL incrementoHora
POP R16
OUT SREG, R16
RETI
;***************INTERRUPCIÓN TIMER*********
;***************INTERRUPCIÓN ADC***********
brilloADC: IN R16, SREG
PUSH R16
	IN R16, ADCL
	STS 0x100, R16
	IN R16, ADCH
	STS 0x101, R16			; 0x101:0x100
	CALL div4				; Se divide entre 4 el valor leído por ADC 
							; 0x89 contiene número a enviarse por serial
	LDS R16, 0x89
	LDI XY, 0xB8
	RCALL gotoXY_LCD
	LDI ZH, HIGH(LUT<<1)
	LDI ZL, LOW(LUT<<1)
	ADD ZL, R16				; Nos lleva a número correspondiente en LUT
	LPM R16, Z
	STS 0x102, R16
	RCALL BIN8BCD3
	LDS sendLCD_Reg, 0x8F
	CALL sendASCII_LCD
	LDS sendLCD_Reg, 0x90
	CALL sendASCII_LCD
	LDS sendLCD_Reg, 0x91
	CALL sendASCII_LCD
	LDI sendLCD_Reg, '%'
	CALL send4bits_LCD
POP R16
OUT SREG, R16
RETI
;***************INTERRUPCIÓN ADC***********
;***************FUNCIONES GENERALES********
;EDITAR RAM
editRAM:
	LDI R16, 1
	STS 0x80, R16
	LDI R16, 3
	STS 0x81, R16
	LDI R16, 3
	STS 0x83, R16
	LDI R16, 8
	STS 0x84, R16
	LDI R16, 0
	STS 0x86, R16
	LDI R16, 0
	STS 0x87, R16
							; Escribir ':' en espacios de Memoria
	LDI R16, ':'
	STS 0x82, R16
	STS 0x85, R16
							; Limpiar formato
	RCALL seleccionColor
	CLR R16
	STS 0x89, R16
RET
;SELECCIONAR COLOR
seleccionColor:
	; 0 - Rojo. 1 - Azul
	SBIC PIND, 5
	RJMP azul
	rojo: LDI R16, 'R'					; 'R' = Rojo
	RJMP asignar
	azul: LDI R16, 'B'		; 'A' = Azul
asignar:
	STS 0x88, R16
	; Mostrar en LCD
	LDS R16, 0x88
	CPI R16, 'B'
	BRNE rojoROM
	LDI ZH,HIGH(Blue<<1)
	LDI ZL,LOW(Blue<<1)
	rjmp escribirColor
	rojoROM:
	LDI ZH,HIGH(Red<<1)
	LDI ZL,LOW(Red<<1)
	escribirColor:
	LDI XY, 0x08
	RCALL gotoXY_LCD
	LDI cont, 4
	RCALL sendData_LCD
RET
;ENVÍO POR SERIAL
envioSerial:
	CLI
	/*
	;DESPLEGAR EN ARDUINO:

	LDS R16, 0x80		;0
	SUBI R16, -0x30
	OUT UDR, R16
	CALL enviandoTx

	LDS R16, 0x81		;0
	SUBI R16, -0x30
	OUT UDR, R16
	CALL enviandoTx

	LDS R16, 0x82		;:
	OUT UDR, R16
	CALL enviandoTx

	LDS R16, 0x83		;0
	SUBI R16, -0x30
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x84		;0
	SUBI R16, -0x30
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x85		;:
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x86		;0
	SUBI R16, -0x30
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x87		;0
	SUBI R16, -0x30
	OUT UDR, R16
	CALL enviandoTx

	LDS R16, 0x88		;'R' - 'B'
	OUT UDR, R16
	CALL enviandoTx

	LDS R16, 0x89		;0-255
	OUT UDR, R16
	CALL enviandoTx
	*/

	LDI R16, 'I'		; Marca inicio de comunicación
	OUT UDR, R16
	CALL enviandoTx

	LDS R16, 0x80		;_0:00:00BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x81		;0_:00:00BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x82		;00_00:00BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x83		;00:_0:00BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x84		;00:0_:00BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x85		;00:00_00BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x86		;00:00:_0BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x87		;00:00:0_BC
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x88		;00:00:00_C
	OUT UDR, R16
	CALL enviandoTx
	LDS R16, 0x89		;00:00:00B_
	OUT UDR, R16
	CALL enviandoTx
	SEI
RET

enviandoTx:
send: SBIS UCSRA, UDRE
RJMP send
CALL delay10ms
RET
;DIVISIÓN PARA ADC
div4:
	LDS R3, 0x101
	LDS R2, 0x100		; R3:R2
	//División
	LSR R3
	ROR R2				; /2
	LSR R3
	ROR R2				; /4. R2 contiene resultado
	STS 0x89, R2
RET

;INCREMENTO PARA TIMER1
incrementoHora:
	LDS R16, 0x87						; Revisar Unidad de Segundo
	CPI R16, 9
	BRNE incrementarUnidadSegundo
	CLR R16
	STS 0x87, R16						; Limpiar Unidad de Segundo
	LDS R16, 0x86						; Revisar Decena de Segundo
	CPI R16, 5
	BRNE incrementarDecenaSegundo
	CLR R16
	STS 0x86, R16						; Limpiar Decena de Segundo
	LDS R16, 0x84						; Revisar Unidad de Minuto
	CPI R16, 9
	BRNE incrementarUnidadMinuto
	CLR R16
	STS 0x84, R16						; Limpiar Unidad de Minuto
	LDS R16, 0x83						; Revisar Decena de Minuto
	CPI R16, 5
	BRNE incrementarDecenaMinuto
	CLR R16
	STS 0x83, R16						; Limpiar Decena de Minuto
	LDS R16, 0x81						; Revisar Unidad de Hora
	CPI R16, 9
	BRNE incrementarUnidadHora
	CLR R16
	STS 0x81, R16						; Limpiar Unidad de Hora
	LDS R16, 0x80						; Revisar Decena de Hora
	INC R16
	STS 0x80, R16
	RJMP retornar

	incrementarUnidadSegundo:
	INC R16
	STS 0x87, R16
	RJMP retornar
	incrementarDecenaSegundo:
	INC R16
	STS 0x86, R16
	RJMP retornar
	incrementarUnidadMinuto:
	INC R16
	STS 0x84, R16
	RJMP retornar
	incrementarDecenaMinuto:
	INC R16
	STS 0x83, R16
	RJMP retornar
	incrementarUnidadHora:
	MOV R15, R16
	CPI R16, 3							; R16 tiene el contenido de 0x81 (Unidad de Hora)
	BRNE seguirReloj
	LDS R16, 0x80
	CPI R16, 2							; Hay un 23:xx:xx y quiere incrementar. Debemos resettear
	BRNE seguirReloj
	CLR R16
	STS 0x81, R16
	STS 0x80, R16
	RJMP retornar
	seguirReloj:
	MOV R16, R15
	INC R16
	STS 0x81, R16
retornar:
RET

;ACTUALIZACIÓN PARA TIMER0 (RFSH)
actualizarHora:
	;Enviar a LCD contenido de direcciones de memoria 0x80 - 0x87 a partir de C3
	LDI XY, 0x3C
	RCALL gotoXY_LCD 
	LDI XH, HIGH(0x80)
	LDI XL, LOW(0x80)
	LDI cont, 8
	escribirHora:
	LD sendLCD_Reg, X+
	CPI sendLCD_Reg, ':'
	BRNE numero
	RCALL send4bits_LCD
	RJMP decrementoAuto
	numero:RCALL sendASCII_LCD
	decrementoAuto: DEC cont
	BRNE escribirHora
RET

;INCREMENTAR MINUTO POR BOTÓN
incrementoUnidadMinuto:
	LDS R16, 0x84						; Revisar Unidad de Minuto
	CPI R16, 9
	BRNE incrementarUMinuto
	CLR R16
	STS 0x84, R16						; Limpiar Unidad de Minuto
	LDS R16, 0x83						; Revisar Decena de Minuto
	CPI R16, 5
	BRNE incrementarDMinuto
	CLR R16
	STS 0x83, R16						; Limpiar Decena de Minuto
	LDS R16, 0x81						; Revisar Unidad de Hora
	CPI R16, 9
	BRNE incrementarUHora
	CLR R16
	STS 0x81, R16						; Limpiar Unidad de Hora
	LDS R16, 0x80						; Revisar Decena de Hora
	INC R16
	STS 0x80, R16
	RJMP regresar
	incrementarUMinuto:
	INC R16
	STS 0x84, R16
	RJMP regresar
	incrementarDMinuto:
	INC R16
	STS 0x83, R16
	RJMP regresar
	incrementarUHora:
	MOV R15, R16
	CPI R16, 3							; R16 tiene el contenido de 0x81 (Unidad de Hora)
	BRNE seguirReloj2
	LDS R16, 0x80
	CPI R16, 2							; Hay un 23:xx:xx y quiere incrementar. Debemos resettear
	BRNE seguirReloj2
	CLR R16
	STS 0x81, R16
	STS 0x80, R16
	RJMP regresar
	seguirReloj2:
	MOV R16, R15
	INC R16
	STS 0x81, R16
regresar:
RET
;INCREMENTAR HORA POR BOTÓN
incrementoUnidadHora:
	LDS R16, 0x81						; Revisar Unidad de Hora
	CPI R16, 9
	BRNE incrementarUHora2
	CLR R16
	STS 0x81, R16						; Limpiar Unidad de Hora
	LDS R16, 0x80						; Revisar Decena de Hora
	INC R16
	STS 0x80, R16
	RJMP regresar2
	incrementarUHora2:
	MOV R15, R16
	CPI R16, 3							; R16 tiene el contenido de 0x81 (Unidad de Hora)
	BRNE seguirReloj3
	LDS R16, 0x80
	CPI R16, 2							; Hay un 23:xx:xx y quiere incrementar. Debemos resettear
	BRNE seguirReloj3
	CLR R16
	STS 0x81, R16
	STS 0x80, R16
	RJMP regresar2
	seguirReloj3:
	MOV R16, R15
	INC R16
	STS 0x81, R16
regresar2:
RET
;DECREMENTO DE MINUTO POR BOTÓN
decrementoUnidadMinuto:
	LDS R16, 0x84						; Revisar Unidad de Minuto
	CPI R16, 0
	BRNE decrementarUnidadMinuto
	LDI R16, 9
	STS 0x84, R16						; Unidad de Minuto con 9
	LDS R16, 0x83						; Revisar Decena de Minuto
	CPI R16, 0
	BRNE decrementarDecenaMinuto
	LDI R16, 5
	STS 0x83, R16
	LDS R16, 0x81						; Revisar Unidad de Hora
	CPI R16, 0
	BRNE decrementarUnidadHora
	LDS R16, 0x80						; Revisar Decena Hora
	CPI R16, 0
	BRNE decrementoHora
	LDI R16, 3
	STS 0x81, R16
	LDI R16, 2
	STS 0x80, R16
	RJMP regresar4
	decrementarUnidadMinuto:
	DEC R16
	STS 0x84, R16
	RJMP regresar4
	decrementarDecenaMinuto:
	DEC R16
	STS 0x83, R16
	RJMP regresar4
	decrementarUnidadHora:
	DEC R16
	STS 0x81, R16
	RJMP regresar4
	decrementoHora:
	DEC R16
	STS 0x80, R16
	LDI R16, 9
	STS 0x81, R16
regresar4:
RET
;DECREMENTO DE HORA POR BOTÓN
decrementoUnidadHora:
	LDS R16, 0x81						; Revisar Unidad de Hora
	CPI R16, 0
	BRNE decrementarUnidadHora2
	LDS R16, 0x80						; Revisar Decena Hora
	CPI R16, 0
	BRNE decrementoHora2
	LDI R16, 3
	STS 0x81, R16
	LDI R16, 2
	STS 0x80, R16
	RJMP regresar5
	decrementarUnidadHora2:
	DEC R16
	STS 0x81, R16
	RJMP regresar5
	decrementoHora2:
	DEC R16
	STS 0x80, R16
	LDI R16, 9
	STS 0x81, R16
regresar5:
RET
;***************FUNCIONES GENERALES********
;***************FUNCIONES VISUALIZACIÓN****
BIN8BCD3:
PUSH XL
PUSH XH
PUSH cont
LDI cont, 1
LDI XH, HIGH(0x102)
LDI XL, LOW(0x102)
guardarBinario1: LD R16, X+
PUSH R16
DEC cont
BRNE guardarBinario1
CLR R16
STS 0x91, R16
STS 0x90, R16
STS 0x8F, R16
sN0c:
LDS R16, 0x102
TST R16
BRNE iBCDc
RJMP retRutina4
iBCDc:
LDI YL, LOW(0x91)
CLR YH
iBCDLc:
LD R16, Y
INC R16
ST Y, R16
CPI R16, 10
BRNE dBinc
CLR R16
ST Y, R16
DEC YL
CPI YL, 0x8E
BRNE iBCDLc
dBinc:
LDS R16, 0x102
DEC R16
STS 0x102, R16
RJMP sN0c
retRutina4:
LDI cont, 1
LDI XH , HIGH(0x103)
LDI XL, LOW(0x103)	;Primero decrementa, luego vacía
regresarBinario1: POP R16
ST -X, R16
DEC cont
BRNE regresarBinario1
POP cont
POP XH
POP XL
RET
;***************FUNCIONES LCD**************
	;init_LCD: inicializa LCD
	;send4bits_LCD: envía datos contenidos en R25
	;busy_LCD: espera a que LCD esté lista para otra instrucción/dato
	;gotoXY_LCD: envía cursor a dirección en registro XY
	;sendData_LCD: envía el número de caracteres a partir de la dirección del apuntador Z
	;sendASCII_LCD: envía el caracter ASCII correspondiente a un número
	;cursorOff_LCD: detiene blink y desactiva el cursor
init_LCD:
	RCALL delay10ms
	RCALL delay10ms
	RCALL delay10ms
	RCALL delay10ms
	RCALL delay10ms							; 50ms de espera (49.934 ms)
	LDI sendLCD_Reg,0b00101000				; DL: 4 bit interface. N: 2 lines. F: 5x8 dots
	RCALL send4bits_LCD
	RCALL delay5ms							; 5ms de espera (4.994 ms)
	LDI sendLCD_Reg,0b00000110				; I/D: incrementa cursor. No display shift 
	RCALL send4bits_LCD
	RCALL delay5ms							; 5ms de espera
	LDI sendLCD_Reg,0b00001111				; D: Display ON. C: Cursor ON. B: Blink ON .
	RCALL send4bits_LCD
	RCALL delay5ms							; 5ms de espera
	LDI sendLCD_Reg,0b00000001				; Clear Display and Cursor to Home
	RCALL send4bits_LCD
	RCALL delay10ms							//76.86ms
RET
send4bits_LCD:
	PUSH R16
	PUSH R17
	PUSH R24
	BRID seguirNoInt
	CLI									; Apagar interrupciones en caso de que estuvieran encendidas
	INC R17								; Indicador de que estuvo encendida
	seguirNoInt: LDI R16,2				; Dos nibbles en un byte. Primero se envía nibble superior y luego nibble inferior
	MOV R24,sendLCD_Reg	
envioNibbles:
	ANDI R24,0xF0						; Nibble superior únicamente
	BRTS dato							; Si es un dato, deberá enviarse como dato
instruccion:							; En caso contrario, es instrucción
	SUBI R24,-4							; Activar enable  E-RW-RS (100)
	OUT LCD_PORT,R24					; Datos salen por Puerto C
	NOP
	NOP
	NOP									; 3 ciclos de máquina
	CBI LCD_PORT,2						; CLR pin. Flanco de bajada
	DEC R16								; Decrementar contador
	BREQ final 
	MOV R24,sendLCD_Reg
	SWAP R24
	RJMP envioNibbles
dato:
	INC R24								; sumo bits E-RW-RS (101)	
	RJMP instruccion		
final:
	RCALL delay500us
	RCALL busy_LCD
	CPI R17, 1							; Revisamos si estuvo encendida la bandera
	BRNE seguirInt
	SEI									; Volvemos a activarlas
	seguirInt:POP R24
	POP R17
	POP R16
RET
busy_LCD:
PUSH R2
	CLR R2
	OUT LCD_PORT, R2					; RS = 0
	SBI LCD_PORT, 1						; RW = 1
	CBI LCD_DDRx, 7						; Habilidar PC7 para lectura
pollingFlag:	
	SBIC LCD_PIN, 7						; Polling del pin del PC7
	RJMP pollingFlag
	SBI LCD_DDRx, 7						; Habilitar PC7 para escritura
POP R2
RET
gotoXY_LCD:
	CLT
	MOV sendLCD_Reg, XY
	SWAP sendLCD_Reg
	RCALL send4bits_LCD
	SET
RET
sendData_LCD:
dataLoop:LPM sendLCD_Reg, Z+
	RCALL send4bits_LCD
	DEC cont
	BRNE dataLoop
RET
sendASCII_LCD:
PUSH R2
	MOV R2, sendLCD_Reg
	SUBI sendLCD_Reg, -0x30
	RCALL send4bits_LCD
	MOV sendLCD_Reg, R2
POP R2
RET
cursorOff_LCD:
	CLT
	LDI sendLCD_Reg, 0b00001100
	RCALL send4bits_LCD
	SET
RET
delay10ms:
PUSH R20
PUSH R21
	LDI R20, 104			
	cicloc:	
		LDI R21 ,255 
		ciclod:	
			DEC R21 
		BRNE ciclod
			DEC R20
	BRNE cicloc
POP R21
POP R20
RET
delay5ms:
PUSH R20
PUSH R21
	LDI R20, 52			
	cicloe:	
		LDI R21 ,255 
		ciclof:	
			DEC R21 
		BRNE ciclof
			DEC R20
	BRNE cicloe
POP R21
POP R20
RET
delay500us:	
PUSH R20	
PUSH R21				
	LDI R20, 5			
	cicloa:	
		LDI R21 ,255 
		ciclob:DEC R21 
		BRNE ciclob
		DEC R20
	BRNE cicloa
POP R21
POP R20
RET
;***************FUNCIONES LCD**************
;***************FUNCIONES VISUALIZACIÓN****
;***************FLASH**********************
.ORG 0x300
Blue: .DB "Blue"
Red: .DB "Red "

.ORG 0x500
LUT:
.DB 0, 0, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5
.DB 5, 5, 6, 6, 7, 7, 7, 8, 8, 9, 9, 9
.DB 10, 10, 11, 11, 11, 12, 12, 13, 13, 13, 14, 14
.DB 15, 15, 15, 16, 16, 16, 17, 17, 18, 18, 18, 19
.DB 19, 20, 20, 20, 21, 21, 22, 22, 22, 23, 23, 24
.DB 24, 24, 25, 25, 25, 26, 26, 27, 27, 27, 28, 28
.DB 29, 29, 29, 30, 30, 31, 31, 31, 32, 32, 33, 33
.DB 33, 34, 34, 35, 35, 35, 36, 36, 36, 37, 37, 38
.DB 38, 38, 39, 39, 40, 40, 40, 41, 41, 42, 42, 42
.DB 43, 43, 44, 44, 44, 45, 45, 45, 46, 46, 47, 47
.DB 47, 48, 48, 49, 49, 49, 50, 50, 51, 51, 51, 52
.DB 52, 53, 53, 53, 54, 54, 55, 55, 55, 56, 56, 56
.DB 57, 57, 58, 58, 58, 59, 59, 60, 60, 60, 61, 61
.DB 62, 62, 62, 63, 63, 64, 64, 64, 65, 65, 65, 66
.DB 66, 67, 67, 67, 68, 68, 69, 69, 69, 70, 70, 71
.DB 71, 71, 72, 72, 73, 73, 73, 74, 74, 75, 75, 75
.DB 76, 76, 76, 77, 77, 78, 78, 78, 79, 79, 80, 80
.DB 80, 81, 81, 82, 82, 82, 83, 83, 84, 84, 84, 85
.DB 85, 85, 86, 86, 87, 87, 87, 88, 88, 89, 89, 89
.DB 90, 90, 91, 91, 91, 92, 92, 93, 93, 93, 94, 94
.DB 95, 95, 95, 96, 96, 96, 97, 97, 98, 98, 98, 99
.DB 99, 100, 100