;**********************************************************************
;                                                                     
;   rc-light-controller.asm
;
;                                                                     
;**********************************************************************
;                                                                     
;   Author:         Werner Lane                                                   
;   E-mail:         laneboysrc@gmail.com 
;                                                                     
;**********************************************************************
    TITLE       RC Light Controller
    LIST        p=pic16f628a, r=dec
    RADIX       dec
    
    #include    <p16f628a.inc>
 
    __CONFIG _CP_OFF & _WDT_OFF & _BODEN_ON & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF & _LVP_OFF



;**********************************************************************
;   The following outputs are needed:
;   - Stand light, tail light
;   - Head light
;   - High beam
;   - Fog light, fog rear light
;   - Indicators L + R
;   - Brake light
;   - Reversing light
;   - Servo output for steering
;   
;   
;   Inputs:
;   - Steering servo
;   - Throttle servo
;   - CH3 momentary
;   
;   
;   Modes that the SW must handle:
;   - Light mode:
;       - Stand light
;       - + Head light
;       - + Fog lights
;       - + High beam
;   - Drive mode:
;       - Neutral
;       - Forward
;       - Braking
;       - Reverse
;   - Indicators
;   - Steering servo pass-through
;   - Hazard lights
;
;
;   Other functions:
;   - Failsafe mode: all lights blink when no signal
;   - Program CH3
;   - Program TH neutral, full fwd, full rev
;   - Program servo output for steering servo: direction, neutral and end points
;
;
;   Slave unit is controlled via PPM (6 lights + 1 steering)
;
;
;   Operation:
;   - CH3
;       - short press if hazard lights: hazard lights off
;       - short press: cycle through light modes up
;       - double press: cycle through light modes down
;       - triple press: hazard lights
;       - long press: all lights off
;
;**********************************************************************



;***** VARIABLE DEFINITIONS
w_temp		    EQU	0x70    ; variable used for context saving 
status_temp   	EQU	0x71    ; variable used for context saving
CounterA	    EQU	0x72	; counters for delay loop
CounterB	    EQU	0x73
CounterC	    EQU	0x74
CloseCounter	EQU	0x75	; counter x20ms for amount of time the servo is steered when closing
OpenCounter	    EQU	0x76	; counter x20ms for amount of time the servo is steered when opening
flag		    EQU	0x77	; just various flags

#define door_status flag,0

;***** PORT DEFINITIONS
#define servo     PORTB,3
#define led_close PORTA,0
#define led_open  PORTA,1
#define sensor    PORTA,2

; unit: 20ms
#define SERVO_MOVE_TIME 250	
#define T20ms_H 0xB1
#define T20ms_L 0xE0

;**********************************************************************
    ORG     0x000           ; processor reset vector
    goto    Main            ; go to beginning of program

;**********************************************************************
;    ORG     0x004           ; interrupt vector location
;    movwf   w_temp          ; save off current W register contents
;    movf	STATUS,w        ; move status register into W register
;    movwf	status_temp     ; save off contents of STATUS register

;    banksel T1CON
;    bcf	T1CON,TMR1ON	; stop the timer
;    movlw	T20ms_H		; set Timer1 to 20ms (0xFFFF-0x4E1F)
;    movwf	TMR1H
;    movlw	T20ms_L
;    movwf	TMR1L
;    bsf	T1CON,TMR1ON	; re-start the 20ms timer

;    bcf	PIR1, TMR1IF	; clear the interrupt flag

;    movf	CloseCounter,1	; 'close' counter running?
;    btfss	STATUS, Z
;    goto	closing		; yes: send 'close' pulse to servo

;    movf	OpenCounter,1	; 'close' counter running?
;    btfss	STATUS, Z
;    goto	opening		; yes: send 'open' pulse to servo

;    bcf	led_close	; neither opening nor closing: clear all LEDs and return
;    bcf	led_open
;    goto	done

;closing
;    bcf	led_open
;    bsf	led_close	; turn on 'closing' LED
;    bsf	servo		; make a pulse to the servo of length 0.9ms
;    call	delay_0.9ms
;    bcf	servo
;    decf	CloseCounter
;    goto	done

;opening
;    bcf	led_close
;    bsf	led_open	; turn on 'opening' LED
;    bsf	servo		; make a pulse to the servo of length 2.1ms
;    call	delay_2.1ms
;    bcf	servo
;    decf	OpenCounter

;done		
;    movf	status_temp,w	; retrieve copy of STATUS register
;    movwf	STATUS          ; restore pre-isr STATUS register contents
;    swapf	w_temp,f
;    swapf	w_temp,w        ; restore pre-isr W register contents
;    retfie                  ; return from interrupt



;**********************************************************************
Main
    movlw	0x07
    movwf	CMCON		; disable the comparators

    clrf	PORTA		; set all (output) ports to GND
    clrf	PORTB	

    banksel	TRISB
    bcf		OPTION_REG, T0CS	

    movlw	0x00		; make all ports A output
    movwf	TRISA
    movlw	0x20		; make all ports B except RB5 output
    movwf	TRISB

    banksel	PORTA
    bcf		PORTA, 0


    ; main loop 
main_loop
    clrf    T1CON       ; Stop timer 1, runs at 1us per tick, internal oscillator
    clrf    TMR1H    
    clrf    TMR1L

    btfss   PORTB, 5    ; Wait until servo signal is high
    goto    main_loop


    movlw   0x01        ; Start timer 1
    movwf   T1CON

wait_for_low
    btfsc   PORTB, 5    ; Wait until servo signal is LOW
    goto    wait_for_low

    
    clrf    T1CON       ; Stop timer 1

    movf    TMR1H, 0   ; 1500ms = 0x5DC
    sublw   0x05
    btfss   STATUS, 0   ; Carry/!Borrow bit
    goto    is_larger

    movf    TMR1L, 0   
    sublw   0xdc
    btfss   STATUS, 0   ; Carry/!Borrow bit
    goto    is_larger

    bsf     PORTA, 0
    goto    main_loop

is_larger
    bcf     PORTA, 0
    goto    main_loop



;**********************************************************************
delay_2.1ms
    movlw	D'3'
    movwf	CounterB
    movlw	D'185'
    movwf	CounterA
    goto	delay_loop

delay_0.9ms
    movlw	D'2'
    movwf	CounterB
    movlw	D'40'
    movwf	CounterA
delay_loop
    decfsz	CounterA,1
    goto	delay_loop 
    decfsz	CounterB,1
    goto	delay_loop 
    return


    END			; directive 'end of program'
