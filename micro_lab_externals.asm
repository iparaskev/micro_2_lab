.include "m16def.inc"

.def timer_init_l = r4
.def timer_init_h = r5
.def timer_flag = r24
.def tmp = r16
.def timer_start_l = r17
.def timer_start_h = r18
.def pot_ind = r19    ; Variable to choose potentiometer
.def pot_mode = r20   ; The first bits of the admux register
.def pot_res_l = r21
.def pot_res_h = r22
.def secs = r23        ; The delay seconds for the timer


; TODO: Debug on real hardware
; Debug steps: 
;        - If interrupt works

	; Interrupt vector for atmega16
	rjmp reset
	.org 0x0012
	rjmp timer_handler
	reti

adc_func:
	; Function to read from the adc
	; Inputs:  
	;	pot_ind   register to choose potentiometer
	;       pot_mode  register with the mode of adc
	; Outputs:
	;	pot_res_l low byte of adc measurment
	;       pot_res_h hight byte with adc measurment

	; Initialize adc
	or pot_ind, pot_mode
	out admux, pot_ind

	; Start conversion
	ldi tmp, 0b11001111
	out adcsra, tmp
	
wait_adc:
	sbic adcsra, 6
	rjmp wait_adc

	; Get results
	ldi pot_res_l, adcl
	ldi pot_res_h, adch

	; Hardware print for the end of conversion
	clr tmp
	out portb, tmp

	ret

timer:
	; Set timer for specific delay
	; Input:
	;	sec	the delay time 

	; Load number of commands per sec for prescaler=1024
	; Initial clock freq is 4MHz so the new clock freq is 3096Hz
	ldi zh, high(Clock_freq*2)
	ldi zl, low(Clock_freq*2)

	; Multiply first byte with the seconds
	lpm
	mov tmp, r0
	adiw zl, 1
	mul tmp, secs
	movw timer_init_l, r0

	; Multiply second byte with the seconds
	lpm
	mov tmp, r0
	mul tmp, secs
	
	; Add low byte to the high byte
	add timer_init_h, r0

	ldi timer_start_l, 0xFF
	ldi timer_start_h, 0xFF
	
	; Initial value for the counter to start
	sub timer_start_l, timer_init_l
	sbc timer_start_h, timer_init_h

	out tcnt1l, timer_start_l
	out tcnt1h, timer_start_h

	; Initiliaze general timer interrupts
	ldi tmp, 0b00000100
	out timsk, tmp

	; Set mode of the counter
	ldi tmp, 0b00000101
	out tccr1b, tmp

loop:
	sbrs timer_flag, 0
	rjmp loop
	
	; Reset timer flag
	ldi timer_flag, 0

	ret
	
timer_handler:
	; Handle timer interrupt 
	ldi timer_flag, 1
	reti

reset:
	; Initialize stack pointer
	ldi tmp, high(ramend)
	out sph, tmp
	ldi tmp, low(ramend)
	out spl, tmp

	; Enable global interrupts
	sei

	; Initialize pot_mode 
	ldi pot_mode, 0b11000000

	; Initialize leds
	ldi tmp, 0xFF
	out ddrb, tmp

main:
	ldi secs, 3
	rcall timer

Clock_freq:
.DW 0x0f42
