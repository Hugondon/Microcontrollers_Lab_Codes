/*
DISPOSITIVO: ATmega16A 40-pin-PDIP
PUERTOS:
	Puerto A: PA0 - PA4 a resistencia -330- LEDs Azules (000x xxxx) que van a Colector de Transistor tipo NPN
	Puerto B: PA0 - PA4 a resistencia -330- LEDs Rojos  (000x xxxx) que van a Colector de Transistor tipo NPN
	Puerto C: PC0 - PC1 a resistencia -330- LEDs Verdes
	Puerto D: PD0 (Rx). PD6 (ICP) a pin de señal de Sensor de Efecto Hall. PD7 (OC2) a resistencia de 100 a Base de Transistor tipo NPN
INTERRUPCIONES:
	RX: Recepción de 11 bytes.
	ICP: detección de Flanco de Bajada
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
.DEF contHall = R22
.ORG 0x00
RJMP main
.ORG 0x0A
RJMP hallSensor
.ORG 0x16
RJMP RX
main:
//Pila
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
//Puertos
	LDI R16, 0b00011111
	OUT DDRA, R16					; LEDs Azules
	OUT DDRB, R16					; LEDs Rojos
	SER R16
	OUT LCD_DDRx, R16				; LCD
	;SBI PORTD, 6					; Pull-up Sensor de Efecto Hall
	SBI DDRD, 7						; PWM a base de transistor NPN
//Serial
	LDI R16, 0b10000110		; Asíncrono (6). Disable (5 4). 1 stop bit (3). 8 character size (2 1). No Polaridad (0)
	OUT UCSRC, R16			
	LDI R16, 0b10010000		; Habilita Interrupción cuando Buffer de Recepción lleno
	OUT UCSRB, R16
	LDI R16, 51
	OUT UBRRL, R16			; 9600 baud rate
//Timers
	//TIMER1
		LDI R16, 0b01100001
		OUT TCCR2, R16
	//TIMER2
		LDI R16, 0b01100001
		OUT TCCR2, R16
//Inicializar LCD
	RCALL init_LCD
	LDI XY, 0x08
	RCALL gotoXY_LCD
	RCALL cursorOff_LCD
//Inicializaciones
	LDI cont, 11			; Contador de tramas en comunicación Serial
	CLR contHall
	SEI
fin:
RJMP fin

RX:IN R16, SREG
PUSH R16

IN R16, UDR
	CPI cont, 11			; Esperamos a inicio de comunicación con byte = 'I'
	BREQ inicio
	CPI cont, 10			; Esperamos _0:00:00
	BREQ alm1
	CPI cont, 9				; Esperamos 0_:00:00
	BREQ alm2
	CPI cont, 8				; Esperamos 00_00:00
	BREQ alm3
	CPI cont, 7				; Esperamos 00:_0:00
	BREQ alm4
	CPI cont, 6				; Esperamos 00:0_:00
	BREQ alm5
	CPI cont, 5				; Esperamos 00:00_00
	BREQ alm6
	CPI cont, 4				; Esperamos 00:00:_0
	BREQ alm7
	CPI cont, 3				; Esperamos 00:00:0_
	BREQ alm8
	CPI cont, 2				; Esperamos 'B'/'R'
	BREQ alm9
	CPI cont, 1
	BREQ alm10				; Esperamos valor entre 0-255
	RJMP noASCII
;***VERIFICACIÓN DE INICIO***
	inicio:
	CPI R16, 'I'
	BRNE salirRX
	DEC cont
	RJMP salirRx
;***VERIFICACIÓN DE INICIO***
;***ALMACENAMIENTO DE HORA***
	alm1: STS 0x80, R16
	RJMP resta
	alm2: STS 0x81, R16
	RJMP resta
	alm3: STS 0x82, R16
	RJMP noASCII
	alm4: STS 0x83, R16
	RJMP resta
	alm5: STS 0x84, R16
	RJMP resta
	alm6: STS 0x85, R16
	RJMP noASCII
	alm7: STS 0x86, R16
	RJMP resta
	alm8: STS 0x87, R16
	RJMP resta
;***ALMACENAMIENTO DE HORA***
;**ALMACENAMIENTO DE COLOR***
	alm9: STS 0x88, R16
	RCALL colorSeleccionado
	RJMP noASCII
;**ALMACENAMIENTO DE COLOR***
;***ALMACENAMIENTO DE ADC****
	alm10: STS 0x89, R16
	RCALL brilloADC
	RJMP noASCII
;***ALMACENAMIENTO DE ADC****

	resta:
	SUBI R16, -0x30
	RJMP noASCII

	noASCII:
	MOV sendLCD_Reg, R16
	RCALL send4Bits_LCD
	DEC cont
	BRNE salirRX
	LDI cont, 11
	LDI XY, 0x0C
	RCALL gotoXY_LCD
	MOV sendLCD_Reg, contHall
	RCALL sendASCII_LCD
	LDI XY, 0x08
	RCALL gotoXY_LCD
	RJMP salirRX

salirRX:
POP R16
OUT SREG, R16
RETI

hallSensor:IN R16, SREG
PUSH R16
/*
	LDI XY, 0x0C
	RCALL gotoXY_LCD
	MOV sendLCD_Reg, contHall
	RCALL sendASCII_LCD
*/
	INC contHall
salirHall:
POP R16
OUT SREG, R16
RETI


colorSeleccionado:
	LDS R18, 0x88
	CPI R18, 'B'
	BRNE rojoSeleccionado
	azulSeleccionado:
	LDI R18, 0b00011111
	OUT PORTA, R18
	CLR R18
	OUT PORTB, R18
	RJMP salidaColor
	rojoSeleccionado:
	LDI R18, 0b00011111
	OUT PORTB, R18
	CLR R18
	OUT PORTA, R18
salidaColor:
RET

;******AJUSTE DE BRILLO*******
brilloADC:
	OUT OCR2, R16
RET
;******AJUSTE DE BRILLO*******

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
