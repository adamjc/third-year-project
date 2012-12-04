; context_switcher -------------------------------------------------------------
;
;-------------------------------------------------------------------------------

TEMP_IRQ_LR EQU &9D4
TEMP_R0 EQU &9D8
TEMP_R1 EQU &9DC
TEMP_IRQ_CPSR EQU &9E0
TEMP_SYSTEM_CPSR EQU &9E4

CURRENT_PROCESS_ID EQU &9E8
TOP_OF_QUEUE EQU &9EC
BOTTOM_OF_QUEUE EQU &AF0

; contextSwitch ----------------------------------------------------------------
; Saves the state of the currently running process, including it's registers
; r0-12, SP, LR & PC. Then loads up the state of the next process to be run,
; and continues from where the process just switched into left off.
;-------------------------------------------------------------------------------
contextSwitch
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

	; store the SPSR of the IRQ (this is the CPSR of User Mode / System Mode)
	mrs r0, spsr
	ldr r1, =TEMP_SYSTEM_CPSR
	str r0, [r1]
	
	; store the LR of the IRQ (this is the PC of User Mode / System Mode)
	ldr r0, =TEMP_IRQ_LR
	str lr, [r1]
	
	; store the IRQ CPSR
	mrs r0, cpsr
	ldr r1, =TEMP_IRQ_CPSR
	str r0, [r1]

	orr r0, r0, #0x1F ; system mode, disable irq; fiq; thumb
	msr cpsr_c, r0 ; actually change to system mode

	; Now should be in System Mode

	; push the System CPSR
	ldr r0, =TEMP_SYSTEM_CPSR
	ldr r1, [r0]
	push {r1}

	ldr r0, =TEMP_R0 ; restore r0.
	ldr r0, [r0]
	ldr r1, =TEMP_R1 ; restore r1
	ldr r1, [r1] 

	; push the all registers of process we are switching out of
	push {r0-r12, lr}

	; push the PC of the process we are switching out of
	ldr r0, =TEMP_IRQ_LR ; this is the PC of the System / User Mode process
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

; storeSP ----------------------------------------------------------------------
; stores the SP to the current_PID's area in linked-list index
;-------------------------------------------------------------------------------
storeSP
	ldr r0, =TOP_OF_QUEUE
	ldr r0, [r0]
	str sp, [r0, #4]
	mov pc, lr

; getPID_SP_Addr ---------------------------------------------------------------
; returns (in r0) the address of where the SP-value is stored
;-------------------------------------------------------------------------------
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
	; does not exist).
	pid_found
		ldr r0, [r1]
		mov pc, lr

; getNextPID -------------------------------------------------------------------
; gets the top PID of the queue, and moves it to the bottom. also, stores the
; PID to [CURRENT_PROCESS_ID]
;-------------------------------------------------------------------------------
getNextPID
	;TODO

; addNewProcess ----------------------------------------------------------------
; Stores the first instruction of the new process to a new area in linked list
; input:-
; r0: the PID (process ID) of the new process
; r1: the PC of the new process
; Cref: void addNewProcess(uint32 PID, uint32 PC)
;-------------------------------------------------------------------------------
addNewProcess
	


	defs 100
temp_stack	
