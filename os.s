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

	adrl r0, main_add
	bl addNewProcess
	adrl r0, main_sub
	bl addNewProcess

	; run the first process
	bl runActiveProcess

; runActiveProcess -------------------------------------------------------------
; runs whatever process is in the ACTIVE_PCB. If no process is in it, we take
; the first process off the ready queue.
;-------------------------------------------------------------------------------
runActiveProcess
	; TEST

	ldr r0, =ACTIVE_PCB
	ldr r1, [r0]
	cmp r1, #0 ; is there anything in the ACTIVE_PCB?

	push {lr}
	bleq updateActiveProcess ;nope
	pop {lr}

	; now there should be if there wasn't.
	ldr r13, =ACTIVE_PCB
	ldr r13, [r13]

	; update the SPSR
	ldr r0, =ACTIVE_PCB
	ldr r1, [r0, #64]
	msr spsr, r1 ; put pcb cpsr into spsr

	; move r0-r12 from the pcb into our registers
	ldmia r13!, {r0-r12}

	; update the SP
	ldr r14, r13
	ldmia r14!, {r13}^

	; update the LR
	ldmia r14!, {r14}^

	; then we want to 'return' to user mode
	ldr r14, [r0, #60] ; load process's pc into r14
	movs pc, r14 ; return to user mode.

; storeActiveProcess -----------------------------------------------------------
; stores user registers to the active_pcb
;-------------------------------------------------------------------------------
storeActiveProcess
	; TODO
	; TEST

	; store r0-r14
	ldr r13, =ACTIVE_PCB
	stmia r13!, {r0-r14}^

	; need to store user's pc (r14 of supervisor mode) [not yet though]
	str r14, [r13], #4

	; need to store SPSR
	mrs r0, spsr
	str r0, [r13]

	; done
	mov pc, lr

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

	mov r0, #&50 ;"make" a new CPSR
	str r0, [r1, #64] ;store it in the pcb's CPSR spot.

	mov r0, r1 ; r0 is now the ptr to the grabbed pcb
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
