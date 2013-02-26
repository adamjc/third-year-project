FREE_PCB	EQU		&9E8
ACTIVE_PCB	EQU		&9EC
READY_PCB	EQU		&9F0
READY_PCB_TAIL	EQU		&9F4

; PCB --------------------------------------------------------------------------
; Process Control Block
;
; Each process requires 72 bytes of storages (18 32-bit values)
;
; Outline of values in each process block:
; #0-#48 stores r0-r12
; #52    stores the SP (r13)
; #56    stores the LR (r14)
; #60    stores the PC (r15)
; #64    stores the CPSR
; #68	 stores the pointer to the next pcb
;-------------------------------------------------------------------------------

initialise_PCB	
	; update FREE_PCB with the address of pcb_start
	adrl r0, pcb_start
	ldr r1, =FREE_PCB
	str r0, [r1]

	add r0, r0, #68 ;move to the ptr section of the first pcb
	add r1, r0, #4 ;create the ptr address
	str r1, [r0] ;store the ptr address in the ptr section of the pcb

	add r0, r0, #72 ;move to the ptr section of the next pcb
	mov r1, #0 ;null pointer
	str r1, [r0] ;store null pointer in the pcb address

	; this is one of the first things the kernel does, no active processes
	ldr r1, =ACTIVE_PCB
	mov r0, #0
	str r0, [r1] ;make ACTIVE_PCB null

	; this is one of the first things the kernel does, no ready processes
	ldr r1, =READY_PCB
	str r0, [r1] ;make READY_PCB null

	; the tail of the READY_PCB is obviously also null
	ldr r1, =READY_PCB_TAIL
	str r0, [r1] ;make READY_PCB_TAIL null

	mov pc, lr

; moveFreeToReadyQueue ---------------------------------------------------------
; movees r0 (the processes PCB address) out of the FREE_PCB queue and into the
; ready queue, waiting for execution.
;
; input
;	r0: the processes PCB address
;-------------------------------------------------------------------------------
moveFreeToReadyQueue
	;we are always grabbing from the top of the FREE queue (eg. FREE_PTR)

	;look at ready queue FIRST, see if there are any pcbs currently in it.
	ldr r1, =READY_PCB
	ldr r2, [r1] 
	cmp r2, #0
	bne movFreeToRdyTail ; the READY_PCB is not empty

	str r0, [r1] ;move the grabbed pcb to READY_PCB

	; now we want to update FREE_PTR
	add r0, r0, #68 
	ldr r2, [r0] ; get ptr address of the grabbed pcb (the next free pcb)
	ldr r1, =FREE_PCB
	str r2, [r1] ; update the FREE_PTR

	; now we want to update the pointer of the grabbed pcb to null
	mov r1, #0 ; null pointer
	str r1, [r0] ; put null pointer in the ptr_address of the grabbed pcb

	; need to update READY_PCB_TAIL to be grabbed pcb's ptr address
	ldr r1, =READY_PCB_TAIL
	str r0, [r1] ; put grabbed pcb's ptr to the next pcb in READY_PCB_TAIL

	mov pc, lr ; grabbed pcb is now at top of READY_PCB

	movFreeToRdyTail
		; READY_PCB is not empty, we add this pcb ptr to the end then
		ldr r1, =READY_PCB_TAIL ;points to the last pcb's ptr
		ldr r1, [r1] ;we now have the address of the last pcb's ptr
		str r2, [r1] ;the grabbed pcb is now the last pcb

		;therefore, make the grabbed pcb's ptr null
		add r0, r0, #68 ;get the pointer address of the grabbed pcb
		mov r1, #0
		str r1, [r0] ; make the pointer address null

	mov pc, lr ;grabbed ocb is now at tail of READY_PCB

; getNextProcess ---------------------------------------------------------------
; moves the top pcb in the READY queue to the active queue
;-------------------------------------------------------------------------------
getNextProcess

; moveActiveToReadyQueue -------------------------------------------------------
; moves the pcb from the active queue to the ready queue
; input
; 	void
; output
; 	r0: #0 if it failed (nothing in the ready queue), #1 if successful
;-------------------------------------------------------------------------------
moveActiveToReadyQueue
	; look at ready queue FIRST, see if there are any procs currently in it
	ldr r0, =ACTIVE_PCB
	ldr r1, =READY_PCB
	ldr r2, [r1] 
	cmp r2, #0
	bne movActvToRdyTail ; the READY_PCB is not empty

	mov r0, #0
	mov pc, lr ; the READY_PCB is empty - this is the only proc running

	movActvToRdyTail
		;the READY_PCB is not empty, add pcb addr to end of the queue
		ldr r0, =READY_PCB_TAIL ;points to the last pcb's ptr
		ldr r0, [r0] ; we now have the address of the last pcb's ptr

	; TODO







pcb_start
	defs 76
	defs 76
