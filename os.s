;
; AdamOS
;
; TODO
; implement interrupts
; implement timer compare
; make the interrupt call the context switcher
; add button functionality to ADD an LED process
; add button functionality to REMOVE an LED process
; implement a physical memory manager (no address space unfortunately)

; Exception Vectors ------------------------------------------------------------
b	main					; reset
b	undef_inst				; undefined instruction
b	supervisor_call			; svc
b	prefetch_abort			; tried executing code from non-existing memory
b	data_abort				; data error (e.g. accessed out of bounds area)
nop
b	irq_routine				; interrupt request
b	fiq_routine				; fast interrupt request

main
	adrl sp, os_stack

	ldr r9, =TEMP_IRQ
	mov r8, #0
	str r8, [r9]

	bl disable_interrupts
	bl clear_interrupts

	; add leds to the array
	ldr r0, =LED_GET
	ldr r1, =led_get_space
	str r1, [r0]

	mov r0, #left_red
	str r0, [r1], #4
	mov r0, #right_red
	str r0, [r1], #4
	mov r0, #left_amber
	str r0, [r1], #4
	mov r0, #right_amber
	str r0, [r1], #4
	mov r0, #left_green
	str r0, [r1], #4
	mov r0, #right_green
	str r0, [r1], #4
	mov r0, #left_blue
	str r0, [r1], #4
	mov r0, #right_blue
	str r0, [r1], #4

	bl initialise_PCB

	adrl r0, led_flash
	bl get_top_led
	adrl r2, proc_1
	bl addNewProcess

	adrl r0, led_flash
	bl get_top_led
	adrl r2, proc_2
	bl addNewProcess

	adrl r0, led_flash
	bl get_top_led
	adrl r2, proc_3
	bl addNewProcess

	adrl r0, led_flash
	bl get_top_led
	adrl r2, proc_4
	bl addNewProcess

	bl enable_interrupts
	bl set_interrupts
	bl set_timer_compare

	; run the first process
	bl runActiveProcess

