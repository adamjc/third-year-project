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

; main -------------------------------------------------------------------------
;
;-------------------------------------------------------------------------------
main
	adrl sp, os_stack

	bl initialise_PCB

	adrl r0, led_flash
	mov r1, #left_red
	adrl r2, proc_1
	bl addNewProcess

	adrl r0, led_flash
	mov r1, #right_red
	adrl r2, proc_2
	bl addNewProcess

	adrl r0, led_flash
	mov r1, #left_blue
	adrl r2, proc_3
	bl addNewProcess

	adrl r0, led_flash
	mov r1, #right_amber
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

	; move r0-r12 from the pcb into our registers
	ldmia r14!, {r0-r12}

	; update the SP
	ldmia r14!, {r13}^

	; update the LR
	ldmia r14!, {r14}^

	; then we want to 'return' to user mode
	ldr r14, =ACTIVE_PCB
	ldr r14, [r14]
	ldr r14, [r14, #60] ; load process's pc into r14
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
	ldr r0, =port_area
	ldr r0, [r0, #TIMER] ; get the timer value
	movs pc, lr

; get_time ---------------------------------------------------------------------
; gets the current value of the timer ** supervisor mode only **
; output:
;	r0: the current value of the timer
; ------------------------------------------------------------------------------
get_time
	ldr r0, =port_area
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
	ldr r2, =port_area
	str r1, [r2, #TIMER_COMPARE] ; update the timer compare
	mov pc, lr

; set_interrupts ---------------------------------------------------------------
; sets up the (active high) interrupts
; ------------------------------------------------------------------------------
set_interrupts
	mov r0, #&01
	ldr r1, =port_area
	add r1, r1, #IRQ_EN
	str r0, [r1]
	mov pc, lr

; disable_interrupts -----------------------------------------------------------
; disables interrupts, we use this during 'interrupt_routine' as to allow
; the current interrupt to finish before being interrupted.
; ------------------------------------------------------------------------------
disable_interrupts
	mrs r0, cpsr
	orr r0, r0, #&80
	msr cpsr_c, r0
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

; unknown_svc ------------------------------------------------------------------
;
; ------------------------------------------------------------------------------
unknown_svc
	b reset

; reset ------------------------------------------------------------------------
;
; ------------------------------------------------------------------------------
reset
	b reset

; prefetch_abort ----------------------------------------------------------------
;
; ------------------------------------------------------------------------------
prefetch_abort
	b reset

; data_abort --------------------------------------------------------------------
;
; ------------------------------------------------------------------------------
data_abort
	b reset

; irq_routine ------------------------------------------------------------------
;
; ------------------------------------------------------------------------------
irq_routine
	; TODO
	bl disable_interrupts

; fiq_routine ------------------------------------------------------------------
;
; ------------------------------------------------------------------------------
fiq_routine
	b reset	

	defs 96
os_stack

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
