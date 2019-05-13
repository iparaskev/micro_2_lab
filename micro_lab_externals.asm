.include "m16def.inc"

.def tmp = r16
.def pot_ind = r19    ; Variable to choose potentiometer
.def pot_mode = r20   ; The first bits of the admux register
.def pot_res_l = r21
.def pot_res_h = r22

; TODO: Debug on real hardware
; Debug steps: 
;        - If interrupt works

	; Interrupt vector for atmega16
	jmp reset
	reti                   ; Store Program Memory Ready Handler

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
	ldi pot_ind, 0	
	rcall adc_func

	ldi pot_ind, 1
	rcall adc_func

	ldi pot_ind, 2
	rcall adc_func

	ldi pot_ind, 3
	rcall adc_func

	ldi pot_ind, 4
	rcall adc_func
