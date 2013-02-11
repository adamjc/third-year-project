;
; AdamOS
;

;TODO: Find way to use timer to call interrupts in software
;TODO: Add a round-robin scheduler
;TODO: Add dynamic memory
;TODO: Add dybamically added processes


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

	bl initializeLinkedList

	adrl r0, pcb1
	bl addNewProcess
	adrl r0, pcb2
	bl addNewProcess

	mrs r0, cpsr ; switch to user mode
	bic r0, r0, #&1f
	orr r0, r0, #&10
	msr cpsr_c, r0

	; set the current process ID to be 1 ***WILL CHANGE THIS TO BE DYNAMIC***
	ldr r0, =CURRENT_PROCESS_ID
	mov r1, #1
	str r1, [r0]

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
; Stores the first instruction of the new process to a new area in linked list.
;
; registers used:
;
; input:-
; r0: the PCB address of the new process
;
; general:-
; r1: the PID of the process
; r2: the address of BOTTOM_OF_QUEUE
; r3: the value stored at the pointer retrieved from BOTTOM_OF_QUEUE
;
; Cref: void addNewProcess(uint32 PID, uint32 PC)
;-------------------------------------------------------------------------------
addNewProcess

	; get the PID, update, and store it back.
	ldr r1, =PROCESS_ID_COUNTER
	ldr r2, [r1]
	add r2, r2, #1
	str r2, [r1]
	mov r1, r2 ;switch r2 into r1, to use r2 for something else.

	; get the address of the bottom of the queue
	ldr r2, =BOTTOM_OF_QUEUE
	ldr r3, [r2]

	sub r3, r3, #8 ; update the new bottom of the queue
	str r3, [r2]

	str r1, [r3], #4 ; store the PID at relative #0
	str r0, [r3] ; store the PCB address at relative #4
	
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