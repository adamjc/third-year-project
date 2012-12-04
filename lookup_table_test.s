; writing values to a look-up table test program

main
	adrl r0, test_table
	b main

test_table	DEFW	0
			DEFW	1
			DEFW	2
			DEFW	3