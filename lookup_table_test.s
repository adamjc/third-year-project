; writing values to a look-up table test program

main
	adrl r0, test_table
	adrl r1, pcb1
	adrl r2, pcb2
	b main

test_table
	pcb1
	defs 16
	pcb2
	defs 16