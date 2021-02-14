/*
ENVÍO DE DATOS
	PC7 PC6 PC5 PC4 PC3 PC2 PC1 PC0
	DB7 DB6 DB5 DB4  -  E	RW	RS
PUERTOS:
	Puerto A: PA7 lectura de dipswitch
	Puerto B: PB2. Decremento de un minuto
	Puerto C: como se muestra arriba
	Puerto D: PD2. Selector de tipo de horario. PD3. Incremento de un minuto

	En este programa se emulará un reloj digital que puede cambiar su formato de horas (AM-PM/24hrs).
	Se hará esta selección mediante un dipswitch (0 - formato AM/PM. 1 - formato 24 hrs). 
	Se escribirá en formato:
						;;;;;;;;;;;;;;;;;
						;				;
						;00:00:00 AM/PM	;
						;;;;;;;;;;;;;;;;;
	Para el conteo del tiempo se utilizará el TIMER1 y se atenderá por interrupción
TIMER0: cuenta "30ms"
	cte = 30ms/(125ns * 1024) - 1 =  233.375 ~ 233. 233 para 29.952ms
TIMER1: cuenta un segundo
	cte = 1/(125ns * 256) - 1 = 31,249
RAM:
	00:00:00
	0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87

	Estado AM/PM:
	0x88. Almacena 'A' para indicar AM, 'P' para indicar PM
	0x89. Almacena 'M'
*/

.INCLUDE "M16ADEF.INC"
.EQU LCD_DDRx = DDRC
.EQU LCD_PORT = PORTC
.EQU LCD_PIN = PINC
.DEF sendLCD_Reg = R25
.DEF XY = R24
.DEF cont = R23
.ORG 0x00
RJMP main
.ORG 0x02			; INT0
RJMP cambioHorario
.ORG 0x04			; INT1
RJMP incrementoMinuto
.ORG 0x0C			; Compare A. Un segundo
RJMP conteoSegundo
.ORG 0x24			; INT2
RJMP decrementoMinuto
.ORG 0x26			; Compare Timer 0. 19.968ms
RJMP RFSH
main:
//Pila
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
//Puertos
	SBI PORTA, 7	; Pull-up del Dipswitch (selector AM/PM)
	SBI PORTB, 2	; Pull-up botón de decremento
	SBI PORTD, 2	; Pull-up del Dipswitch (selector de formato) (0 AM - 1 24hrs)
	SBI PORTD, 3	; Pull-up botón de incremento
	SER R16
	OUT LCD_DDRx, R16
//Inicializar LCD
	RCALL init_LCD
//Limpiar RAM
							; Escribir números en espacios de Memoria
	LDI R16, 1
	STS 0x80, R16
	LDI R16, 1
	STS 0x81, R16
	LDI R16, 5
	STS 0x83, R16
	LDI R16, 9
	STS 0x84, R16
	LDI R16, 5
	STS 0x86, R16
	LDI R16, 5
	STS 0x87, R16
							; Escribir ':' en espacios de Memoria
	LDI R16, ':'
	STS 0x82, R16
	STS 0x85, R16
							; Limpiar formato
	CLR R16
	STS 0x88, R16
	LDI R16, 'M'
	STS 0x89, R16
	LDI XY, 0x3C
	RCALL gotoXY_LCD 
	RCALL actualizarHora		; Hora inicial
//Timers
	//TIMER0
		LDI R16, 233
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
//Interrupciones
	//Interrupción Timer
		LDI R16, 0b00010010		; OCIE0, 0CIE1A
		OUT TIMSK, R16
	//Interrupción Externa
		LDI R16, 0b11100000
		OUT GICR, R16
		LDI R16, 0b00001101
		OUT MCUCR, R16
		LDI R16, 0b01000000
		OUT MCUCSR, R16

SBIS PIND, 2					; Revisar AM/PM 
RCALL decidirHorarioBoton
RCALL cursorOff_LCD
SEI 

fin: RJMP fin

