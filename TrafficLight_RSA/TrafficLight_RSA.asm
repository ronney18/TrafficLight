/* 
	Name: Ronney Sanchez
	Date: 11/29/16
	Course: CTE210 Microcomputers
	Program: Traffic Light
	Description: This program store a 1 for Pin 4 to SRAM and it grab that set of bit instruction and load it to a register. The program then takes that
	register, display it to the first light on the board and then shift that 1 on the bit to the left so that it could turn the next light on. 
	It will keep shifting to the left until and overflow occurrs and then branches back to the setup.

	comment out in atmel studio
	.device ATmega328P
	.equ INT_VECTORS_SIZE	= 52   size in words

	 timer stuff
	.equ TCNT0	= 0x26
	.equ TCCR0B	= 0x25
	.equ TIMSK0	= 0x6e

	 output stuff
	.equ PORTD 	= 0x0b
	.equ DDRD 	= 0x0a
	.equ PORTB 	= 0x05
	.equ DDRB 	= 0x04
*/

.def overflows = R17
.def temp = R16

.org 0 ; reset instruction at $0
.device ATmega328P ;The device that we are using is the ATmega328P
.equ size = 5 ;Equate the size to 6
.dseg ;Data segment to allocate array memory
myArray: .byte size ;Allocate 1 byte for the array

.cseg ;Current segment as code
.org 0 ;Starting at address 0
rjmp setup ;Jump to the setup


.org 0x0020            ;overflow interrupt handler at $20 - see data sheet
rjmp overflow_handler  ;jump to handler

.org INT_VECTORS_SIZE  ;start the program after the interrupt table

setup:
	ldi temp, 0b00000001  ; set the Timer Overflow Interrupt Enabled bit(TOIE0)
	sts TIMSK0, temp      ; of the Timer Interrupt Mask Register (TIMSK0)

	sei                   ; enable global interrupts
                        ; this must be disabled when you write to SPL/SPH
                        ; this is discussed in CH6 of the text

	ldi temp,  0b00000101 ; set the Clock Selector Bits CS00, CS01, CS02 to 101
	out TCCR0B, temp      ; Timer Counter0, TCNT0 in to FCPU/1024 (see data sheet)
                        ; FCPU is 16Mhz that is 16000000 cycles per sec
                        ; 16000000/1024 = 15625 "ticks" per second
                        ; timer "ticks" are stored in an 8 bit register
                        ; it will overflow after 256 "ticks"
                        ; 15625/256 = 61.03 about 61 overflows per second

	clr temp
	out TCNT0, temp       ;initialize Timer Counter0 to 0

	.def limit = r19 ;Define the limit as register 19
	.def number = r25 ;Define the number register as register 25
	.def red_light = r30
	ldi YL, low(myArray) ;Load the low byte of the array to the low Y register
	ldi YH, high(myArray) ;Load the high byte of the array to the high Y register
	ldi limit, size ;Load the size of the array to the limit register

	ldi temp, 0b00110000
	st Y+, temp

	ldi temp, 0b01010000
	st Y+, temp

	ldi temp, 0b10000100
	st Y+, temp

	ldi temp, 0b10001000
	st Y+, temp

	ldi temp, 0b10010000
	st Y, temp

	sbiw Y, (size - 1)

	ld number, Y ;Load Y to the number register
	ldi temp, 0xFF ;Load all 1s to temp
	out DDRD, temp ;Output all the 1s to the Data Direction Register in Port D

	ldi temp, 0x00
	out DDRB, temp
	
	rjmp main ;Jump to main

main:
	;Turn ON LED
	rcall delay ;call the delay function
	rcall display ;Call the display function
				
	;TURN OFF LED
	rcall delay ;delay again
	ld number, Y+
	cpi number, 0b10010000 ;Compare the number register with the overflow binary 0b00000000
	breq wait_for_button ;Branch to setup if equal to 0b00000000
	rjmp main ;loop to main
	
wait_for_button:
	sbic PINB, 0
	rjmp setup
	rjmp wait_release

;delay function
delay:
	clr overflows          ; set overflows to 0
delay_loop:
	cpi overflows, 38   	 ; how many ticks to wait? delay here until then
	brne delay_loop     	 ; loop here and keep checking ticks
	ret                 	 ; if the number of ticks is met, return to caller

;runs when the counter overflows
overflow_handler:
   inc overflows          ; add 1 to overflows register  (number of overflows)
   cpi overflows, 61      ; compare with 61 (overflows)
   brne overflow_return   ; if not 61 overflows, just return from the interrupt
   clr overflows          ; otherwise reset the counter to zero
overflow_return:
   reti                   ; return from interrupt

display:
	out PORTD, number ;Output the instuction from the number register to PORT D
	ret ;Return to the caller

wait_release:
	sbis PINB, 0
	rjmp wait_release
	out PORTD, number
	rcall delay
	rcall delay
	rjmp setup
