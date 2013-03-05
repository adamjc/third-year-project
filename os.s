;
; AdamOS
;

; Exception Vectors ------------------------------------------------------------
b	main					; reset
b	undefinedInstruction	; undefined instruction
b	supervisorCall			; svc
b	prefetchAbort			; tried executing code from non-existing memory
b	dataAbort				; data error (e.g. accessed out of bounds area)
nop
b	irqRoutine				; interrupt request
b	fiqRoutine				; fast interrupt request

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
	; TEST

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

; main_add ---------------------------------------------------------------------
; testing the context switcher
;-------------------------------------------------------------------------------
main_add
	adrl sp, add_stack
	mov r1, #0
	addloop
		add r1, r1, #1
		mov r0, #1 ; 1 is the opcode for contextswitch
		svc YIELD
		b addloop

; main_sub ---------------------------------------------------------------------
; testing the context switcher
;-------------------------------------------------------------------------------
main_sub
	adrl sp, sub_stack
	mov r1, #255
	subloop
		sub r1, r1, #1
		svc YIELD
		b subloop

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

; undefinedInstruction -
;
;- 
undefinedInstruction

; superVisorCall -
;
;-
supervisorCall
	YIELD				EQU	&10
	UPPER_BOUNDS_SVC	EQU	&20

	push {lr} ;store user mode pc
	ldr r14, [lr, #-4] ; read off svc code
	bic r14, r14, #&FFFFFF00 ; mask off svc code

	cmp r14, #UPPER_BOUNDS_SVC
	bhi	unknown_svc ; process tried to access a function that doesn't exist

	cmp r14, #YIELD
	beq svc_context_switch

; unknown_svc ------------------------------------------------------------------
;
;-------------------------------------------------------------------------------
unknown_svc
	; TODO
	b reset

; reset ------------------------------------------------------------------------
;
;-------------------------------------------------------------------------------
reset
	; TODO
	b reset

; prefetchAbort -
;
;-
prefetchAbort

;- dataAbort
;
;-
dataAbort

;- irqRoutine -
;
;-
irqRoutine

;- fiqRoutine
;
;-
fiqRoutine

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
