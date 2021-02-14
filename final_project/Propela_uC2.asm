/*
DISPOSITIVO: ATmega16A 40-pin-PDIP
PUERTOS:
	Puerto A: PA0 - PA4 a resistencia -330- LEDs Azules (000x xxxx) que van a Colector de Transistor tipo NPN
	Puerto B: PA0 - PA4 a resistencia -330- LEDs Rojos  (000x xxxx) que van a Colector de Transistor tipo NPN
	Puerto C: PC0 - PC1 a resistencia -330- LEDs Verdes (0000 00xx) que van a Colecor de Transistor tipo NPN.
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
.DEF ancho = R24
.DEF cont = R23
.DEF contLetra = R22
.DEF timeH = R19
.DEF timeL = R18
.DEF registroDespliegue = R17
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
	LDI R16, 0b00000011
	OUT DDRC, R16					; LEDs Verdes
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
		LDI R16, 0b00000000
		OUT TCCR1A, R16
		LDI R16, 0b00000101
		OUT TCCR1B, R16
	//TIMER2
		LDI R16, 0b01100001
		OUT TCCR2, R16
//Interrupcion Timer
	LDI R16, 0b00100000
	OUT TIMSK, R16
//Inicializaciones
	LDI cont, 11			; Contador de tramas en comunicación Serial
	SBI PORTC, 0
	SBI PORTC, 1
	LDI R16, 255
	OUT OCR2, R16
	RCALL cleanCounter
	SEI
.EQU degreesClock = 260
.EQU degrees90 = 170
.EQU degreesStart = 30
loop:
IN timeH, TCNT1H
IN timeL, TCNT1L

LDI R26, HIGH(degreesStart)
LDI R25, LOW(degreesStart)
CLR contLetra							; contLetra se utilizará para contar cuál secuencia hacer 
RCALL comparacion

LDI R26, HIGH(degreesStart+30)
LDI R25, LOW(degreesStart+30)
LDI contLetra, 1
RCALL comparacion

LDI R26, HIGH(degreesStart+60)
LDI R25, LOW(degreesStart+60)
LDI contLetra, 2
RCALL comparacion

LDI R26, HIGH(degreesStart+90)
LDI R25, LOW(degreesStart+90)
LDI contLetra, 3
RCALL comparacion

LDI R26, HIGH(degreesStart+120)
LDI R25, LOW(degreesStart+120)
LDI contLetra, 4
RCALL comparacion

LDI R26, HIGH(degreesClock)
LDI R25, LOW(degreesClock)
LDI contLetra, 5
RCALL comparacion

LDI R26, HIGH(degreesClock+30)
LDI R25, LOW(degreesClock+30)
LDI contLetra, 6
RCALL comparacion

LDI R26, HIGH(degreesClock+60)
LDI R25, LOW(degreesClock+60)
LDI contLetra, 7
RCALL comparacion


LDI R26, HIGH(degreesClock+90)
LDI R25, LOW(degreesClock+90)
LDI contLetra, 8
RCALL comparacion

LDI R26, HIGH(degreesClock+120)
LDI R25, LOW(degreesClock+120)
LDI contLetra, 9
RCALL comparacion

LDI R26, HIGH(degreesClock+150)
LDI R25, LOW(degreesClock+150)
LDI contLetra, 10
RCALL comparacion

LDI R26, HIGH(degreesClock+180)
LDI R25, LOW(degreesClock+180)
LDI contLetra, 11
RCALL comparacion

LDI R26, HIGH(degreesClock+210)
LDI R25, LOW(degreesClock+210)
LDI contLetra, 12
RCALL comparacion



RJMP loop

comparacion:
CP timeH, R26
BRNE salirComparacion
CP timeL, R25
BRNE salirComparacion
CPI contLetra, 0
BREQ escribirCora
CPI contLetra, 1
BREQ escribirE
CPI contLetra, 2
BREQ escribirS
CPI contLetra, 3
BREQ escribirT
CPI contLetra, 4
BREQ escribirI
CPI contLetra, 5
BREQ escribirnum1
CPI contLetra, 6
BREQ escribirnum2
CPI contLetra, 7
BREQ escribirnum3
CPI contLetra, 8
BREQ escribirnum4
CPI contLetra, 9
BREQ escribirnum5
CPI contLetra, 10
BREQ escribirnum6
CPI contLetra, 11
BREQ escribirnum7
CPI contLetra, 12
BREQ escribirnum8
salirComparacion:
RET

escribirCora:
LDI ZH, HIGH(cora<<1)
LDI ZL, LOW(cora<<1)
LDI ancho, 5
RJMP start
escribirE:
LDI ZH, HIGH(E<<1)
LDI ZL, LOW(E<<1)
LDI ancho, 5
RJMP start
escribirS:
LDI ZH, HIGH(S<<1)
LDI ZL, LOW(S<<1)
LDI ancho, 5
RJMP start
escribirT:
LDI ZH, HIGH(T<<1)
LDI ZL, LOW(T<<1)
LDI ancho, 5
RJMP start
escribirI:
LDI ZH, HIGH(I<<1)
LDI ZL, LOW(I<<1)
LDI ancho, 5
RJMP start

escribirnum1:
LDS R27, 0x87							; 00:00:0_
RJMP descifrar
escribirnum2:
LDS R27, 0x86							; 00:00:_0
RJMP descifrar
escribirnum3:
LDS R27, 0x85							; 00:00_00
RJMP descifrar
escribirnum4:
LDS R27, 0x84							; 00:0_:00
RJMP descifrar
escribirnum5:
LDS R27, 0x83							; 00:0_:00
RJMP descifrar
escribirnum6:
LDS R27, 0x82							; 00:_0:00
RJMP descifrar
escribirnum7:
LDS R27, 0x81							; 00_00:00
RJMP descifrar
escribirnum8:
LDS R27, 0x80							; 0_:00:00

RJMP descifrar
descifrar:
RCALL descifrarCar
RJMP start


start:
escribir: LPM registroDespliegue, Z+
RCALL logica
RCALL delay300us
DEC ancho
BRNE escribir
RJMP salirComparacion

logica:
RCALL encenderSeleccionado
RET

encenderSeleccionado:
	CLR R0									; Se usará para apagar LEDs
	CPI R20, 1
	BREQ rojoON
	azulON:									; Estamos si R20 = 0 (Blue)
	OUT PORTB, R0
	OUT PORTA, registroDespliegue
	RJMP seguirEncender
	rojoON:									; Estamos si R20 = 1 (Red)
	OUT PORTA, R0
	OUT PORTB, registroDespliegue
	seguirEncender:
	RCALL delay400us
	OUT PORTA, R0
	OUT PORTB, R0
RET

escribir0a:
JMP escribir0
escribir1a:
JMP escribir1
escribir2a:
JMP escribir2
escribir3a:
JMP escribir3
escribir4a:
JMP escribir4
escribir5a:
JMP escribir5
escribir6a:
JMP escribir6
escribir7a:
JMP escribir7
escribir8a:
JMP escribir8
escribir9a:
JMP escribir9

descifrarCar:				; Revisar número que hay en R27
CPI R27, 0
BREQ escribir0a
CPI R27, 1
BREQ escribir1a
CPI R27, 2
BREQ escribir2a
CPI R27, 3
BREQ escribir3a
CPI R27, 4
BREQ escribir4a
CPI R27, 5
BREQ escribir5a
CPI R27, 6
BREQ escribir6a
CPI R27, 7
BREQ escribir7a
CPI R27, 8
BREQ escribir8a
CPI R27, 9
BREQ escribir9a
CPI R27, ':'
BREQ escribirPuntosa
CPI R27, ')'
BREQ escribirPuntosa
CPI R27, 'A'
BREQ escribirAa
CPI R27, 'B'
BREQ escribirBa
CPI R27, 'C'
BREQ escribirCa
CPI R27, 'D'
BREQ escribirDa
CPI R27, 'E'
BREQ escribirE2a
CPI R27, 'F'
BREQ escribirFa
CPI R27, 'G'
BREQ escribirGa
CPI R27, 'H'
BREQ escribirHa
CPI R27, 'I'
BREQ escribirI2a
CPI R27, 'J'
BREQ escribirJa
CPI R27, 'K'
BREQ escribirKa
CPI R27, 'L'
BREQ escribirLa
CPI R27, 'M'
BREQ escribirMa
CPI R27, 'N'
BREQ escribirNa
CPI R27, 'O'
BREQ escribirOa
CPI R27, 'P'
BREQ escribirPa
CPI R27, 'Q'
BREQ escribirQa
CPI R27, 'R'
BREQ escribirRa
CPI R27, 'S'
BREQ escribirS2a
CPI R27, 'T'
BREQ escribirT2a
CPI R27, 'U'
BREQ escribirUa
CPI R27, 'V'
BREQ escribirVa
CPI R27, 'W'
BREQ escribirWa
CPI R27, 'X'
BREQ escribirXa
CPI R27, 'Y'
BREQ escribirYa
CPI R27, 'Z'
BREQ escribirZa
CPI R27, ' '
BREQ escribirSpacea
CPI R27, '.'
BREQ escribirPuntoa
retornarNum:
RET
escribirPuntoa:
JMP escribirPunto
escribirSpacea:
JMP escribirSpace
escribirPuntosa:
JMP escribirPuntos
escribirAa:
JMP escribirA
escribirBa:
JMP escribirB
escribirCa:
JMP escribirC
escribirDa:
JMP escribirD
escribirE2a:
JMP escribirE2
escribirFa:
JMP escribirF
escribirGa:
JMP escribirG
escribirHa:
JMP escribirH
escribirI2a:
JMP escribirI2
escribirJa:
JMP escribirJ
escribirKa:
JMP escribirK
escribirLa:
JMP escribirL
escribirMa:
JMP escribirM
escribirNa:
JMP escribirN
escribirOa:
JMP escribirO
escribirPa:
JMP escribirP
escribirQa:
JMP escribirQ
escribirRa:
JMP escribirR
escribirS2a:
JMP escribirS2
escribirT2a:
JMP escribirT2
escribirUa:
JMP escribirU
escribirVa:
JMP escribirV
escribirWa:
JMP escribirW
escribirXa:
JMP escribirX
escribirYa:
JMP escribirY
escribirZa:
JMP escribirZ

escribir0:
LDI ZH, HIGH(zero<<1)
LDI ZL, LOW(zero<<1)
LDI ancho, 5
RJMP retornarNum
escribir1:
LDI ZH, HIGH(one<<1)
LDI ZL, LOW(one<<1)
LDI ancho, 5
RJMP retornarNum
escribir2:
LDI ZH, HIGH(two<<1)
LDI ZL, LOW(two<<1)
LDI ancho, 5
RJMP retornarNum
escribir3:
LDI ZH, HIGH(three<<1)
LDI ZL, LOW(three<<1)
LDI ancho, 5
RJMP retornarNum
escribir4:
LDI ZH, HIGH(four<<1)
LDI ZL, LOW(four<<1)
LDI ancho, 5
RJMP retornarNum
escribir5:
LDI ZH, HIGH(five<<1)
LDI ZL, LOW(five<<1)
LDI ancho, 5
RJMP retornarNum
escribir6:
LDI ZH, HIGH(six<<1)
LDI ZL, LOW(six<<1)
LDI ancho, 5
RJMP retornarNum
escribir7:
LDI ZH, HIGH(seven<<1)
LDI ZL, LOW(seven<<1)
LDI ancho, 4
RJMP retornarNum
escribir8:
LDI ZH, HIGH(eight<<1)
LDI ZL, LOW(eight<<1)
LDI ancho, 4
RJMP retornarNum
escribir9:
LDI ZH, HIGH(nine<<1)
LDI ZL, LOW(nine<<1)
LDI ancho, 4
RJMP retornarNum

escribirpuntos:
LDI ZH, HIGH(dots<<1)
LDI ZL, LOW(dots<<1)
LDI ancho, 1
RJMP retornarNum
escribirSpace:
LDI ZH, HIGH(space<<1)
LDI ZL, LOW(space<<1)
LDI ancho, 5
RJMP retornarNum
escribirPunto:
LDI ZH, HIGH(punto<<1)
LDI ZL, LOW(punto<<1)
LDI ancho, 5
RJMP retornarNum

escribirA:
LDI ZH, HIGH(A<<1)
LDI ZL, LOW(A<<1)
LDI ancho, 5
RJMP retornarNum
escribirB:
LDI ZH, HIGH(B<<1)
LDI ZL, LOW(B<<1)
LDI ancho, 5
RJMP retornarNum
escribirC:
LDI ZH, HIGH(C<<1)
LDI ZL, LOW(C<<1)
LDI ancho, 5
RJMP retornarNum
escribirD:
LDI ZH, HIGH(D<<1)
LDI ZL, LOW(D<<1)
LDI ancho, 5
RJMP retornarNum
escribirE2:
LDI ZH, HIGH(E<<1)
LDI ZL, LOW(E<<1)
LDI ancho, 5
RJMP retornarNum
escribirF:
LDI ZH, HIGH(F<<1)
LDI ZL, LOW(F<<1)
LDI ancho, 5
RJMP retornarNum
escribirG:
LDI ZH, HIGH(G<<1)
LDI ZL, LOW(G<<1)
LDI ancho, 5
RJMP retornarNum
escribirH:
LDI ZH, HIGH(H<<1)
LDI ZL, LOW(H<<1)
LDI ancho, 5
RJMP retornarNum
escribirI2:
LDI ZH, HIGH(I<<1)
LDI ZL, LOW(I<<1)
LDI ancho, 5
RJMP retornarNum
escribirJ:
LDI ZH, HIGH(J<<1)
LDI ZL, LOW(J<<1)
LDI ancho, 5
RJMP retornarNum
escribirK:
LDI ZH, HIGH(K<<1)
LDI ZL, LOW(K<<1)
LDI ancho, 5
RJMP retornarNum
escribirL:
LDI ZH, HIGH(L<<1)
LDI ZL, LOW(L<<1)
LDI ancho, 5
RJMP retornarNum
escribirM:
LDI ZH, HIGH(M<<1)
LDI ZL, LOW(M<<1)
LDI ancho, 5
RJMP retornarNum
escribirN:
LDI ZH, HIGH(N<<1)
LDI ZL, LOW(N<<1)
LDI ancho, 5
RJMP retornarNum
escribirO:
LDI ZH, HIGH(O<<1)
LDI ZL, LOW(O<<1)
LDI ancho, 5
RJMP retornarNum
escribirP:
LDI ZH, HIGH(P<<1)
LDI ZL, LOW(P<<1)
LDI ancho, 5
RJMP retornarNum
escribirQ:
LDI ZH, HIGH(Q<<1)
LDI ZL, LOW(Q<<1)
LDI ancho, 5
RJMP retornarNum
escribirR:
LDI ZH, HIGH(R<<1)
LDI ZL, LOW(R<<1)
LDI ancho, 5
RJMP retornarNum
escribirS2:
LDI ZH, HIGH(S<<1)
LDI ZL, LOW(S<<1)
LDI ancho, 5
RJMP retornarNum
escribirT2:
LDI ZH, HIGH(T<<1)
LDI ZL, LOW(T<<1)
LDI ancho, 5
RJMP retornarNum
escribirU:
LDI ZH, HIGH(U<<1)
LDI ZL, LOW(U<<1)
LDI ancho, 5
RJMP retornarNum
escribirV:
LDI ZH, HIGH(V<<1)
LDI ZL, LOW(V<<1)
LDI ancho, 5
RJMP retornarNum
escribirW:
LDI ZH, HIGH(W<<1)
LDI ZL, LOW(W<<1)
LDI ancho, 5
RJMP retornarNum
escribirX:
LDI ZH, HIGH(equis<<1)
LDI ZL, LOW(equis<<1)
LDI ancho, 5
RJMP retornarNum
escribirY:
LDI ZH, HIGH(ye<<1)
LDI ZL, LOW(ye<<1)
LDI ancho, 5
RJMP retornarNum
escribirZ:
LDI ZH, HIGH(zeta<<1)
LDI ZL, LOW(zeta<<1)
LDI ancho, 5
RJMP retornarNum

RX:IN R16, SREG
PUSH R16

IN R16, UDR
	CPI R16, '?'
	BRNE normal
	LDI cont, 11
	RJMP salirRx
	normal:
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
	RJMP seguirRX
;***VERIFICACIÓN DE INICIO***
	inicio:
	CPI R16, 'I'
	BRNE salirRX
	DEC cont
	RJMP salirRx
;***VERIFICACIÓN DE INICIO***
;***ALMACENAMIENTO DE HORA***
	alm1: STS 0x80, R16
	RJMP seguirRX
	alm2: STS 0x81, R16
	RJMP seguirRX
	alm3: STS 0x82, R16
	RJMP seguirRX
	alm4: STS 0x83, R16
	RJMP seguirRX
	alm5: STS 0x84, R16
	RJMP seguirRX
	alm6: STS 0x85, R16
	RJMP seguirRX
	alm7: STS 0x86, R16
	RJMP seguirRX
	alm8: STS 0x87, R16
	RJMP seguirRX
;***ALMACENAMIENTO DE HORA***
;**ALMACENAMIENTO DE COLOR***
	alm9: STS 0x88, R16
	RCALL colorSeleccionado
	RJMP seguirRX
;**ALMACENAMIENTO DE COLOR***
;***ALMACENAMIENTO DE ADC****
	alm10:	CPI R16, '#'
	BREQ clearADC
	CPI R16, '.'
	BREQ setADC
	RJMP seguirADC
	clearADC: LDI R16, 0			; Con CLR no funcionó
	RJMP seguirADC
	setADC: SER R16
	seguirADC: RCALL brilloADC
	STS 0x89, R16
	RJMP seguirRX
;***ALMACENAMIENTO DE ADC****
	seguirRX:
	DEC cont
	BRNE salirRX
	LDI cont, 11
salirRX:
POP R16
OUT SREG, R16
RETI



colorSeleccionado:
	LDS R16, 0x88
	CPI R16, 'B'
	BRNE rojoSeleccionado
	azulSeleccionado:
	CLR R20
	CLT								; Bandera T = 0. Se seleccionó Azul
	RJMP salidaColor
	rojoSeleccionado:
	LDI R20, 1
	SET								; Bandera T = 1. Se seleccionó Rojo
salidaColor:
RET


hallSensor:IN R16, SREG
PUSH R16
									; Reiniciamos cuenta
	RCALL cleanCounter
salirHall:
POP R16
OUT SREG, R16
RETI

cleanCounter:
	CLR R0
	OUT TCNT1H, R0
	OUT TCNT1L, R0
RET
;******AJUSTE DE BRILLO*******
brilloADC:
	OUT OCR2, R16
RET
;******AJUSTE DE BRILLO*******
delay400us:	
PUSH R20	
PUSH R21				
	LDI R20, 4	
	cicloa:	
		LDI R21 ,255 
		ciclob:DEC R21 
		BRNE ciclob
		DEC R20
	BRNE cicloa
POP R21
POP R20
RET
delay300us:	
PUSH R20	
PUSH R21				
	LDI R20, 3
	cicloa2:	
		LDI R21 ,255 
		ciclob2:DEC R21 
		BRNE ciclob2
		DEC R20
	BRNE cicloa2
POP R21
POP R20
RET
;***************FLASH**********************
.ORG 0x300
zero: .DB 0b00011111, 0b00010001, 0b00010001, 0b00010001, 0b00011111	; 0 - 5
one: .DB 0b00000000, 0b00000000, 0b00011111, 0b00000000, 0b00000000		; 1 - 5
two: .DB 0b00011101, 0b00010101, 0b00010101, 0b00010101, 0b00010111		; 2 - 5
three: .DB 0b00011111, 0b00010101, 0b00010101, 0b00010101, 0b00010101	; 3 - 5
four: .DB 0b00011111, 0b00000100, 0b00000100, 0b00000100, 0b00011100	; 4 - 5
five: .DB 0b00010111, 0b00010101, 0b00010101, 0b00010101, 0b00011101	; 5 - 5
six: .DB 0b00010111, 0b00010101, 0b00010101, 0b00010101, 0b00011111		; 6 - 5
seven: .DB 0b00011111, 0b00010100, 0b00010100, 0b00010000				; 7 - 4
eight: .DB 0b00011011, 0b00010101, 0b00010101, 0b00011011				; 8 - 4
nine: .DB 0b00011111, 0b00010100, 0b00010100, 0b000111000				; 9 - 4

dots: .DB 0b00001010													; : - 1
punto: .DB 0b00000000, 0b00000011, 0b00000011, 0b00000000, 0b00000000	; . - 5
cora: .DB 0b00001010, 0b00010101, 0b00010001, 0b00001010, 0b00000100	; <3 - 5
parentesis: .DB 0b00001110, 0b00010001, 0b00000000, 0b00000000, 0b00000000	; ) - 5

	
A: .DB 0b00001111, 0b00010100, 0b00010100, 0b00010100, 0b00001111		; Todas las letras - 5
B: .DB 0b00000111, 0b00000101, 0b00000101, 0b00000101, 0b00011111
C: .DB 0b00010001, 0b00010001, 0b00010001, 0b00010001, 0b00011111
D: .DB 0b00011111, 0b00000101, 0b00000101, 0b00000101, 0b00000111
E: .DB 0b00010101, 0b00010101, 0b00010101, 0b00010101, 0b00011111
F: .DB 0b00010100, 0b00010100, 0b00010100, 0b00010100, 0b00011111
G: .DB 0b00010111, 0b00010101, 0b00010101, 0b00010101, 0b00011111
H: .DB 0b00011111, 0b00000100, 0b00000100, 0b00000100, 0b00011111
I: .DB 0b00010001, 0b00010001, 0b00011111, 0b00010001, 0b00010001
J: .DB 0b00011111, 0b00000001, 0b00000001, 0b00000001, 0b00000001
K: .DB 0b00000000, 0b00010001, 0b00001010, 0b00000100, 0b00011111
L: .DB 0b00000001, 0b00000001, 0b00000001, 0b00000001, 0b00011111
M: .DB 0b00011111, 0b00001000, 0b00000100, 0b00001000, 0b00011111
N: .DB 0b00011111, 0b00000010, 0b00000100, 0b00001000, 0b00011111
O: .DB 0b00011111, 0b00010001, 0b00010001, 0b00010001, 0b00011111
P: .DB 0b00011100, 0b00010100, 0b00010100, 0b00010100, 0b00011111
Q: .DB 0b00000001, 0b00011111, 0b00010010, 0b00010010, 0b00011110
R: .DB 0b00000000, 0b00011100, 0b00010101, 0b00010110, 0b00011111
S: .DB 0b00010111, 0b00010101, 0b00010101, 0b00010101, 0b00011101
T: .DB 0b00010000, 0b00010000, 0b00011111, 0b00010000, 0b00010000
U: .DB 0b00011111, 0b00000001, 0b00000001, 0b00000001, 0b00011111
V: .DB 0b00011100, 0b00000010, 0b00000001, 0b00000010, 0b00011100
W: .DB 0b00011110, 0b00000001, 0b00000010, 0b00000001, 0b00011110
equis: .DB 0b00010001, 0b00001010, 0b00000100, 0b00001010, 0b00010001
ye: .DB 0b00011100, 0b00000100, 0b00000111, 0b00000100, 0b00011100
zeta: .DB 0b00010001, 0b00011001, 0b00010101, 0b00010011, 0b00010001
space: .DB 0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000