; runActiveProcess -------------------------------------------------------------
; runs whatever process is in the ACTIVE_PCB. If no process is in it, we take
; the first process off the ready queue.
;-------------------------------------------------------------------------------
runActiveProcess
	ldr r0, =ACTIVE_PCB
	ldr r1, [r0]
	cmp r1, #0 ; is there anything in the ACTIVE_PCB?

	push {lr}
	bleq updateActiveProcess ;nope
	pop {lr}

	; now there should be if there wasn't.
	ldr r14, =ACTIVE_PCB
	ldr r14, [r14]

	; update the SPSR
	ldr r1, [r14, #64] 
	msr spsr, r1 ; put pcb cpsr into spsr

	ldmia r14!, {r0-r12} ; move r0-r12 from the pcb into our registers

	ldmia r14!, {r13}^ 	; update the SP

	ldmia r14!, {r14}^ ; update the LR

	; then we want to 'return' to user mode
	ldr r14, =ACTIVE_PCB
	ldr r14, [r14]
	ldr r14, [r14, #60] ; load process's pc into r14
	sub lr, lr, #4
	movs pc, r14 ; return to user mode.

; storeActiveProcess -----------------------------------------------------------
; stores user registers to the active_pcb
;-------------------------------------------------------------------------------
storeActiveProcess
	push {lr} ; push the link

	ldr r14, =ACTIVE_PCB
	ldr r14, [r14]
	stmia r14!, {r0-r14}^ ; store user mode r0-r14

	mov r0, r14
	pop {lr} ; get the link, and user mode pc
	pop {r1}
	str r1, [r0] ; store user mode pc

	ldr r1, =ACTIVE_PCB
	ldr r1, [r1]
	add r1, r1, #64 ; get stored CPSR address
	mrs r0, spsr ; get SPSR
	str r0, [r1] ; store SPSR

	mov pc, lr 	; done

; addNewProcess ----------------------------------------------------------------
; registers used:
;
; input:-
; r0: the address of the program to run
; r1: any parameters to the program
; r2: the address of the processes stack
;
; general:-
;
; Cref: void addNewProcess(uint32 PC)
;-------------------------------------------------------------------------------
addNewProcess
	ldr r3, =FREE_PCB ;get a free PCB
	ldr r3, [r3] ;get a free PCB

	str r0, [r3, #60] ;update the pcb with the new processes PC location
	str r1, [r3] ; update the pcb with the input parameter (processes r0)
	str r2, [r3, #52] ; store the SP 

	mov r0, #&50 ;"make" a new CPSR
	str r0, [r3, #64] ;store it in the pcb's CPSR spot.

	mov r0, r3 ; r0 is now the ptr to the grabbed pcb
	;we want to move the PCB we have acquired into the READY queue
	push {lr}
	bl moveFreeToReadyQueue
	pop {lr}

	mov pc, lr

; undefinedInstruction ---------------------------------------------------------
;
; ------------------------------------------------------------------------------
undef_inst

; supervisor_call --------------------------------------------------------------
;
; ------------------------------------------------------------------------------
supervisor_call
	YIELD				EQU	&10
	GET_LEDS			EQU &20
	SET_LEDS			EQU &30
	UNSET_LEDS			EQU &40
	GET_TIME 			EQU &50
	UPPER_BOUNDS_SVC	EQU	&50

	push {lr} ;store user mode pc
	ldr r14, [lr, #-4] ; read off svc code
	bic r14, r14, #&FFFFFF00 ; mask off svc code

	cmp r14, #UPPER_BOUNDS_SVC
	bhi	unknown_svc ; process tried to access a function that doesn't exist

	cmp r14, #YIELD
	beq svc_context_switch

	cmp r14, #GET_LEDS
	beq svc_get_leds

	cmp r14, #SET_LEDS
	beq svc_set_leds

	cmp r14, #UNSET_LEDS
	beq svc_unset_leds

	cmp r14, #GET_TIME
	beq svc_get_time

; svc_get_time -----------------------------------------------------------------
; gets the current value of the timer
; output:
;	r0: the current value of the timer
; ------------------------------------------------------------------------------
svc_get_time
	pop {lr}
	ldr r0, =PORT_AREA
	ldr r0, [r0, #TIMER] ; get the timer value
	sub lr, lr, #4
	movs pc, lr

; get_time ---------------------------------------------------------------------
; gets the current value of the timer ** supervisor mode only **
; output:
;	r0: the current value of the timer
; ------------------------------------------------------------------------------
get_time
	ldr r0, =PORT_AREA
	ldr r0, [r0, #TIMER] ; get the timer value
	mov pc, lr

; svc_set_timer_compare --------------------------------------------------------
; sets the time to wait for until the timer compare interrupt is called.
; hard coded to 250ms right now ** supervisor mode only **
; ------------------------------------------------------------------------------
svc_set_timer_compare

; set_timer_compare ------------------------------------------------------------
; sets the time to wait for until the timer compare interrupt is called.
; hard coded to 250ms right now ** supervisor mode only **
; ------------------------------------------------------------------------------
set_timer_compare
	push {lr}
	bl get_time ; get the current counter time
	pop {lr}
	add r1, r0, #250 ; find the time 250ms from now
	and r1, r1, #&ff ; modulo 256 (only 256 states in this counter)
	ldr r2, =PORT_AREA
	str r1, [r2, #TIMER_COMPARE] ; update the timer compare
	mov pc, lr

; set_interrupts ---------------------------------------------------------------
; sets up the (active high) interrupts
; ------------------------------------------------------------------------------
set_interrupts
	mov r0, #&41 ;set upper_button and timer_compare
	ldr r1, =PORT_AREA
	str r0, [r1, #IRQ_EN]
	mov pc, lr

; disable_interrupts -----------------------------------------------------------
; disables interrupts, we use this during 'interrupt_routine' as to allow
; the current interrupt to finish before being interrupted. ARM is weird
; bit 7 set = interrupts off.
; ------------------------------------------------------------------------------
disable_interrupts
	push {r0}
	mrs r0, cpsr
	orr r0, r0, #&80
	msr cpsr_c, r0
	pop {r0}

	mov pc, lr

; enable_interrupts ------------------------------------------------------------
; enables interrupts, we use this to allow interrupts to be active after we have
; finished processing the current interrupt.
; ------------------------------------------------------------------------------
enable_interrupts
	mrs r0, cpsr
	bic r0, r0, #&80 ; clear bit 7 (interrupt enable)
	msr cpsr_c, r0
	mov pc, lr

; clear_interrupts -------------------------------------------------------------
;
; ------------------------------------------------------------------------------
clear_interrupts
	mov	r0, #&00
	ldr	r1, =PORT_AREA
	str	r0, [r1, #INTERRUPT]
	str r0, [r1, #IRQ_EN]

	mov pc, lr

; get_top_led ------------------------------------------------------------------
;
; ------------------------------------------------------------------------------
get_top_led
	push {r0}
	ldr r0, =LED_GET
	ldr r1, [r0]
	ldr r1, [r1]
	ldr r2, =LED_GET
	ldr r2, [r2]
	add r2, r2, #4
	str r2, [r0]
	pop {r0}

	mov pc, lr

; add_led_list -----------------------------------------------------------------
;
; ------------------------------------------------------------------------------
add_led_list


; unknown_svc ------------------------------------------------------------------
; user called a supervisor call that doesn't exist
; ------------------------------------------------------------------------------
unknown_svc
	b reset

; reset ------------------------------------------------------------------------
; the routine to reset the OS into a reasonable state
; ------------------------------------------------------------------------------
reset
	b reset

; prefetch_abort ---------------------------------------------------------------
;
; ------------------------------------------------------------------------------
prefetch_abort
	b reset

; data_abort -------------------------------------------------------------------
; the routine to handle data_aborts (trying to access areas that you shouldn't!)
; ------------------------------------------------------------------------------
data_abort
	b reset

; irq_routine ------------------------------------------------------------------
; the routine to handle interrupts
; ------------------------------------------------------------------------------
irq_routine
	adrl sp, irq_stack ; assign the irq's stack

	push {r0} 
	ldr r0, =PORT_AREA
	ldr r0, [r0, #INTERRUPT] ; get the interrupt bits
	bic r0, r0, #&FFFFFF00 ; mask off the interrupt bits
	and r0, r0, #UPPER_IRQ ; check if upper button was pressed
	cmp r0, #UPPER_IRQ
	pop {r0}
	beq upper_irq_routine

	push {r0}
	ldr r0, =PORT_AREA
	ldr r0, [r0, #INTERRUPT] ; get the interrupt bits
	bic r0, r0, #&FFFFFF00 ; mask off the interrupt bits
	and r0, r0, #LOWER_IRQ ; check if upper button was pressed
	cmp r0, #LOWER_IRQ
	pop {r0}
	beq lower_irq_routine

	b timer_routine

	; then run the upper_button routine (which is to add a process)
	upper_irq_routine
		; if it was, debounce the input (i.e. wait a while!)
		; have to debounce the interrupt before we move out of here,
		; make sure upper_button has been left "up"
		push {r0}
		mov r0, #&8000
		u_i_loop ;urgh, so ugly...!			
			sub r0, r0, #1
			cmp r0, #0
			bne u_i_loop
		pop {r0}

		sub lr, lr, #4 ;debug
		push {lr}
		adrl r0, led_flash
		bl get_top_led
		adrl r2, proc_5
		bl addNewProcess
		movs pc, lr

	; then run the lower_button routine (which is to remove a process)
	lower_irq_routine
		; if it was, debounce the input (i.e. wait a while!)
		; have to debounce the interrupt before we move out of here,
		; make sure lower_button has been left "up"		
		push {r0}
		mov r0, #&8000
		l_i_loop ;urgh, so ugly...!			
			sub r0, r0, #1
			cmp r0, #0
			bne l_i_loop
		pop {r0}

		; remove the bottom process
		push {lr}
		bl moveReadyToFreeQueue
		pop {lr}

		sub lr, lr, #4 ;debug
		movs pc, lr		

	timer_routine
		ldr r8, =TEMP_IRQ ; r8 is used to store a counter
		ldr r8, [r8] ; r8 is used to store a counter
		cmp r8, #4 ; if the counter is #4 (i.e. 4*250ms or 1s has passed)

		beq irq_context_switch ; context_switch out the running process

		push {lr} ; store user mode's pc

		add r8, r8, #1
		ldr r9, =TEMP_IRQ
		str r8, [r9]
		bl clear_interrupts
		bl set_timer_compare
		bl set_interrupts
		pop {lr}
		sub lr, lr, #4 ;debug
		movs pc, lr

		irq_context_switch
			mov r8, #0
			ldr r9, =TEMP_IRQ
			str r8, [r9]
			push {lr} ; store user mode pc
			bl disable_interrupts
			bl clear_interrupts

			; make sure that the registers are what we are expecting them to be
			; rewrite the context switcher to handle interrupts
			b svc_context_switch

; fiq_routine ------------------------------------------------------------------
; the routine to handle fast interrupts
; ------------------------------------------------------------------------------
fiq_routine
	b reset	

	defs 32
os_stack
	
	defs 32
irq_stack

	defs 96
proc_1
	defs 96
proc_2
	defs 96
proc_3
	defs 96
proc_4
	defs 96
proc_5
	defs 96
proc_6
	defs 96
proc_7
	defs 96
proc_8

include context_switcher.s
include pcb.s
include led.s
include ports.s

led_get_space
	defs 80
