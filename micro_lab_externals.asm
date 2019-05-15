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


	; Interrupt vector for atmega16
	jmp reset
	.org 0x0010
	jmp timer_handler
	.org 0x0012
	jmp error_timer	
	reti

adc_func:
	; Function to read from the adc
	; Inputs:  
	;	pot_ind   register to choose potentiometer
	; Outputs:
	;	pot_res_l low byte of adc measurment
	;   pot_res_h hight byte with adc measurment

	; Initialize adc
	or pot_ind, pot_mode
	out admux, pot_ind

	; Start conversion
	ldi tmp, 0b11000111
	out adcsra, tmp
	
wait_adc:
	sbic adcsra, 6
	rjmp wait_adc

	; Get results
	in pot_res_l, adcl
	in pot_res_h, adch

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

	; Set mode of the counter
	ldi tmp, 0b00000100
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
	; Start buzzer
	ldi tmp, 0b00000001
	out portc, tmp
ack:
	; Wait until the sw6 has been pressed
	sbic pind, 6
	rjmp ack

	clr tmp
	out portc, tmp
error:
	; Light error led
	ldi secs, 5
	ldi tmp, 0b11111110
	out portb, tmp
	rcall timer

	ser tmp
	out portb, tmp
	rcall timer
	;sbic pind, 6
	rjmp error
	ret 

check_for_errors:
	; Check if potentiometer 0 is ok
	rcall check_A1
	; Check q1
	sbis pind, 4
	rcall alarm
	; Check q2
	sbis pind, 5
	rcall alarm
	ret

error_timer:
	; Handler to call again check_for_errors
	sei
	rcall check_for_errors
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
	ser tmp
	out ddrb, tmp

	; Button
	out ddrc, tmp

	; Initialize buttons
	clr tmp
	out ddrd, tmp
	
	; Initiliaze general timer interrupts
	ldi tmp, 0b00000101
	out timsk, tmp

	; Start timer for error checking
	clr tmp
	out tcnt0, tmp
	ldi tmp, 0b00000101
	out tccr0, tmp

main:

	; Timer check
	ldi tmp, 0b10101010
	out portb, tmp

	ldi secs, 3
	rcall timer

	ldi tmp, 0xFF
	out portb, tmp
	ldi secs, 5
	rcall timer
	; A1 check
	;rcall check_A1
	;rcall alarm
	;rcall check_for_errors


Clock_freq:
.DW 0x3d09

Low_value:
.DW 0x0000
