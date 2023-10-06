  	/* integer parsing with SVE */

	.section .rodata
	.balign	8
.Ltens:	.quad	1
	.quad	10
	.quad	100
	.quad	1000
	.quad	10000
	.quad	100000
	.quad	1000000
	.quad	10000000
	.quad	100000000
	.quad	1000000000
	.quad	10000000000
	.quad	100000000000
	.quad	1000000000000
	.quad	10000000000000
	.quad	100000000000000
	.quad	1000000000000000
	.quad	10000000000000000
	.quad	100000000000000000
	.quad	1000000000000000000

	.text
	.type	strtol, %function
	.globl	strtol
	// x0: str
	// x1: endptr
	// x2: base
strtol:	setffr
	ptrue	p1.b, all
	pfalse	p0.b
	mov	x3, x0				// stash a copy of the original pointer
	ldff1b	z0.d, p1/z, [x0]		// load string head
	rdffr	p2.b				// list of valid elements in z0
	zip1	p2.b, p2.b, p0.b		// convert to half-words
	zip1	p2.h, p2.h, p0.h		// convert to words
	zip1	p2.s, p2.s, p0.s		// convert to double (64 bit) words

	// step 0: load powers of 10
	mov	w3, #19				// number of powers of 10 in LUT
	whilels	p3.d, xzr, x3			// generate mask of at most that many double words
	adrp	x4, .Ltens
	add	x4, x4, #:lo12:.Ltens
	ld1d	{z6.d}, p3/z, [x4]		// load powers of 10

	// step 1: skip leading whitespace
	// TODO

	// step 2: extract sign (+ or -)
	movprfx	z1, z0
	sub	z1.d, z1.d, #'+'		// adjust characters such that +/- can be imm.
	mov	p3.b, p2.b
	pfirst	p3.b, p2, p3.b			// where a + or - sign could be
	cmpeq	p4.d, p2/z, z1.d, #'+'-'+'	// + present?
	cmpeq	p5.d, p2/z, z1.d, #'-'-'+'	// - present?
	orr	p4.b, p3/z, p4.b, p5.b
	mov	w3, #'+'
	clastb	x3, p4, x3, z0.d		// get sign if present, else '+'
	bics	p2.b, p1/z, p2.b, p4.b		// mark sign bit as inactive
	bne	0f				// any active bytes left?

	rdffr	p2.b				// list of valid elements from previous load
	setffr
	incp	x0, p2.b			// advance pointer by that many bytes
	ldff1b	z0.d, p1/z, [x0]		// redo the load
	rdffr	p2.b				// get new active element mask
	zip1	p2.b, p2.b, p0.b		// convert to half-words
	zip1	p2.h, p2.h, p0.h		// convert to words
	zip1	p2.s, p2.s, p0.s		// convert to double (64 bit) words

	// step 3: extract digits
0:	sub	z1.d, z0.d, #'0'		// convert digits to decimal
	cmphi	p3.d, p2/z, z0.d, #9		// which of these are not digits?
	brkbs	p3.b, p2/z, p3.b		// longest all-digit prefix
	beq	.Lfail				// fail if no digits found
	cntp	x4, p3, p3.d			// number of digits decoded this iteration
	rev	z1.d, z1.d			// flip digit vector
	rev	p3.d, p3.d			// dito for predicate
	compact	z1.d, p3, z1.d			// compact digits into the beginning the vector
	mul	z1.d, z1.d, z6.d		// scale by powers of 10

	// decoding error: no valid digits found
.Lfail:

	.size	strtol, .-strtol
