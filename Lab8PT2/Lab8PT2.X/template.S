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
RxReady		EQU 0x70
RxByte		EQU 0x71
TxByte		EQU 0x72
TxPending	EQU 0x73
	
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
    BANKSEL PORTA
    CLRF PORTA
    CLRF PORTC
    
    BANKSEL TRISC
    BCF TRISC,6			;c output 
    BSF TRISC,7			;c input
    BCF TRISA,0
    
    BANKSEL ANSEL
    CLRF ANSEL
    BANKSEL ANSELH
    CLRF ANSELH
    BCF PORTB,0
    
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
    BSF RCSTA,4			;enable recieve
    
    BANKSEL TXSTA
    BSF TXSTA,5			;enable transmit 
    
    BANKSEL RxReady
    CLRF RxReady
    CLRF TxPending 
    
    BANKSEL INTCON
    CLRF INTCON
    
    goto Main
 
Main: 
   CALL ServiceRX
   CALL ProcessEcho
   CALL ServiceTX
   GOTO Main
    
ServiceRX:
    BANKSEL PORTA
    BSF PORTA,0	
    BCF PORTA,0			; momentary diag pulse 
    BANKSEL RxReady		    
    MOVF RxReady,W			
    BTFSS STATUS,2		; Is RxReady == 0?
RETURN				; No, return

    ; Clear Overrun Error if it happens
    BANKSEL RCSTA
    BTFSS RCSTA,1		; Check OERR
    GOTO ReadUART               ; No error, go read the byte
    BCF RCSTA,4			; Clear CREN to reset OERR
    BSF RCSTA,4			; Re-enable receiver

ReadUART:
    BANKSEL PIR1
    BTFSS PIR1,5                ; Check RCIF (1 = byte available)
RETURN				; No data yet, exit
    BANKSEL RCREG
    MOVF RCREG,W
    BANKSEL RxByte
    MOVWF RxByte		; Save data byte
    MOVLW 1
    MOVWF RxReady		; Set ready flag
RETURN
  
ProcessEcho:
    BANKSEL RxReady
    MOVF RxReady,F		;movingg recieved to w 
    BTFSC RxReady,2		;is it ready to recieve? 
RETURN				;
    MOVF TxPending,F		;
    BTFSS TxPending,2
RETURN
    MOVF RxByte,W
    MOVWF TxByte		;recieved moved to transmit
    
    CLRF RxReady		;clear recieve flag
    MOVLW 0x01
    MOVWF TxPending		;set tx flag
RETURN
  
ServiceTX:
    BANKSEL TxPending
    MOVF TxPending,W
    BTFSC STATUS,2		;is it waiting?
RETURN
    BANKSEL PIR1
    BTFSS PIR1,4		;txreg empty
RETURN
    BANKSEL TxByte  
    MOVF TxByte,W		;send the stored value
    BANKSEL TXREG
    MOVWF TXREG	    
    CLRF TxPending		;clear the pending flag
RETURN 
    
 End