;***************INTERRUPCIONES EXTERNAS****
//INT0 
cambioHorario: 
IN R16, SREG
PUSH R16
/*
	Lógica antirrebote
*/
SBIC PIND, 2	
RJMP logicaEn1
RCALL delay10ms				; Lógica en 0
SBIC PIND, 2				; Si sigue en mismo estado, sigue
RJMP salir					; No estuvo en mismo estado
RJMP rutina
logicaEn1:
RCALL delay10ms				; Lógica en 1
SBIS PIND, 2				; Si estuvo en mismo estado, sigue
RJMP salir					; No estuvo en mismo estado
rutina: 
	/* 
		En '0' se seleccionó formato AM/PM
		En '1' se seleccionó formato 24hrs
	*/
SBIC PIND, 2
RJMP subida
bajada:						; Estamos en '0'. Se leyó flanco de bajada (pasamos de 24hrs a AM/PM)
	;AQUÍ VA LÓGICA PARA CUANDO SE CAMBIA DE 24 HRS A AM/PM (si hora está entre 0-12, escribir el AM. Si está entre 13-23, restar 12 y escribir el PM)
	RCALL BCD3BIN8			
	LDS R16, 0x100			; Leemos la hora
	CPI R16, 12
	BRLO escribirAM
	BREQ escribirAM
	;Está entre 13-23
	SUBI R16, 12
	SEI
	STS 0x100, R16
	RCALL BIN8BCD3
	LDI R16, 'P'
	STS 0x88, R16
	RJMP salir
	escribirAM:
	LDI R16, 'A'
	STS 0x88,R16
RJMP salir
subida:						; Estamos en '1'. Se leyó flanco de subida (pasamos de AM/PM a 24hrs)
	LDS R16, 0x88			; Leer estado (AM/PM)
	CPI R16, 'A'			
	BRNE sumar12		
	RCALL BCD3BIN8
	LDS R16, 0x100
	CPI R16, 12				; (12 AM ¿?)
	BRNE salir				; Está en AM, no hay nada que modificar (1-11AM)
	RJMP restar
	RJMP salir				
	sumar12:				; Está en PM, hay que sumar 12 a las horas
	RCALL BCD3BIN8
	LDS R16, 0x100
	CPI R16, 12
	BREQ restar
	sumar:SUBI R16, -12
	RJMP seguirSubida
	restar: SUBI R16, 12
	seguirSubida:STS 0x100, R16
	RCALL BIN8BCD3
salir:
POP R16
OUT SREG, R16
RETI

//INT1
incrementoMinuto:

RETI
//INT2
decrementoMinuto:

RETI
;***************INTERRUPCIONES EXTERNAS****
;***************INTERRUPCIÓN TIMER*********
//TIMER0
RFSH:IN R16, SREG
PUSH R16
	RCALL clearHorario			; Desaparecer AM/PM
	SBIS PIND, 2			; En '1' implica que queremos formato 24hrs
	RCALL decidirHorario
	LDI XY, 0x3C
	RCALL gotoXY_LCD 
	RCALL actualizarHora
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
;***************FUNCIONES VISUALIZACIÓN****
BCD3BIN8:
PUSH XL
PUSH XH
PUSH cont
LDI cont, 3
CLR XH
LDI XL, 0x7F
guardarLamparas1: LD R16, X+
PUSH R16
DEC cont
BRNE guardarLamparas1
CLR R16
STS 0x100, R16
sN0e:
LDS R16, 0x81
TST R16
BRNE dBCDb
LDS R16, 0x80
TST R16
BRNE dBCDb
LDS R16, 0x7F
TST R16
BRNE dBCDb
RJMP retRutina1
dBCDb:
LDI YL, 0x81
CLR YH
dBCDbL:
LD R16, Y
DEC R16
ST Y, R16
CPI R16, 0xFF
BRNE incBinB
LDI R16, 9
ST Y, R16
DEC YL
CPI YL, 0x7E
BRNE dBCDbL
incBinB:
LDS R16, 0x100
INC R16
STS 0x100, R16
RJMP sN0e
retRutina1:
LDI cont, 3
CLR XH
LDI XL, 0x82	;Primero decrementa, luego vacía
regresarLamparas1: POP R16
ST -X, R16
DEC cont
BRNE regresarLamparas1
POP cont
POP XH
POP XL
RET

