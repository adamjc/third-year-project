; ports.s ----------------------------------------------------------------------
; List of important port areas on the manchester arm board and their aliases
; ------------------------------------------------------------------------------
PORT_AREA		EQU	&10000000 ; the start of the port area
TIMER			EQU	&08
TIMER_COMPARE	EQU &0C
INTERRUPT		EQU	&18
IRQ_EN			EQU &1C
UPPER_IRQ		EQU	&40
LOWER_IRQ		EQU &80

BUTTONS			EQU &10000018

left_red		EQU	&04 ; left red led
right_red		EQU &40 ; right red led
left_amber		EQU &02 ; left amber led
right_amber		EQU &20 ; right amber led
left_green		EQU &01 ; left green led
right_green 	EQU &10 ; right green led
left_blue		EQU	&08 ; left blue led 
right_blue		EQU &80 ; right blue led