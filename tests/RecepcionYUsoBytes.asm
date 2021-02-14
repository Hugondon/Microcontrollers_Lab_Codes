/*
DISPOSITIVO: ATmega16A 40-pin-PDIP
PUERTOS:
	Puerto B: PB0. LED rojo
	Puerto C:
		PC7 PC6 PC5 PC4 PC3 PC2 PC1 PC0
		DB7 DB6 DB5 DB4  -  E	RW	RS
	Puerto D: PD0 (Rx). PD7 (OC2) a resistencia de 100 a Base de Transistor NPN
		AVCC a VCC
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
.ORG 0x16
RJMP RX
main:
//Pila
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
//Puertos
	SER R16
	OUT LCD_DDRx, R16
	LDI R16, 0b00011111
	OUT DDRA, R16					; LEDs Azules
	OUT DDRB, R16					; LEDs Rojos
	SBI DDRD, 7
//Serial
	LDI R16, 0b10000110		; As�ncrono (6). Disable (5 4). 1 stop bit (3). 8 character size (2 1). No Polaridad (0)
	OUT UCSRC, R16			
	LDI R16, 0b10010000		; Habilita Interrupci�n cuando Buffer de Recepci�n lleno
	OUT UCSRB, R16
	LDI R16, 51
	OUT UBRRL, R16			; 9600 baud rate
//TIMER2
	LDI R16, 0b01100001
	OUT TCCR2, R16
//Inicializar LCD
	RCALL init_LCD
	LDI XY, 0x08
	RCALL gotoXY_LCD
	RCALL cursorOff_LCD
//Inicializaciones
	LDI cont, 11			; Contador de tramas en comunicaci�n Serial
	SEI
fin:
RJMP fin

RX:IN R16, SREG
PUSH R16

IN R16, UDR

	CPI cont, 11			; Esperamos a inicio de comunicaci�n con byte = 'I'
	BREQ inicio
	CPI cont, 10			; Esperamos _0:00:00
	BREQ resta
	CPI cont, 9				; Esperamos 0_:00:00
	BREQ resta
	CPI cont, 8				; Esperamos 00_00:00
	BREQ noASCII
	CPI cont, 7				; Esperamos 00:_0:00
	BREQ resta
	CPI cont, 6				; Esperamos 00:0_:00
	BREQ resta
	CPI cont, 5				; Esperamos 00:00_00
	BREQ noASCII
	CPI cont, 4				; Esperamos 00:00:_0
	BREQ resta
	CPI cont, 3				; Esperamos 00:00:0_
	BREQ resta
	CPI cont, 2				; Esperamos 'B' o 'R'
	BREQ colorSeleccionado
	CPI cont, 1
	BREQ brilloADC			; Esperamos valor entre 0-255 (obtenido de ADC)
	RJMP noASCII
;***VERIFICACI�N DE INICIO***
	inicio:
	CPI R16, 'I'
	BRNE salirRX
	DEC cont
	RJMP salirRx
;***VERIFICACI�N DE INICIO***

	resta:
	SUBI R16, -0x30
	RJMP noASCII

;*****SELECCI�N DE COLOR******
	colorSeleccionado:
	CPI R16, 'B'
	BRNE rojoSeleccionado
	azulSeleccionado:
	LDI R17, 0b00011111
	OUT PORTA, R17
	CLR R17
	OUT PORTB, R17
	RJMP noASCII
	rojoSeleccionado:
	LDI R17, 0b00011111
	OUT PORTB, R17
	CLR R17
	OUT PORTA, R17
	RJMP noASCII
;*****SELECCI�N DE COLOR******
;******AJUSTE DE BRILLO*******
	brilloADC:
	OUT OCR2, R16
	RJMP noASCII
;******AJUSTE DE BRILLO*******
	noASCII:
	MOV sendLCD_Reg, R16
	RCALL send4Bits_LCD
	DEC cont
	BRNE salirRX
	LDI cont, 11
	LDI XY, 0x08
	RCALL gotoXY_LCD
	RJMP salirRX
salirRX:
POP R16
OUT SREG, R16
RETI
;***************FUNCIONES LCD**************
	;init_LCD: inicializa LCD
	;send4bits_LCD: env�a datos contenidos en R25
	;busy_LCD: espera a que LCD est� lista para otra instrucci�n/dato
	;gotoXY_LCD: env�a cursor a direcci�n en registro XY
	;sendData_LCD: env�a el n�mero de caracteres a partir de la direcci�n del apuntador Z
	;sendASCII_LCD: env�a el caracter ASCII correspondiente a un n�mero
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
	seguirNoInt: LDI R16,2				; Dos nibbles en un byte. Primero se env�a nibble superior y luego nibble inferior
	MOV R24,sendLCD_Reg	
envioNibbles:
	ANDI R24,0xF0						; Nibble superior �nicamente
	BRTS dato							; Si es un dato, deber� enviarse como dato
instruccion:							; En caso contrario, es instrucci�n
	SUBI R24,-4							; Activar enable  E-RW-RS (100)
	OUT LCD_PORT,R24					; Datos salen por Puerto C
	NOP
	NOP
	NOP									; 3 ciclos de m�quina
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