BIN8BCD3:
PUSH XL
PUSH XH
PUSH cont
LDI cont, 1
LDI XH, HIGH(0x100)
LDI XL, LOW(0x100)
guardarBinario1: LD R16, X+
PUSH R16
DEC cont
BRNE guardarBinario1
CLR R16
STS 0x81, R16
STS 0x80, R16
STS 0x7F, R16
sN0c:
LDS R16, 0x100
TST R16
BRNE iBCDc
RJMP retRutina4
iBCDc:
LDI YL, LOW(0x81)
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
CPI YL, 0x7E
BRNE iBCDLc
dBinc:
LDS R16, 0x100
DEC R16
STS 0x100, R16
RJMP sN0c
retRutina4:
LDI cont, 1
LDI XH , HIGH(0x101)
LDI XL, LOW(0x101)	;Primero decrementa, luego vacía
regresarBinario1: POP R16
ST -X, R16
DEC cont
BRNE regresarBinario1
POP cont
POP XH
POP XL
RET
;***************FUNCIONES VISUALIZACIÓN****
;***************FUNCIONES GENERALES********
incrementoHora:
	/*
	 Revisiones: se hace el incremento con la lógica de un reloj
	 Incrementos: se incrementan los números pertinentes
		*incrementarUnidadHora
	*/
	//Revisiones
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
										; Incremento Deceno de Hora
	RJMP retornar

	//Incrementos
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
	SBIC PIND, 2
	RJMP formato24hrs
	CPI R16, 2							; R16 tiene el contenido de 0x81 (Unidad de Hora)
	BRNE formato24hrs
	LDS R16, 0x80
	CPI R16, 1							; Hay un 12:xx:xx y quiere incrementar. Debemos continuar con un 01:xx:xx
	BRNE formato24hrs
	LDI R16, 1
	STS 0x81, R16
	CLR R16
	STS 0x80, R16
	//Se INDICA que debe hacerse cambio AM -> PM / PM -> AM
	LDI R22, 1
	RJMP retornar
	formato24hrs:
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

actualizarHora:
	LDI XH, HIGH(0x80)
	LDI XL, LOW(0x80)
	LDI cont, 8
	escribirHora:
	LD sendLCD_Reg, X+
	CPI sendLCD_Reg, ':'
	BRNE numero
	RCALL send4bits_LCD
	RJMP decremento
	numero:RCALL sendASCII_LCD
	decremento: DEC cont
	BRNE escribirHora
RET

clearHorario:
PUSH XY
LDI XY, 0xCC
RCALL gotoXY_LCD 
LDI sendLCD_Reg, ' '
LDI cont, 4
clear: RCALL send4bits_LCD
DEC cont
BRNE clear
POP XY
RET
decidirHorario:
	CPI R22, 1
	BRNE noTransicion
	LDS R16, 0x88						// Sí hay transición
	CPI R16, 'A'						; ¿Estamos en AM o PM?
	BREQ cambioPM
	LDI XY, 0xCC						//cambio AM
	RCALL gotoXY_LCD 			
	LDI ZH,HIGH(AM<<1)
	LDI ZL,LOW(AM<<1)
	LDI R16, 'A'
RJMP escribirTransicion
cambioPM:		
LDI XY, 0xEC
RCALL gotoXY_LCD 	
	LDI ZH,HIGH(PM<<1)
	LDI ZL,LOW(PM<<1)
	LDI R16, 'P'
escribirTransicion:STS 0x88, R16
LDI cont, 2
RCALL sendData_LCD
CLR R22
RET
notransicion:
	LDS R16, 0x88						// No hay transición
	CPI R16, 'A'						; ¿Estamos en AM o PM?
	BRNE mantenerPM
	LDI XY, 0xCC						//mantenerAM
	RCALL gotoXY_LCD 			
	LDI ZH,HIGH(AM<<1)
	LDI ZL,LOW(AM<<1)
	LDI R16, 'A'
RJMP escribirNoTransicion
mantenerPM:		
LDI XY, 0xEC
RCALL gotoXY_LCD 	
	LDI ZH,HIGH(PM<<1)
	LDI ZL,LOW(PM<<1)
	LDI R16, 'P'
escribirNoTransicion:STS 0x88, R16
LDI cont, 2
RCALL sendData_LCD
RET

decidirHorarioBoton:
RCALL clearHorario
SBIS PINA, 7
RJMP saltoPM
saltoAM:
LDI XY, 0xCC
RCALL gotoXY_LCD 			
	LDI ZH,HIGH(AM<<1)
	LDI ZL,LOW(AM<<1)
	LDI R16, 'A'
