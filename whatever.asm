.def temp = r16
.def pot_ind = r19
.def pot_mode = r20
.def pot_res_1 = r21
.def pot_res_2 = r22

LDI	R16, low(RAMEND)
OUT	SPL, R16
LDI	R16, high(RAMEND)
OUT	SPH, R16

start:
	; set all pins of portd as input
	clr temp
	out DDRD, temp
	; set all pins of portb as output
	com temp
	out DDRB, temp

wait_start:
	; wait for the switch 0 to be pushed
	in temp, portd
	sbis portd, 0
	rjmp wait_start

start_tape:
	; check if the required conditions are met and start the production tape
	; condition 1: b1 = 0
	ldi pot_ind, 1
	rcall adc_func ; read b1 value
	rcall check_low
	sbrs lower_flag, 0 ; if silo 1 is empty skip horn
	rjmp alarm
	
	; condition 2: b3 = 0
	ldi pot_ind, 3
	rcall adc_func ; read b3 value
	rcall check_low
	sbrs lower_flag, 0; if silo 2 is empty skip horn
	rjmp alarm

	; condition 3: a1 > 0
	; check_A1
	
	; condition 4: b2 = 0 or b4 = 0
	ldi pot_ind, 2
	rcall adc_func ; read b2
	rcall check_low
	mov temp, lower_flag
	
	ldi pot_ind, 4
	rcall adc_func ; read b4
	rcall check_low 
	or temp, comp_res

	sbrs temp, 0 ; if the first bit of the or result is 1, skip horn
	rjmp alarm

	;condition 5: Q2 = 0
	in temp, portd ; read sw5
	sbis portd, 5
	rjmp start_tape ; if sw5 is not pressed, do what?


	; if all conditions are met, open led7
	ldi temp, 0b10000000
	out portd, temp

; 7 sec_timer

start_m1:
	; start the product loading in silos if sw4 and sw5 are not pressed
	sbic portd, 4
	rjmp alarm
	sbic portd, 5
	rjmp alarm

load_silo_1:
	ldi pot_ind, 2
	rcall adc_read
	rcall check_low
	sbrc lower_flag, 0
	rjmp load_silo_1; while b2 is lower than a threshold, keep loading silo 1

; switch the pump Y2

load_silo_2:
	ldi pot_ind, 4
	rcall adc_read
	rcall check_low
	sbrc lower_flag, 0
	rjmp load_silo_1; while b4 is lower than a threshold, keep loading silo 2
	
; when silo 2 is filled stop engines


