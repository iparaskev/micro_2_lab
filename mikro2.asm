.include "m16def.inc"

.def pot_gen_low_flag = r6
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
.def timer_count = r26

; Interrupt vector for atmega16
jmp reset
.org 0x0010
jmp timer_handler
.org 0x0012
jmp error_timer	
reti

wait_start:
	; wait for the switch 0 to be pushed
	clr tmp
	out portb, tmp
	;ldi secs, 1
	;rcall timer
	;in tmp, portd
	rcall check_A1
	sbic PIND, 0
	rjmp wait_start

start_tape:
	; check if the required conditions are met and start the production tape
	; condition 1: b1 = 0
	ser tmp
	out portb, tmp
	rcall timer
	
	rcall check_A1

	ldi pot_ind, 1
	rcall adc_func ; read b1 value
	rcall check_low
	mov pot_gen_low_flag, lower_flag
	sbrs pot_gen_low_flag, 0 ; if silo 1 is empty skip horn
	rjmp wait_start
	
	; condition 2: b3 = 0
	rcall check_A1
	ldi pot_ind, 3
	rcall adc_func ; read b3 value
	rcall check_low
	mov pot_gen_low_flag, lower_flag
	sbrs pot_gen_low_flag, 0 ; if silo 2 is empty skip horn
	rjmp wait_start
	
	; condition 3: the y valve is at position y1
	sbic pind, 1
	rjmp wait_start

tape_run:
	; Wait for the moving tape to take normal speed
	; and open led 7
	ldi tmp, 0b01111111
	out portb, tmp

	ldi secs, 7
	rcall timer
	
load_silo_1:
	rcall check_A1
	ldi pot_ind, 2
	rcall adc_func
	rcall check_low
	mov pot_gen_low_flag, lower_flag
	sbrc pot_gen_low_flag, 1 
	rjmp load_silo_1; while b2 is lower than a threshold, keep loading silo 1
	
	; switch the pump Y2
	sbic pind, 2
	rcall alarm

load_silo_2:
	rcall check_A1
	ldi pot_ind, 4
	rcall adc_func
	rcall check_low
	mov pot_gen_low_flag, lower_flag
	sbrc pot_gen_low_flag, 1 	
	rjmp load_silo_2; while b4 is lower than a threshold, keep loading silo 2
	
stop_engines:
	; when silo 2 is filled stop engines
	ldi tmp, 0b01010101
	out portb, tmp
	ldi secs, 2
	rcall timer
	ldi tmp, 0b10101010
	out portb, tmp
	rcall timer
	rjmp stop_engines


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
	ldi zh, high(Clock_freq*2)
	ldi zl, low(Clock_freq*2)
	
	; Load 1 sec
	lpm
	mov timer_init_l, r0
	adiw zl, 1
	lpm
	mov timer_init_h, r0

	ldi timer_start_l, 0xFF
	ldi timer_start_h, 0xFF
	
	; Initial value for the counter to start
	sub timer_start_l, timer_init_l
	sbc timer_start_h, timer_init_h
	
	ldi timer_count, 0

start_count:
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

	inc timer_count
	cp  timer_count, secs
	brlo start_count
	
	ret
	
timer_handler:
	; Handle timer interrupt 
	ldi timer_flag, 1
	reti

check_low:
	; Function to check if adc_value is above a value and return true or 
	; false. 
	ldi lower_flag, 0

	; Load constant
	ldi zh, high(Values*2)
	ldi zl, low(Values*2)
	
	; Check high byte
	adiw zl, 1
	lpm 
	cp pot_res_h, r0
	brlo lower
	brne high_check	

	; Check low byte
	sbiw zl, 1
	lpm 
	cp pot_res_l, r0
	brlo lower
higher:
	rjmp high_check
lower:
	ldi lower_flag, 1

	; Load constant
high_check:
	; Load constant
	ldi zh, high(Values*2)
	ldi zl, low(Values*2)

	; Check high byte
	adiw zl, 3
	lpm
	cp pot_res_h, r0
	brlo lower_high
	brne end_check

	; Check low byte
	sbiw zl, 1
	lpm 
	cp pot_res_l, r0
	brlo lower_high
higher_high:
	rjmp end_check
lower_high:
	ori lower_flag, 2

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
	ldi tmp, 0b00000100
	out timsk, tmp
ack:
	; Wait until the sw6 has been pressed
	sbic pind, 6
	rjmp ack

	clr tmp
	out portc, tmp
error:
	; Light error led
	ldi secs, 1
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

	;rcall check_A1

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
	ldi secs, 1
	rcall timer
	rcall wait_start
meas:
	rcall adc_func
	com pot_res_l
	out portb, pot_res_l
	rjmp meas
	 
	; Timer check
	ldi tmp, 0b10101010
	out portb, tmp

	ldi secs, 3
	rcall timer

	ldi tmp, 0xFF
	out portb, tmp
	ldi secs, 4
	rcall timer
	rjmp main


Clock_freq:
.DW 0x3d09

Values:
.DW 0x0020, 0x007a
