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
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3 pin is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit
  CONFIG  CPD = OFF             ; Data Code Protection bit
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits
  CONFIG  IESO = OFF            ; Internal External Switchover mode is disabled
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor is disabled
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset set to 4.0V
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits

#include <xc.inc>

    rx_byte         EQU 0x70
    rx_state        EQU 0x71
    rx_command      EQU 0x72
    reply_pending   EQU 0x73
    adc_state       EQU 0x74
    adc_high        EQU 0x75
    adc_low         EQU 0x76
    tx_data0        EQU 0x77
    tx_data1        EQU 0x78
    tx_data2        EQU 0x79
    tx_data3        EQU 0x7A
    tx_data4        EQU 0x7B
    tx_data5        EQU 0x7C
    tx_length       EQU 0x7D
    tx_count        EQU 0x7E
	
    Count50us	    EQU 0x20
    Count5ms	    EQU 0x21

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
    BANKSEL ANSEL
    CLRF ANSEL
    BSF ANSEL,0
    CLRF ANSELH
    CLRF BAUDCTL

    BANKSEL TXSTA
    MOVLW 0b00100100
    MOVWF TXSTA
    MOVLW 25
    MOVWF SPBRG
    BSF TRISC,6
    BSF TRISC,7
    BSF TRISA,0
    BCF TRISA,1
    MOVLW 0b10000000
    MOVWF ADCON1

    BANKSEL RCSTA
    MOVLW 0b10010000
    MOVWF RCSTA
    MOVLW 0b01000001
    MOVWF ADCON0

    CLRF PORTA
    CLRF rx_byte
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
    CALL ServiceRx
    CALL Process
    CALL ServiceTx
    CALL Delay5ms
    GOTO Main

ServiceRx:
    BANKSEL RCSTA
    BTFSC RCSTA,1 ;overrun error? 
    GOTO RxRun

    BTFSS PIR1,5 ;new byte revieced?
    RETURN
    BTFSC RCSTA,2 ;frame error on new byte?
    GOTO RxOut

    MOVF RCREG,W
    MOVWF rx_byte ;read byte 
    MOVF reply_pending,F 
    BTFSS STATUS,2 ;irnore new recieved unless ready 
    RETURN
    CALL ParseRx
    RETURN

RxRun:
    BCF RCSTA,4
    BSF RCSTA,4 ;reset/clear the reciever 
    MOVLW 0x04 ;four means error 
    GOTO RxError

RxOut:
    MOVF RCREG,W ;discard bad byte
    ;three is a framing error 
    MOVLW 0x03

RxError:
    MOVWF reply_pending ;save error to address later 
    CLRF rx_state ;reset 
    CLRF adc_state ;reset 
    RETURN

ParseRx:
    MOVF rx_state,F
    BTFSC STATUS,2 ;waiting for start byte? 
    GOTO Wait
    MOVF rx_state,W 
    XORLW 0x01
    BTFSC STATUS,2 ;waiting for command?
    GOTO Command
    MOVF rx_state,W
    XORLW 0x02
    BTFSC STATUS,2 ;waiting for length?
    GOTO Length
    MOVF rx_state,W
    XORLW 0x03
    BTFSC STATUS,2 ;waiting for channel? 
    GOTO Channel
    GOTO ResetParse

Wait:
    MOVF rx_byte,W
    XORLW 0x24
    BTFSS STATUS,2 ;does the packet start with 24/$?
    RETURN ;no $ we wait 
    MOVLW 0x01 
    MOVWF rx_state ;yes $, now move to command 
    RETURN

Command:
    MOVF rx_byte,W
    XORLW 0x49 
    BTFSC STATUS,2 ;is it 49/A? ADC 
    GOTO Save
    MOVF rx_byte,W ;is it I?
    XORLW 0x41
    BTFSS STATUS,2
    GOTO ResetParse

Save:
    MOVF rx_byte,W 
    MOVWF rx_command ;save what was requested 
    MOVLW 0x02
    MOVWF rx_state
    RETURN

Length:
    MOVF rx_command,W
    XORLW 0x49
    BTFSC STATUS,2 ;is it device id? 
    GOTO ID

    MOVF rx_command,W
    XORLW 0x41
    BTFSS STATUS,2 ;is it A?
    GOTO ResetParse

    MOVF rx_byte,W
    XORLW 0x01
    BTFSS STATUS,2 ;is it 1? 
    GOTO ResetParse
    MOVLW 0x03
    MOVWF rx_state
    RETURN

ID:
    CLRF rx_state
    MOVF rx_byte,F
    BTFSS STATUS,2 ;does it have the ID? 
    RETURN
    MOVLW 0x01
    MOVWF reply_pending
    RETURN

