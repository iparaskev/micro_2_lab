.include "m16def.inc"

.def timer_init_l = r4
.def timer_init_h = r5
.def timer_flag = r24
.def lower_flag = r25
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
;        - Real time of timer

	; Interrupt vector for atmega16
	rjmp reset
	.org 0x0012
	rjmp timer_handler
	reti

adc_func:
	; Function to read from the adc
	; Inputs:  
	;	pot_ind   register to choose potentiometer
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
	in pot_res_l, adcl
	in pot_res_h, adch

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

check_low:
	; Function to check if adc_value is above a value and return true or 
	; false. 

	; Load constant
	ldi zh, high(Low_value*2)
	ldi zl, low(Low_value*2)
	
	; Check high byte
	adiw zl, 1
	lpm
	cp pot_res_h, r0
	brlo lower

	; Check low byte
	sbiw zl, 1
	lpm 
	cp pot_res_l, r0
	brlo lower
higher:
	ldi lower_flag, 0
	rjmp end_check
lower:
	ldi lower_flag, 1
end_check:
	ret

check_A1:
	; Function to get the value of A1 sensor
	; Get measurment
	ldi pot_ind, 0
	rcall adc_func
	rcall check_low
	sbrc lower_flag, 0
	rjmp alarm
	ret
alarm: 
	; Alarm
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

	; Timer check
	ldi secs, 3
	ldi tmp, 0x00
	out portb, tmp
	rcall timer
	ldi tmp, 0xFF
	out portb, tmp

	; A1 check
	rcall check_A1
Clock_freq:
.DW 0x0f42

Low_value:
.DW 0x0001
