; led_flash --------------------------------------------------------------------
; turn an led on and off ad infinitum
;
; input:
;	r0: the led to flash (0 - 7)
; ------------------------------------------------------------------------------
led_flash
	ldr r5, =PORT_AREA
	cmp r0, #&80
	bhi	led_flash_error ; process tried to access led that doesn't exist
	mov r6, r0

	led_loop
		mov r0, r6
		svc SET_LEDS

		mov r0, #&900
		bl led_delay ; wait for a bit

		; now we want to turn the led off
		mov r0, r6
		svc UNSET_LEDS

		mov r0, #&900
		bl led_delay ; wait for a bit

		b led_loop

	led_flash_error
		b led_flash_error ; something went wrong
		
; led_delay --------------------------------------------------------------------
; busy-wait a specified amount of time.
;
; input:
;	r0: the length of time to wait for
; ------------------------------------------------------------------------------
led_delay
	sub r0, r0, #1
	cmp r0, #0
	bne led_delay
	mov pc, lr

; svc_get_leds -----------------------------------------------------------------
; gets the current led assignments
; output:
;	r0: the current led assignments
; ------------------------------------------------------------------------------
svc_get_leds
	ldr r0, =PORT_AREA
	ldr r0, [r0]
	pop {lr}
	movs pc, lr

; svc_set_leds -----------------------------------------------------------------
; sets the led assignments
; input:
;	r0: the led assignments to set
; ------------------------------------------------------------------------------
svc_set_leds
	ldr r1, =PORT_AREA
	ldr r2, [r1] ; get the led assignments
	orr r0, r0, r2 ; set the led on, without affecting others
	strb r0, [r1] ; store it to the port area
	pop {lr}
	movs pc, lr

; svc_unset_leds ----------------------------------------------------------------
; turns the led(s) specified, off.
; input:
;	r0: the led(s) to turn off.
; ------------------------------------------------------------------------------
svc_unset_leds
	ldr r1, =PORT_AREA
	ldr r2, [r1] ; get the led assignments
	and r0, r0, r2
	eor r0, r0, r2 ; set the led(s) specified, off, leave others on
	strb r0, [r1] ; store it to the port area
	pop {lr}
	movs pc, lr