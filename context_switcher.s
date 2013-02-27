; context_switcher -------------------------------------------------------------
;
;
;-------------------------------------------------------------------------------

TEMP_IRQ_LR EQU &9D4
TEMP_R0 EQU &9D8
TEMP_R1 EQU &9DC
TEMP_IRQ_CPSR EQU &9E0
TEMP_SYSTEM_CPSR EQU &9E4

; contextSwitch ----------------------------------------------------------------
; Saves the state of the currently running process, including it's registers
; r0-12, SP, LR & PC. Then loads up the state of the next process to be run,
; and continues from where the process just switched into left off.
;-------------------------------------------------------------------------------
contextSwitch
	; TODO
	; TEST
	
	bl storeActiveProcess
	bl moveActiveToReadyQueue
	bl updateActiveProcess
	bl runActiveProcess

	; done

	adrl sp, temp_stack

	push {r1} ; store r0 temporarily
	push {r0}
	ldr r0, =TEMP_R0
	pop {r1}
	str r1, [r0]

	ldr r0, =TEMP_R1 ; store r1 temporarily
	pop {r1}
	str r1, [r0]

	; store the SPSR of the IRQ (this is the CPSR of User Mode / System Mode)
	mrs r0, spsr
	ldr r1, =TEMP_SYSTEM_CPSR
	str r0, [r1]
	
	; store the LR of the IRQ (this is the PC of User Mode / System Mode)
	ldr r0, =TEMP_IRQ_LR
	str lr, [r1]
	
	mrs r0, cpsr ; store the IRQ CPSR
	ldr r1, =TEMP_IRQ_CPSR
	str r0, [r1]

	orr r0, r0, #0x1F ; system mode, disable irq; fiq; thumb
	msr cpsr_c, r0 ; actually change to system mode

	bl storeToPCB ;store to PCB

	; Now get the next process to be run
	mov sp, r0
	
	msr cpsr_c, r0 ; switch to User Mode

	; Need to re-enable IRQs & FIQs here.

	; Return to process
	mov pc, lr ; probably the incorrect way to do this

storeToPCB
	str r1, [r0], #4 ; store the PID

	ldr r1, =TEMP_R0 ;get r0
	ldr r1, [r1] ;get r0
	str r1, [r0], #4 ;store r1

	ldr r1, =TEMP_R1 ;get r1
	ldr r1, [r1] ; get r1
	str r1, [r0], #4 ;store r1

	; replace this with stmia, also ^ it.
	str r2, [r0], #4
	str r3, [r0], #4
	str r4, [r0], #4
	str r5, [r0], #4
	str r6, [r0], #4
	str r7, [r0], #4
	str r8, [r0], #4
	str r9, [r0], #4
	str r10, [r0], #4
	str r11, [r0], #4
	str r12, [r0], #4
	str sp, [r0], #4
	str lr, [r0], #4 ;******THIS MIGHT BE A PROBLEM****** (not user's lr?)
	str pc, [r0], #4

	ldr r1, =TEMP_SYSTEM_CPSR ;get the user mode CPSR
	ldr r1, [r1] ;get the user mode CPSR
	str r1, [r0] ; store the user mode CPSR

	mov pc, lr


	defs 96
temp_stack	

