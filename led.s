; led_flash --------------------------------------------------------------------
; turn an led on and off ad infinitum
;
; input:
;	r0: the led to flash (0 - 7)
; ------------------------------------------------------------------------------
led_flash
	ldr r5, =port_area
	cmp r0, #&80
	bhi	led_flash_error ; process tried to access led that doesn't exist
	mov r6, r0

	b led_loop
		ldr r1, [r5] ; get the led assignments
		orr r1, r6, r1 ; turn r0 on, leave others alone
		strb r1, [r5] ; turn the led on
		mov r0, #&40000
		bl led_delay ; wait for a bit

		; now we want to turn the led off
		ldr r1, [r5] ; get the led assignments
		and r1, r6, r1 
		xor r1, r6, r1 ; turn r0 off, leave others alone
		strb r1, [r5] ; turn the led off
		mov r0, #&40000
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