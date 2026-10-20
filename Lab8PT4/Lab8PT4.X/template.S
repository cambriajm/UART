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

    W_TEMP          EQU 0x7D
    STATUS_TEMP     EQU 0x7E

    tx_length       EQU 0x28
    tx_count        EQU 0x29

    Count50us       EQU 0x20
    Count5ms        EQU 0x21

    servo_rx_hi     EQU 0x22
    servo_rx_lo     EQU 0x23
    servo_pending_hi EQU 0x24
    servo_pending_lo EQU 0x25
    servo_update    EQU 0x26
    servo_busy      EQU 0x27

; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    GOTO Setup

; Interrupt Vector at 0004h. Execution starts here after an interrupt.
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    GOTO ISRHandler

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
    BCF TRISC,2
    MOVLW 0b10000000
    MOVWF ADCON1

    BANKSEL RCSTA
    MOVLW 0b10010000
    MOVWF RCSTA
    MOVLW 0b01000001
    MOVWF ADCON0

    BANKSEL PORTA
    CLRF PORTA
    BANKSEL PORTC
    BCF PORTC,2

    CLRF rx_byte
    CLRF rx_state
    CLRF rx_command
    CLRF reply_pending
    CLRF adc_state
    CLRF adc_high
    CLRF adc_low
    CLRF tx_length
    CLRF tx_count

    CLRF servo_rx_hi
    CLRF servo_rx_lo
    MOVLW 0xB7
    MOVWF servo_pending_hi
    MOVLW 0xBC
    MOVWF servo_pending_lo
    CLRF servo_update
    CLRF servo_busy

    ; CCP1 Setup
    BANKSEL CCP1CON
    MOVLW 0x0A
    MOVWF CCP1CON ;CCP1 Compare mode, software interrupt on match

    ; Initial servo setting is 1500 us
    BANKSEL CCPR1H
    MOVLW 0xB7
    MOVWF CCPR1H
    MOVLW 0xBC
    MOVWF CCPR1L

    ; Timer1 Setup
    BANKSEL T1CON
    CLRF T1CON ;Timer1 off while configuring

    BANKSEL TMR1H
    MOVLW 0xB1
    MOVWF TMR1H
    MOVLW 0xE0
    MOVWF TMR1L ;Timer1 preload for 20 ms frame

    BANKSEL PIR1
    BCF PIR1,0 ;clear Timer1 interrupt flag
    BCF PIR1,2 ;clear CCP1 interrupt flag

    BANKSEL PIE1
    BSF PIE1,0 ;enable Timer1 interrupt
    BCF PIE1,2 ;enable CCP1 interrupt at frame start

    BANKSEL T1CON
    MOVLW 0x01
    MOVWF T1CON ;Timer1 on, Fosc/4, 1:1 prescaler

    BANKSEL INTCON
    BSF INTCON,6 ;enable peripheral interrupts
    BSF INTCON,7 ;enable global interrupts

Main:
    BANKSEL servo_busy
    BTFSC servo_busy,0
    GOTO Main

    BSF PORTA,1
    CALL ServiceRx
    BCF PORTA,1

    BANKSEL servo_busy
    BTFSC servo_busy,0
    GOTO Main
    CALL Process

    BANKSEL servo_busy
    BTFSC servo_busy,0
    GOTO Main
    CALL ServiceTx

    GOTO Main

ServiceRx:
    BANKSEL RCSTA
    BTFSC RCSTA,1 ;overrun error?
    GOTO RxRun

    BTFSS PIR1,5 ;new byte received?
    RETURN
    BTFSC RCSTA,2 ;frame error on new byte?
    GOTO RxOut

    MOVF RCREG,W
    MOVWF rx_byte ;read byte

    MOVF reply_pending,F
    BTFSS STATUS,2 ;ignore new received byte unless ready
    RETURN

    CALL ParseRx
    RETURN

RxRun:
    BCF RCSTA,4
    BSF RCSTA,4 ;reset/clear the receiver
    MOVLW 0x04 ;four means overrun error
    GOTO RxError

RxOut:
    MOVF RCREG,W ;discard bad byte
    MOVLW 0x03 ;three is a framing error

RxError:
    MOVWF reply_pending ;save error to address later
    CLRF rx_state ;reset parser
    CLRF adc_state ;reset ADC state
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
    MOVF rx_state,W
    XORLW 0x04
    BTFSC STATUS,2 ;waiting for servo high byte?
    GOTO ServoHigh
    MOVF rx_state,W
    XORLW 0x05
    BTFSC STATUS,2 ;waiting for servo low byte?
    GOTO ServoLow
    GOTO ResetParse

Wait:
    MOVF rx_byte,W
    XORLW 0x24
    BTFSS STATUS,2 ;does the packet start with 24/$?
    RETURN
    MOVLW 0x01
    MOVWF rx_state ;now wait for command
    RETURN

