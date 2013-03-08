; svc_context_switch ----------------------------------------------------------------
; Saves the state of the currently running process, including it's registers
; r0-12, SP, LR & PC. Then loads up the state of the next process to be run,
; and continues from where the process just switched into left off.
;-------------------------------------------------------------------------------
svc_context_switch
	bl storeActiveProcess
	bl moveActiveToReadyQueue
	cmp r0, #0
	blne updateActiveProcess
	bl set_timer_compare
	bl set_interrupts
	bl runActiveProcess

	defs 96
temp_stack	

