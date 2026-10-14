//Cambria Morgan
//RCET3373
//First Program
//git
//-Wl,-presetVect=0000h,-pisrVect=0004h,-pcode=0008h

    
; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
COMStatus	EQU 0x70
BitToSend	EQU 0x71
 ;Reset Vector at 0000h. Execution starts here after reset 
PSECT resetVect,class=CODE,delta=2
ResetVector:
    NOP
    NOP
    goto Setup
    
;Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2 //after PSECT everything is grouped until the next PSECT

Setup:
    ; add device setup here 
    BANKSEL TRISC
    BSF TRISC,6			;c output 
    
    BANKSEL TXSTA
    CLRF TXSTA
    BCF TXSTA,4			;set EUSART in async mode 
    BSF TXSTA,2			;set high speed baud rate
    BCF TXSTA,6			;enable transmit        
    
    BANKSEL BAUDCTL
    CLRF BAUDCTL
    BCF BAUDCTL,3		;set baud rate at 8 bit
       
    BANKSEL SPBRG 
    CLRF SPBRG
    MOVLW 25
    MOVWF SPBRG			;select 9600 baud rate 
    
    BANKSEL RCSTA
    CLRF RCSTA
    BSF RCSTA,7			;enable serial port pins 
  
    BANKSEL TXSTA
    BSF TXSTA,5		;enable transmit 
    
    goto Main
 
 
 
Main: 
 BANKSEL PIR1
 BTFSC PIR1,4			;is transmit reg empty?
 GOTO MakeItRain
 GOTO Main
 
MakeItRain:
    BANKSEL TXREG
    MOVLW 0x24
    MOVWF TXREG
    GOTO Main
  
 End