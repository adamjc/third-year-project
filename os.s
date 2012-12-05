;
; AdamOS
;

; Exception Vectors ------------------------------------------------------------
b	main					; reset
b	undefinedInstruction	; undefined instruction
b	supervisorCall			; svc
b	prefetchAbort			; tried to execute code from non-existing memory regions
b	dataAbort				; data error (e.g. accessed out of bounds area)
nop
b	irqRoutine				; interrupt request
b	fiqRoutine				; fast interrupt request

; main -
;
;-
main
	adrl sp, os_stack

	bl initializeLinkedList

	adrl r0, pcb1
	bl addNewProcess
	adrl r0, pcb2
	bl addNewProcess

	; switch to user mode
	mrs r0, cpsr
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