Channel:
    CLRF rx_state
    MOVF rx_byte,F
    BTFSS STATUS,2 ;AN0 recieved? 
    RETURN
    MOVLW 0x02
    MOVWF reply_pending ;now it knows AN0 is recieved 
    CLRF adc_state
    RETURN

ResetParse:
    CLRF rx_state ;go back to wait for $ 
    RETURN

Process:
    BANKSEL reply_pending
    MOVF reply_pending,F
    BTFSC STATUS,2 ;does the response need ti be sent?
    RETURN

    MOVF tx_length,W
    XORWF tx_count,W
    BTFSS STATUS,2 ;sending prev packet 
    RETURN

    MOVF reply_pending,W
    XORLW 0x01 
    BTFSC STATUS,2 ;need the device ID? 
    GOTO BuildID
    MOVF reply_pending,W
    XORLW 0x02
    BTFSC STATUS,2 ;need ADC reading? 
    GOTO BuildADC
    GOTO BuildError

BuildID:
    MOVLW 0x49 ;I is for ID 
    MOVWF tx_data1 
    MOVLW 0x02 ;two bytes 
    MOVWF tx_data2
    MOVLW 0x33 ;high byte 
    MOVWF tx_data3
    MOVLW 0x75 ;low byte 
    MOVWF tx_data4
    MOVLW 0x05 ;five total bytes 
    GOTO FinishPacket

BuildADC:
    CALL ServiceAdc
    MOVF adc_state,W
    XORLW 0x02
    BTFSS STATUS,2 ;adc conversion done? 
    RETURN

    MOVLW 0x41 ;A for adc 
    MOVWF tx_data1
    MOVLW 0x03 ;data bytes 
    MOVWF tx_data2
    CLRF tx_data3 ;AN0 
    MOVF adc_high,W ;moving high to packet 
    MOVWF tx_data4
    MOVF adc_low,W ;moving low to packet 
    MOVWF tx_data5
    CLRF adc_state ;reset for next 
    MOVLW 0x06 ;now has all six bytes 
    GOTO FinishPacket

BuildError:
    MOVLW 0x45 ;45 is E for error 
    MOVWF tx_data1
    MOVLW 0x02
    MOVWF tx_data2
    MOVF reply_pending,W
    ADDLW -2 ;check which error code, 3 or 4? 
    MOVWF tx_data3
    CLRF tx_data4
    MOVLW 0x05

FinishPacket:
    MOVWF tx_length
    MOVLW 0x24 ;packet always starts with $
    MOVWF tx_data0;transmit first byte 
    CLRF tx_count 
    CLRF reply_pending;packet ready
    RETURN

ServiceAdc:
    BANKSEL adc_state
    MOVF adc_state,F
    BTFSC STATUS,2 ;is the adc running? 
    GOTO StartAdc

    MOVF adc_state,W
    XORLW 0x01
    BTFSS STATUS,2 ;is there an active conversion? 
    RETURN
    BTFSC ADCON0,1 ;is it done converting? 
    RETURN

    MOVF ADRESH,W ;read high byte 
    MOVWF adc_high
    BANKSEL ADRESL
    MOVF ADRESL,W ;read low byte 
    BANKSEL adc_low
    MOVWF adc_low
    MOVLW 0x02
    MOVWF adc_state ;adc state now shows there is a result 
    RETURN

StartAdc: ;new conversion
    BSF ADCON0,1 ;start 
    MOVLW 0x01 ;adc is 1 
    MOVWF adc_state
    RETURN

ServiceTx:
    BANKSEL tx_count
    MOVF tx_length,W
    XORWF tx_count,W
    BTFSC STATUS,2 ;have all packets been sent?
    RETURN
    BTFSS PIR1,4 ;transmit reg full?
    RETURN

    MOVF tx_count,W
    ADDLW tx_data0
    MOVWF FSR
    BCF STATUS,7 ;indirect address on bank 1/0? 
    MOVF INDF,W
    MOVWF TXREG
    INCF tx_count,F ;increase counter look at next byte 
    RETURN

Delay5ms: ;delay loop used for overrun error 
    MOVLW 0x5E
    MOVWF Count5ms
Delay5msLoop:
    CALL Delay50usLoop
    DECFSZ Count5ms
    GOTO Delay5msLoop
    MOVLW 0x04
    MOVWF Count5ms
    DECFSZ Count5ms
    GOTO $-1
    RETURN

Delay50usLoop:
    MOVLW 0x0F
    MOVWF Count50us
    DECFSZ Count50us,1
    GOTO $-1
    RETURN

END