FREE_PCB	EQU		&9E8
ACTIVE_PCB	EQU		&9EC
READY_PCB	EQU		&9F0
READY_PCB_TAIL	EQU	&9F4

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

	; this is one of the first things the kernel does, so no active processes
	ldr r1, =ACTIVE_PCB
	mov r0, #0
	str r0, [r1] ;make ACTIVE_PCB null

	; this is one of the first things the kernel does, so no ready processes
	ldr r1, =READY_PCB
	str r0, [r1] ;make READY_PCB null

	; the tail of the READY_PCB is obviously also null
	ldr r1, =READY_PCB_TAIL
	str r0, [r1] ;make READY_PCB_TAIL null

	mov pc, lr

pcb_start
	defs 76
	defs 76
