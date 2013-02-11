; context_switcher -------------------------------------------------------------
;
;
;-------------------------------------------------------------------------------

;TODO: test getNextPID
;TODO: line 118; ;need to fix this in the case where PID not found

TEMP_IRQ_LR EQU &9D4
TEMP_R0 EQU &9D8
TEMP_R1 EQU &9DC
TEMP_IRQ_CPSR EQU &9E0
TEMP_SYSTEM_CPSR EQU &9E4

CURRENT_PROCESS_ID EQU &9E8
TOP_OF_QUEUE EQU &9EC
BOTTOM_OF_QUEUE EQU &AF0

PCB_PTR EQU &AF4
PROCESS_ID_COUNTER EQU &AF8

; contextSwitch ----------------------------------------------------------------
; Saves the state of the currently running process, including it's registers
; r0-12, SP, LR & PC. Then loads up the state of the next process to be run,
; and continues from where the process just switched into left off.
;-------------------------------------------------------------------------------
contextSwitch
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

	; Now should be in System Mode

	ldr r0, =CURRENT_PROCESS_ID ; get the current PID
	ldr r0, [r0]

	bl findPCBAddress ; find the process's pcb address

	bl storeToPCB ;store to PCB

	;ldr r1, =PCB_PTR

	; push the System CPSR
	;ldr r0, =TEMP_SYSTEM_CPSR
	;ldr r1, [r0]
	;push {r1}

	;ldr r0, =TEMP_R0 ; restore r0.
	;ldr r0, [r0]
	;ldr r1, =TEMP_R1 ; restore r1
	;ldr r1, [r1] 

	;push {r0-r12, lr} ; push the all registers of process we are switching out

	; push the PC of the process we are switching out of
	;ldr r0, =TEMP_IRQ_LR ; this is the PC of the System / User Mode process
	;ldr r1, [r0]
	;push {r1}
	;bl storeSP ; Store the current process's SP.

	; Now get the next process to be run
	bl getNextPID
	bl getPID_SP_Addr
	mov sp, r0
	
	;pop {r0} ; pop off the CPSR of the process (i.e. get the status bits)
	
	msr cpsr_c, r0 ; switch to User Mode
	
	;pop {r0-r12, lr} 

	;pop {pc} ; state of process should now be as we left it.

	; Need to re-enable IRQs & FIQs here.

	; Return to process
	mov pc, lr ; probably the incorrect way to do this

storeToPCB
	ldr r1, =CURRENT_PROCESS_ID ; get the current PID
	ldr r1, [r1]

	str r1, [r0], #4 ; store the PID

	ldr r1, =TEMP_R0 ;get r0
	ldr r1, [r1] ;get r0
	str r1, [r0], #4 ;store r1

	ldr r1, =TEMP_R1 ;get r1
	ldr r1, [r1] ; get r1
	str r1, [r0], #4 ;store r1

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

; findPCBAddress ---------------------------------------------------------------
; Returns the pcb address of the PID specified.
;
; Registers Used:
; Parameters:-
; r0: Current process ID
; Return:-
; r0: PCB Address of the current process ID
; General:-
; r1: Used to index the linked list
; r2: Used to store the PID of where r1 indexes
;-------------------------------------------------------------------------------
findPCBAddress
	push {r2}
	ldr r1, =BOTTOM_OF_QUEUE
	ldr r1, [r1]
	;need to fix this in the case where PID not found
	findPCBLoop ;loop until r2=r1. 
		ldr r2, [r1], #8
		cmp r2, r0
		bne findPCBLoop

	ldr r0, [r1, #-4] ;load the PCB address into r0
	pop {r2}
	mov pc, lr

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
; TODO redo this to use the PCB instead of the stack.
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
getNextPID ;getNextPID
	ldr r2, =TOP_OF_QUEUE
	ldr r0, [r2]
	ldr r0, [r2, #-8] ;get the top PID of the queue
	ldr r1, [r2, #-4] ;get the top PCB-Address of the queue
	push {r0, r1}
	sub r2, r2, #12
	mov r1, r2
	add r1, r1, #8

	PIDLoop
		ldr r3, =BOTTOM_OF_QUEUE ; check for bottom of queue
		ldr r3, [r3]
		ldr r3, [r3] ;get PID
		cmp r3, r2
		beq endOfQueue
		ldr r0, [r2], #-4 
		str r0, [r1], #-4 ;move PID down
		ldr r0, [r2], #-4
		str r0, [r1], #-4 ;move PCB-address down
		b PIDLoop

	endOfQueue ;reached the end of the queue.
		ldr r0, [r2], #-4
		str r0, [r1], #-4 ;move PID down
		ldr r0, [r2], #-4
		str r0, [r1], #-4 ;move PCB-address
		pop {r0}
		str r0, [r1], #-4 ;store PID down
		pop {r0}
		str r0, [r1] ;store PCB-address

	;TODO store the PID to [CURRENT_PROCESS_ID]
	;TODO TEST THIS.

	

; initalizeLinkedList ----------------------------------------------------------
; Sets the top and the bottom of the linked list queue to be at the address
; defined by the hardcoded value in os.s. I.e. sets the size of the list to 
; be 0.
;
; input:-  void
; output:- void
; creference:- void initializeLinkedList()
;-------------------------------------------------------------------------------
initializeLinkedList
	ldr r0, =TOP_OF_QUEUE
	adrl r1, ll_space
	str r1, [r0]
	ldr r0, =BOTTOM_OF_QUEUE
	str r1, [r0]

	mov pc, lr

; updatePCB_PTR ----------------------------------------------------------------
; Places the address of the PCB into PCB_PTR.
;-------------------------------------------------------------------------------
updatePCB_PTR
	ldr r0, =PCB_PTR
	adrl r1, PCB
	str r1, [r0]
	mov pc, lr

; PCB --------------------------------------------------------------------------
; Process Control Block
;
; Each process requires 72 bytes of storages (18 32-bit values)
;
; Outline of values in each process block:
; #0     stores the PID
; #4-#52 stores r0-r12
; #56    stores the SP (r13)
; #60    stores the LR (r14)
; #64    stores the PC (r15)
; #68    stores the CPSR
;-------------------------------------------------------------------------------
PCB
	pcb1
	defs 72
	pcb2
	defs 72

ll_space
	defs 16

	defs 96
temp_stack	

