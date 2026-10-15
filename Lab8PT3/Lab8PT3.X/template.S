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

#include <xc.inc>
    rx_byte	    EQU 0x70   
    rx_state	    EQU 0x71   
    rx_command	    EQU 0x72   
    reply_pending   EQU 0x73   
    adc_state	    EQU 0x74
    adc_high	    EQU 0x75
    adc_low	    EQU 0x76
    tx_data0	    EQU 0x77
    tx_data1	    EQU 0x78
    tx_data2	    EQU 0x79
    tx_data3	    EQU 0x7A
    tx_data4	    EQU 0x7B
    tx_data5	    EQU 0x7C
    tx_length	    EQU 0x7D
    tx_count	    EQU 0x7E
	    
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector: 
    GOTO Setup

; Interrupt Vector at 0004h. Execution starts here after an interrupt.
PSECT isrVect,class=CODE,delta=2
InterruptVector:
   
; Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2
 
Setup: 
    ;       Bank 3
    BANKSEL ANSEL     
    CLRF ANSEL         ;set all pins digital, RA0 needs this as an output
    BSF ANSEL,0
    CLRF ANSELH
    CLRF BAUDCTL       ;set the 8-bit baud rate generator
    ;       Bank 1
    BANKSEL TXSTA 
    MOVLW 0b00100100    ;transmitter on, asynchronous, high speed,
    MOVWF TXSTA         ;and 8 bit data
    MOVLW 25
    MOVWF SPBRG         ;9600 baud divisor, 9615 actual at 4 MHz
    BSF TRISC,6       ;bit set as the data sheet says for the TX pin
    BSF TRISC,7       ;bit set as the data sheet says for the RX pin
    BSF TRISA,0       ;RA0 is an output, the diagnostic pin
    BCF TRISA,1
    MOVLW 0b10000000
    MOVWF ADCON1
    ;       Bank 0
    BANKSEL RCSTA
    MOVLW 0b10010000    ;SPEN = 1 enables the serial port,
    MOVWF RCSTA         ;CREN = 1 turns on continuous receive
    MOVLW 0b01000001
    MOVWF ADCON0
    
    CLRF PORTA
    CLRF rx_state
    CLRF rx_command
    CLRF reply_pending
    CLRF adc_state
    CLRF adc_high
    CLRF adc_low
    CLRF tx_length
    CLRF tx_count
    
Main:
    BSF PORTA,1
    BCF PORTA,1
    CALL ServiceRx     ;check the receiver
    CALL Process   
    CALL ServiceTx     ;se 
    GOTO Main          ;repeat forever
 
ServiceRx:
    BANKSEL RCSTA
    BTFSC RCSTA,1
    GOTO RxRun
 
    BTFSS PIR1,5        ;RCIF = 1 means a byte has arrived
    RETURN                ;nothing arrived, nothing to do
    BTFSC RCSTA,2
    GOTO RxOut
    MOVF RCREG,W       ;read the byte, this also clears RCIF
    MOVWF rx_byte
    MOVF reply_pending,F
    BTFSS STATUS,2
    RETURN
    CALL ParseRx
    RETURN
    
RxRun:
    BCF RCSTA,4
    BSF RCSTA,4
    MOVLW 0x04
    GOTO RxError
    
RxOut:
    MOVF RCREG,W
    MOVLW 0x03
    
RxError:
    MOVWF reply_pending
    CLRF rx_state
    CLRF adc_state
    RETURN
 
ParseRx:
    MOVF rx_state,F
    BTFSC STATUS,2
    GOTO Wait
    MOVF rx_stateW
    XORLW 0x01
    BTFSC Status,2
    GOTO Command
    MOVF rx_state,W
    XORLW 0x02
    BTFSC STATUS,2
    GOTO Length
    MOVF rx_state,W
    XORLW 0x03
    BTFSC STATUS,2
    GOTO Channel
    GOTO ResetParse
    
Wait:
    
Command:
    
Length:
    
Channel:
    
ResetParse:
    
    
Process:
    BTFSS rx_ready,0    ;is there a received byte?
    RETURN                ;no
    BTFSC tx_pending,0  ;is the last echo still waiting to go out?
    RETURN                ;yes, wait for it
    MOVF rx_byte,W
    MOVWF tx_byte       ;copy the byte, unchanged
    BCF rx_ready,0    ;received byte is handled
    BSF tx_pending,0  ;and now it waits to be sent
    RETURN
; ServiceTx: if a byte is waiting and TXREG is empty, send it.
ServiceTx:
    BTFSS tx_pending,0  ;is anything waiting to be sent?
    RETURN                ;if no then return
    BTFSS PIR1,4        ;TXIF = 1 means TXREG is empty
    RETURN                ;transmitter busy, try again next pass
    MOVF tx_byte,W
    MOVWF TXREG         ;writing here starts the transmission
    BCF tx_pending,0  ;it is on its way
    RETURN
    End
    