Command:
    MOVF rx_byte,W
    XORLW 0x49
    BTFSC STATUS,2 ;is it I?
    GOTO Save

    MOVF rx_byte,W
    XORLW 0x41
    BTFSC STATUS,2 ;is it A?
    GOTO Save

    MOVF rx_byte,W
    XORLW 0x53
    BTFSS STATUS,2 ;is it S?
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
    BTFSC STATUS,2 ;is it device ID?
    GOTO ID

    MOVF rx_command,W
    XORLW 0x41
    BTFSC STATUS,2 ;is it A?
    GOTO AdcLength

    MOVF rx_command,W
    XORLW 0x53
    BTFSC STATUS,2 ;is it S?
    GOTO ServoLength

    GOTO ResetParse

AdcLength:
    MOVF rx_byte,W
    XORLW 0x01
    BTFSS STATUS,2 ;is it 1?
    GOTO ResetParse
    MOVLW 0x03
    MOVWF rx_state
    RETURN

ServoLength:
    MOVF rx_byte,W
    XORLW 0x02
    BTFSS STATUS,2 ;servo command must contain 2 bytes
    GOTO ResetParse
    MOVLW 0x04
    MOVWF rx_state
    RETURN

ID:
    CLRF rx_state
    MOVF rx_byte,F
    BTFSS STATUS,2 ;does it have the ID length?
    RETURN
    MOVLW 0x01
    MOVWF reply_pending
    RETURN

Channel:
    CLRF rx_state
    MOVF rx_byte,F
    BTFSS STATUS,2 ;AN0 received?
    RETURN
    MOVLW 0x02
    MOVWF reply_pending ;now it knows AN0 is received
    CLRF adc_state
    RETURN

ServoHigh:
    BANKSEL servo_rx_hi
    MOVF rx_byte,W
    MOVWF servo_rx_hi ;save compare high byte
    MOVLW 0x05
    MOVWF rx_state ;now wait for low byte
    RETURN

ServoLow:
    BANKSEL servo_rx_lo
    MOVF rx_byte,W
    MOVWF servo_rx_lo ;save compare low byte
    CLRF rx_state
    GOTO ValidateServo

ValidateServo:
    BANKSEL servo_rx_hi
    MOVF servo_rx_hi,W
    XORLW 0xB3
    BTFSC STATUS,2
    GOTO ServoMin

    MOVF servo_rx_hi,W
    XORLW 0xBB
    BTFSC STATUS,2
    GOTO ServoMax

    MOVLW 0xB3
    SUBWF servo_rx_hi,W
    BTFSS STATUS,0 ;high byte below B3?
    GOTO ServoInvalid

    MOVLW 0xBB
    SUBWF servo_rx_hi,W
    BTFSC STATUS,0 ;high byte at or above BB?
    GOTO ServoInvalid

    GOTO SaveServo

ServoMin:
    MOVLW 0xD4
    SUBWF servo_rx_lo,W
    BTFSS STATUS,0 ;low byte below D4?
    GOTO ServoInvalid
    GOTO SaveServo

ServoMax:
    MOVLW 0xA4
    SUBWF servo_rx_lo,W
    BTFSS STATUS,0 ;low byte below A4 is valid
    GOTO SaveServo
    BTFSC STATUS,2 ;equal to A4?
    GOTO SaveServo
    GOTO ServoInvalid

SaveServo:
    BCF INTCON,7 ;protect the two-byte update

    BANKSEL servo_pending_hi
    MOVF servo_rx_hi,W
    MOVWF servo_pending_hi
    MOVF servo_rx_lo,W
    MOVWF servo_pending_lo
    BSF servo_update,0

    BANKSEL INTCON
    BSF INTCON,7 ;restore global interrupts
    RETURN

ServoInvalid:
    MOVLW 0x05
    MOVWF reply_pending ;request invalid-servo response
    RETURN

ResetParse:
    CLRF rx_state ;go back to wait for $
    RETURN

Process:
    BANKSEL reply_pending
    MOVF reply_pending,F
    BTFSC STATUS,2 ;does the response need to be sent?
    RETURN

    BANKSEL tx_length
    MOVF tx_length,W
    BANKSEL tx_count
    XORWF tx_count,W
    BTFSS STATUS,2 ;sending previous packet?
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
    MOVLW 0x02 ;two data bytes
    MOVWF tx_data2
    MOVLW 0x33 ;high ID byte
    MOVWF tx_data3
    MOVLW 0x75 ;low ID byte
    MOVWF tx_data4
    MOVLW 0x05 ;five total bytes
    GOTO FinishPacket

BuildADC:
    BANKSEL servo_busy
    BTFSC servo_busy,0
    RETURN

    CALL ServiceAdc
    MOVF adc_state,W
    XORLW 0x02
    BTFSS STATUS,2 ;ADC conversion done?
    RETURN

    MOVLW 0x41 ;A for ADC
    MOVWF tx_data1
    MOVLW 0x03 ;three data bytes
    MOVWF tx_data2
    CLRF tx_data3 ;AN0
    MOVF adc_high,W
    MOVWF tx_data4 ;ADC high byte
    MOVF adc_low,W
    MOVWF tx_data5 ;ADC low byte
    CLRF adc_state ;reset for next conversion
    MOVLW 0x06 ;six total bytes
    GOTO FinishPacket

