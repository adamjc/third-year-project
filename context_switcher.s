; context_switcher -------------------------------------------------------------
;
;
;-------------------------------------------------------------------------------

TEMP_IRQ_LR EQU &9D4
TEMP_R0 EQU &9D8
TEMP_R1 EQU &9DC
TEMP_IRQ_CPSR EQU &9E0
TEMP_SYSTEM_CPSR EQU &9E4

; svc_context_switch ----------------------------------------------------------------
; Saves the state of the currently running process, including it's registers
; r0-12, SP, LR & PC. Then loads up the state of the next process to be run,
; and continues from where the process just switched into left off.
;-------------------------------------------------------------------------------
svc_context_switch
	; TEST
	push {lr} ; lr is user mode pc, we don't want this to be removed with a bl
	bl storeActiveProcess
	bl moveActiveToReadyQueue
	cmp r0, #0
	blne updateActiveProcess
	bl runActiveProcess

	; done

	defs 96
temp_stack	

