	/*
		Puerto A: PA0 (ADC0)
		Puerto B: -
		Puerto C: PC0 a resistencia 330 que va a LED rojo. PC1 a resistencia 330 que va a LED azul
		Puerto D: PD2 a botón selector de color ROJO. PD3 a botón selector de color AZUL. PD7 (OC1) a base de Transistor NPN
		AVCC a VCC
		AREF a capacitor 100nF a GND. (puede ir solamente a GND)
		En este programa se leerá el voltaje de un potenciómetro a través del ADC0 y se variará el ciclo de trabajo en PB3.
		Se seleccionará a través de botones el LED que se desea encender.
	*/
	.INCLUDE "M16ADEF.INC"
	.ORG 0x00
	RJMP main
	.ORG 0x02
	RJMP selectorRojo
	.ORG 0x04
	RJMP selectorAzul
	.ORG 0x1C
	RJMP interrupcionADC
	main:
	//Pila
		LDI R16, HIGH(RAMEND)
		OUT SPH, R16
		LDI R16, LOW(RAMEND)
		OUT SPL, R16
	//Puertos					
		SER R16
		OUT DDRC, R16
		SBI PORTD, 2					;Pull-up
		SBI PORTD, 3					;Pull-up
		SBI DDRD, 7
	//TIMER2
		LDI R16, 0b01100001
		OUT TCCR2, R16
	//ADC
		LDI R16, 0b01000000				; AVCC Ref. ADC0+ 
		OUT ADMUX, R16
		LDI R16, 0b10001111				
		OUT ADCSRA, R16
	//Interrupción
		LDI R16, 0b11000000
		OUT GICR, R16					; Habilitar INT0 e INT1
		LDI R16, 0b00001111				; Activas en Flanco de Subida
		OUT MCUCR, R16
	//Inicializaciones
		CLR R16
		STS 0x100, R16
		STS 0x101, R16
		STS 0x102, R16
		SEI
		SBI ADSC, ADCSRA				;Iniciar conversión
		SBI PORTC, 0
	fin: RJMP fin

	interrupcionADC:
	IN R16, SREG
	PUSH R16
	IN R16, ADCL
	STS 0x100, R16
	IN R16, ADCH
	STS 0x101, R16			; 0x101:0x100
	CALL div4				; Se divide entre 4 el valor leído por ADC 
	LDS R16, 0x102			; 0x102 contiene número dividido
	OUT OCR2, R16
	SBI ADSC, ADCSRA		; Iniciar siguiente conversión
	POP R16
	OUT SREG, R16
	RETI

	selectorRojo:
	SBI PORTC, 1
	CBI PORTC, 0
	RETI
	selectorAzul:
	SBI PORTC, 0
	CBI PORTC, 1
	RETI

	div4:
		LDS R3, 0x101
		LDS R2, 0x100		; R3:R2
		//División
		LSR R3
		ROR R2				; /2
		LSR R3
		ROR R2				; /4. R2 contiene resultado
		STS 0x102, R2
	RET