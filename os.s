;
; AdamOS
;

;TODO: Find way to use timer to call interrupts in software
;TODO: Add a round-robin scheduler
;TODO: Add dynamic memory
;TODO: Add dynamically added processes


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

	adrl r0, main_add
	bl addNewProcess
	adrl r0, main_sub
	bl addNewProcess

	mrs r0, cpsr ; switch to user mode
	bic r0, r0, #&1f
	orr r0, r0, #&10
	msr cpsr_c, r0

	b main_add

; main_add ---------------------------------------------------------------------
; testing the context switcher
;-------------------------------------------------------------------------------
main_add
	adrl sp, add_stack
	mov r0, #0
	addloop
		add r0, r0, #1
		bl contextSwitch
		b addloop

; main_sub ---------------------------------------------------------------------
; testing the context switcher
;-------------------------------------------------------------------------------
main_sub
	adrl sp, sub_stack
	mov r0, #255
	subloop
		sub r0, r0, #1
		bl contextSwitch
		b subloop

; addNewProcess ----------------------------------------------------------------
; registers used:
;
; input:-
; r0: the address of the program to run
;
; general:-
;
; Cref: void addNewProcess(uint32 PC)
;-------------------------------------------------------------------------------
addNewProcess
	ldr r1, =FREE_PCB ;get a free PCB
	ldr r1, [r1] ;get a free PCB

	str r0, [r1, #60] ;update the pcb with the new processes PC location

	mov r0, r1 ; r0 is now the ptr to the grabbed pcb
	;we want to move the PCB we have acquired into the READY queue
	push {lr}
	bl moveToReadyQueue
	pop {lr}

	mov pc, lr

; moveToReadyQueue -------------------------------------------------------------
; movees r0 (the processes PCB address) out of the FREE_PCB queue and into the
; ready queue, waiting for execution.
;
; input
;	r0: the processes PCB address
;-------------------------------------------------------------------------------
moveToReadyQueue
	;we are always grabbing from the top of the FREE queue (eg. FREE_PTR)

	;want to look at ready queue FIRST to see if there are any processes currently in it.
	ldr r1, =READY_PCB
	ldr r2, [r1] 
	cmp r2, #0
	bne movToRdyTail ; the READY_PCB is not empty

	str r0, [r1] ;move the grabbed pcb to READY_PCB

	; now we want to update FREE_PTR
	add r0, r0, #68 
	ldr r2, [r0] ; get the pointer address of the grabbed pcb (eg. the next free pcb)
	ldr r1, =FREE_PCB
	str r2, [r1] ;update the FREE_PTR

	; now we want to update the pointer of the grabbed pcb to null
	mov r1, #0 ;null pointer
	str r1, [r0] ;put null pointer in the ptr_address of the grabbed pcb

	; need to update READY_PCB_TAIL to be grabbed pcb's ptr address
	ldr r1, =READY_PCB_TAIL
	str r0, [r1] ; put the grabbed pcb's ptr to the next pcb in READY_PCB_TAIL

	mov pc, lr ; grabbed pcb is now at top of READY_PCB

	movToRdyTail
		;the READY_PCB is not empty, we want to add this pcb ptr to the end then
		ldr r1, =READY_PCB_TAIL ;points to the last pcb's ptr
		ldr r1, [r1] ;we now have the address of the last pcb's ptr
		str r2, [r1] ;the grabbed pcb is now the last pcb

		;therefore, make the grabbed pcb's ptr null
		add r0, r0, #68 ;get the pointer address of the grabbed pcb
		mov r1, #0
		str r1, [r0] ; make the pointer address null

	mov pc, lr ;grabbed ocb is now at tail of READY_PCB







; undefinedInstruction -
;
;- 
undefinedInstruction

; superVisorCall -
;
;-
supervisorCall

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
add_stack
	defs 96
sub_stack

include context_switcher.s
include pcb.s