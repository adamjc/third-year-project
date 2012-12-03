;Scheduler pseudo-ish-code

; we either do this, or have some sort of temporary stack?
TEMP_IRQ_LR EQU &9D4
TEMP_R0 EQU &9D8
TEMP_R1 EQU &9DC
TEMP_IRQ_CPSR EQU &9E0
TEMP_SYSTEM_CPSR EQU &9E4

CURRENT_PROCESS_ID EQU &9E8
TOP_OF_QUEUE EQU &9EC
BOTTOM_OF_QUEUE EQU &AF0

; IRQ Timer == 0 -> contextSwitch
contextSwitch
	
	; Store all of the current process's registers to it's stack
	; Store the SPSR_IRQ (which is the CPSR of usrmode) to the user stack
	; We need to store this information to the SYSTEM stack, not the IRQ stack
	; Assume we have a location in mem that holds the current PID stack addr

	adrl sp, temp_stack

	; store r0 temporarily
	push {r1}
	push {r0}
	ldr r0, =TEMP_R0
	pop {r1}
	str r1, [r0]

	; store r1 temporarily
	ldr r0, =TEMP_R1
	pop {r1}
	str r1, [r0]

	mrs r0, spsr
	ldr r1, =TEMP_SYSTEM_CPSR
	str r0, [r1]
	
	ldr r0, =TEMP_IRQ_LR
	str lr, [r1]
	
	mrs r0, cpsr
	ldr r1, =TEMP_IRQ_CPSR
	str r0, [r1]

	orr r0, r0, #0x1F ; system mode, disable irq; fiq; thumb
	msr cpsr_c, r0 ; actually change to system mode

	; Now in System Mode
	ldr r0, =TEMP_SYSTEM_CPSR
	ldr r1, [r0]
	push {r1}
	ldr r0, =TEMP_R0 ; restore r0.
	ldr r0, [r0]
	ldr r1, =TEMP_R1 ; restore r1
	ldr r1, [r1] 
	push {r0-r12, lr}
	ldr r0, =TEMP_IRQ_LR ; this is the PC of the User Mode process
	ldr r1, [r0]
	push {r1}
	bl storeSP ; Store the current process's SP.

	; Now get the next process to be run
	bl getNextPID
	bl getPID_SP_Addr
	mov sp, r0
	pop {r0} ; pop off the CPSR of the process (i.e. get the status bits)
	msr cpsr_c, r0 ; switch to User Mode
	pop {r0-r12, lr} 
	pop {pc} ; state of process should now be as we left it.

	; Need to re-enable IRQs & FIQs here.

	; Return to process
	mov pc, lr ; probably the incorrect way to do this

; stores the SP to the current_PID's area in linked-list index
storeSP
	ldr r0, =TOP_OF_QUEUE
	ldr r0, [r0]
	str sp, [r0, #4]
	mov pc, lr

; returns (in r0) the address of where the SP-value is stored
getPID_SP_Addr
	; r0 contains the PID to search for
	ldr r1, =BOTTOM_OF_QUEUE ; load in the PID of the bottom process
	ldr r1, [r1]
	ldr r1, [r1]
	teq r0, r1 ; is this the PID we are looking for?
	beq pid_found
	loop
	; is a fixed-memory linked list, #0 is PID, #4 is SP, #8 is next PID, etc.
		ldr r1, [r1, #8] 
		teq r0, r1
		bne loop
	; need to put some error-handling in here (e.g. if r0 contains PID that
	;does not exist).
	pid_found
		ldr r0, [r1]
		mov pc, lr

; gets the top PID of the queue, and moves it to the bottom. also, stores the
; PID to [CURRENT_PROCESS_ID]
getNextPID
	;TODO


	defs 100
temp_stack	
