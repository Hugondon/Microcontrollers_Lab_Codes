;
; ExamenFinalTemplate.asm
.INCLUDE "M16ADEF.INC"
.DEF cont = R17
.DEF lamps = R24
.DEF barrido = R25
.ORG 0x00
JMP estaVaPorMike
/*
.ORG 0x02				
JMP nombreInterrupcion0		;INT0 (PD2)
.ORG 0x04				
JMP nombreInterrupcion1		;INT1 (PD3)
.ORG 0x06
JMP timer2Compare			;Interrupción cuando TCNT2 llega a OCR2. Se activa OCF2
.ORG 0x0A
JMP timer1Capture			;Interrupción cuando se detecta flanco deseado (PD6)
.ORG 0x0C
JMP timer1CompareA			;Interrupción cuando TCNT1H:TCNT1L llega a OCR1AH:OCR1AL. Se activa OCF1A
.ORG 0x0E
JMP timer1CompareB			;Interrupción cuando TCNT1H:TCNT1L llega a OCR1BH:OCR1BL. Se activa OCF1B
.ORG 0x16
JMP Rx						;Interrupción cuando Buffer de Datos está vacío	(PD0)
.ORG 0x1A
JMP Tx						;Interrupción cuando Buffer de Datos está lleno (PD1)
.ORG 0x1C
JMP ADC						;Interrupcion cuando conversión ADC termina
.ORG 0x24
JMP nombreInterrupcion2		;INT2 (PB2)
.ORG 0x26
JMP timer0Compare			;Interrupción cuando TCNT0 llega a OCR0. Se activa OCF0
*/
estaVaPorMike:
//Pila
LDI R16, HIGH(RAMEND)
OUT SPH, R16
LDI R16, LOW(RAMEND)
OUT SPL, R16

LDI R16, 1
STS 0x80, R16
LDI R16, 1
STS 0x81, R16
	CALL BCD3BIN8
	LDS R16, 0x100
	SUBI R16, -12
	STS 0x100, R16

LDI R16, 234
STS 0x100, R16
CALL BIN8BCD3
NOP


FIN: RJMP FIN
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