BuildError:
    MOVF reply_pending,W
    XORLW 0x05
    BTFSC STATUS,2
    GOTO BuildServoError

    MOVLW 0x45 ;45 is E for error
    MOVWF tx_data1
    MOVLW 0x02
    MOVWF tx_data2
    MOVF reply_pending,W
    ADDLW -2 ;check which receive error, 3 or 4?
    MOVWF tx_data3
    CLRF tx_data4
    MOVLW 0x05
    GOTO FinishPacket

BuildServoError:
    MOVLW 0x45 ;45 is E for error
    MOVWF tx_data1
    MOVLW 0x02
    MOVWF tx_data2
    MOVLW 0x03
    MOVWF tx_data3
    MOVLW 0x01
    MOVWF tx_data4
    MOVLW 0x05

FinishPacket:
    BANKSEL tx_length
    MOVWF tx_length
    MOVLW 0x24 ;packet always starts with $
    MOVWF tx_data0
    BANKSEL tx_count
    CLRF tx_count
    BANKSEL reply_pending
    CLRF reply_pending ;packet ready
    RETURN

ServiceAdc:
    BANKSEL adc_state
    MOVF adc_state,F
    BTFSC STATUS,2 ;is the ADC running?
    GOTO StartAdc

    MOVF adc_state,W
    XORLW 0x01
    BTFSS STATUS,2 ;is there an active conversion?
    RETURN

    BANKSEL ADCON0
    BTFSC ADCON0,1 ;is it still converting?
    RETURN

    BANKSEL ADRESH
    MOVF ADRESH,W
    BANKSEL adc_high
    MOVWF adc_high

    BANKSEL ADRESL
    MOVF ADRESL,W
    BANKSEL adc_low
    MOVWF adc_low

    MOVLW 0x02
    MOVWF adc_state ;ADC result is ready
    RETURN

StartAdc:
    BANKSEL ADCON0
    BSF ADCON0,1 ;start conversion
    BANKSEL adc_state
    MOVLW 0x01
    MOVWF adc_state
    RETURN

ServiceTx:
    BANKSEL tx_length
    MOVF tx_length,W
    BANKSEL tx_count
    XORWF tx_count,W
    BTFSC STATUS,2 ;have all packet bytes been sent?
    RETURN

    BTFSS PIR1,4 ;transmit register ready?
    RETURN

    MOVF tx_count,W
    ADDLW tx_data0
    MOVWF FSR
    BCF STATUS,7 ;indirect address in bank 0
    MOVF INDF,W
    MOVWF TXREG
    INCF tx_count,F ;increase counter for next byte
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

ISRHandler:
    ; Save W and STATUS before changing anything in interrupt
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP

    ; Check Timer1 overflow interrupt first.
    BANKSEL PIR1
    BTFSC PIR1,0 ;did Timer1 overflow?
    GOTO Timer1ISR

    ; Check CCP1 compare interrupt.
    BTFSC PIR1,2 ;did Timer1 match CCPR1?
    GOTO CCP1ISR
    GOTO ISRDone

Timer1ISR:
    ; Timer1 overflow marks the beginning of a new 20 ms frame.
    BANKSEL PIR1
    BCF PIR1,0 ;clear Timer1 interrupt flag

    ; Reload Timer1 with 0xB1E0 for another 20 ms frame.
    BANKSEL TMR1H
    MOVLW 0xB1
    MOVWF TMR1H
    MOVLW 0xE0
    MOVWF TMR1L

    ; Start servo pulse HIGH.
    BANKSEL PORTC
    BSF PORTC,2

    ; Transfer a new target only at the frame boundary.
    BANKSEL servo_update
    BTFSS servo_update,0
    GOTO ServoNoUpdate

    BANKSEL servo_pending_lo
    MOVF servo_pending_lo,W
    BANKSEL CCPR1L
    MOVWF CCPR1L

    BANKSEL servo_pending_hi
    MOVF servo_pending_hi,W
    BANKSEL CCPR1H
    MOVWF CCPR1H

    BANKSEL servo_update
    BCF servo_update,0

ServoNoUpdate:
    ; Clear any old CCP interrupt flag before enabling it.
    BANKSEL PIR1
    BCF PIR1,2 ;clear CCP1IF

    ; Mark servo pulse as active.
    BANKSEL servo_busy
    BSF servo_busy,0

    ; Enable CCP1 interrupt for this servo pulse.
    BANKSEL PIE1
    BSF PIE1,2
    GOTO ISRDone

CCP1ISR:
    ; Compare value reached: end the servo pulse.
    BANKSEL PIR1
    BCF PIR1,2 ;clear CCP1 interrupt flag

    ; End the servo pulse.
    BANKSEL PORTC
    BCF PORTC,2 ;servo signal LOW

    ; Disable CCP interrupt until the next servo pulse.
    BANKSEL PIE1
    BCF PIE1,2

    ; Mark servo pulse as finished.
    BANKSEL servo_busy
    BCF servo_busy,0
    GOTO ISRDone

ISRDone:
    ; Restore STATUS and W register
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    RETFIE

END