RJMP escribir
saltoPM:		
LDI XY, 0xEC
RCALL gotoXY_LCD 	
	LDI ZH,HIGH(PM<<1)
	LDI ZL,LOW(PM<<1)
	LDI R16, 'P'
escribir:STS 0x88, R16
LDI cont, 2
RCALL sendData_LCD
RET
;***************FUNCIONES GENERALES********
;***************FUNCIONES LCD**************
	;init_LCD: inicializa LCD
	;send4bits_LCD: envía datos contenidos en R25
	;busy_LCD: espera a que LCD esté lista para otra instrucción/dato
	;gotoXY_LCD: envía cursor a dirección en registro XY
	;sendData_LCD: envía el número de caracteres a partir de la dirección del apuntador Z
	;sendASCII_LCD: envía el caracter ASCII correspondiente a un número
	;clearHome_LCD: envía a primer espacio de LCD y borra todo lo desplegado
	;home_LCD: regresa cursor a primer espacio de LCD
	;cursorOff_LCD: detiene blink y desactiva el cursor
	;cursorOn_LCD: activa blink y activa cursor
	;cursorLeft_LCD: mueve el cursor una posición hacia la izquierda
	;cursorRight_LCD: mueve el cursor una posición hacia la derecha
	;shiftLeft_LCD: mueve todo el display una posición hacia la izquierda
	;shiftRight_LCD: mueve todo el display una posición hacia la derecha
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
clearHome_LCD:
	CLT
	LDI sendLCD_Reg, 0b00000001
	RCALL send4bits_LCD
	SET
	RCALL delay500us
	RCALL delay500us
RET
home_LCD:
	CLT
	LDI sendLCD_Reg, 0b00000010
	RCALL send4bits_LCD
	SET
	RCALL delay500us
	RCALL delay500us
RET
cursorOff_LCD:
	CLT
	LDI sendLCD_Reg, 0b00001100
	RCALL send4bits_LCD
	SET
RET
cursorOn_LCD:
	CLT
	LDI sendLCD_Reg, 0b0001111
	RCALL send4bits_LCD
	SET
RET
cursorLeft_LCD:
	CLT
	LDI sendLCD_Reg, 0b00010000
	RCALL send4bits_LCD
	SET
RET
cursorRight_LCD:
	CLT
	LDI sendLCD_Reg, 0b00010100
	RCALL send4bits_LCD
	SET
RET
shiftLeft_LCD:
	CLT
	LDI sendLCD_Reg, 0b00011000
	RCALL send4bits_LCD
	SET
RET
shiftRight_LCD:
	CLT
	LDI sendLCD_Reg, 0b00011100
	RCALL send4bits_LCD
	SET
RET
chars_LCD:
	LDI ZH, HIGH(Codechars << 1)
	LDI ZL, LOW(Codechars)
LcdChars1:
	LPM R16, Z						; Leer caracter
	TST R16							; ¿Final de la tabla? (0)
	BREQ LcdChars3					; Salir
	LDI	XY, 0x08					; Posicionar cursor
LcdChars2:
	MOV sendLCD_Reg, R16
	RCALL send4bits_LCD
	LPM sendLCD_Reg, Z+
	RCALL send4bits_LCD
	INC R16
	DEC XY
	BRNE LcdChars2
	RJMP LcdChars1
LcdChars3:
	RET
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

;***************FLASH**********************
Codechars:
.db 64,0,10,14,10,0,14,10,14,8 ; C = 0, HP
.db 72,0,0,0,0,0,0,0,0,0 ; C = 1, Description 1
.db 80,0,0,0,0,0,0,0,0,0 ; C = 2, Description 2
.db 88,0,0,0,0,0,0,0,0,0 ; C = 3, Description 3
.db 96,0,0,0,0,0,0,0,0,0 ; C = 4, Description 4
.db 104,0,0,0,0,0,0,0,0,0 ; C = 5, Description 5
.db 112,0,0,0,0,0,0,0,0,0 ; C = 6, Description 6
.db 120,0,0,0,0,0,0,0,0,0 ; C = 7, Description 7
.db 0,0 ; End of table

.ORG 0x300
AM: .DB "AM"
PM: .DB "PM"
