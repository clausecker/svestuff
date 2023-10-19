  	/* integer parsing with SVE */

	.section .rodata
	.balign	16
.Lmyriads:
	.quad	1, 10000, 100000000, 1000000000000
.Ltens:	.short	1, 10, 100, 1000
.Lpowers:
	.quad	1,                 10,             100,             1000
	.quad	10000,             100000,         1000000,         10000000
	.quad	100000000,         1000000000,     10000000000,     100000000000
	.quad	1000000000000,     10000000000000, 100000000000000, 1000000000000000
	.quad	10000000000000000

	.text
	.type	mystrtol, %function
	.globl	mystrtol
	// x0: str
	// x1: endptr
	// x2: base
mystrtol:
	sub	sp, sp, #16
	mov	x3, sp
	cmp	x1, #0				// was an endptr provided?
	csel	x1, x1, x3, ne			// if not, redirect write to dummy stack slot
	setffr
	ptrue	p1.h, vl16			// can process up to 16 digits per iteration
	ldff1b	z0.h, p1/z, [x0]		// load string head
	rdffr	p2.b, p1/z			// list of valid elements in z0
	mov	x8, #0				// offset of current load from x0

	// step 0: load constants
	adrp	x3, .Lmyriads
	add	x3, x3, #:lo12:.Lmyriads
	ptrue	p3.d, vl4			// limit loads to 8x4 = 32 bytes
	ld1d	{z31.d}, p3/z, [x3]		// load myriads
	ld1rd	{z30.d}, p3/z, [x3, #.Ltens-.Lmyriads]
	add	x3, x3, #.Lpowers-.Lmyriads

	// step 1: skip leading whitespace
	// ... todo ...

	// step 2: extract sign (+ or -)
	movprfx	z1, z0
	sub	z1.h, z1.h, #'+'		// adjust characters such that +/- can be imm.
	pfalse	p3.b
	pfirst	p3.b, p2, p3.b			// where a + or - sign could be
	cmpeq	p4.h, p2/z, z1.h, #'+'-'+'	// + present?
	cmpeq	p5.h, p2/z, z1.h, #'-'-'+'
	orr	p4.b, p3/z, p4.b, p5.b		// either present?
	mov	w4, #'+'			// default sign is '+'
	clastb	w4, p4, w4, z0.h		// if a sign was present, store it in w3
	bics	p2.b, p1/z, p2.b, p4.b		// mark sign bit as inactive
	bne	0f				// any active bytes left?

	rdffr	p2.b, p1/z			// list of valid elements from previous load
	setffr
	incp	x8, p2.b			// advance pointer by that many bytes
	ldff1b	z0.h, p1/z, [x0, x8]		// redo the load
	rdffr	p2.b, p1/z			// get new active element mask

	// step 3: extract digits
0:	mov	x5, #0				// result accumulator
	sub	z0.h, z0.h, #'0'		// convert digits to decimal
	cmphi	p3.h, p2/z, z0.h, #9		// which of these are not digits?
	brkbs	p4.b, p2/z, p3.b		// longest all-digit prefix
	beq	.Lfail				// fail if no digits found

1:	cntp	x6, p1, p4.b			// number of digits found
	ldr	x6, [x3, x6, lsl #3]		// prepare multiplication factor for accumulator
	rev	z0.h, z0.h			// reverse digits to little-endian order
	rev	p5.h, p4.h			// match reversed digits in predicate
	mov	z1.h, #0
	splice	z0.h, p5, z0.h, z1.h		// move digits to the front
	udot	z1.d, z0.h, z30.h		// multiply with [1, 10, 100, 1000] and sum
	mul	z1.d, p1/m, z1.d, z31.d		// scale groups by [10**0, 10**4, 10**8, 10**12]
	uaddv	d3, p1, z1.d			// sum groups and zero-extend
	fmov	x7, d3
	madd	x5, x5, x6, x7			// add this batch to accumulator
	bics	p2.b, p1/z, p2.b, p4.b		// mark digits as inactive
	bne	0f				// reach end of digits?

	rdffr	p2.b, p1/z
	setffr
	incp	x8, p2.b			// advance pointer past bytes consumed
	ldff1b	z0.h, p1/z, [x0, x8]		// load additional digits
	rdffr	p2.b, p1/z
	sub	z0.h, z0.h, #'0'		// convert digits to decimal
	cmphi	p3.h, p2/z, z0.h, #9		// which of these are not digits?
	brkbs	p4.b, p2/z, p3.b		// longest all-digit prefix
	bne	1b				// and if any digits remain, convert again

	// all digits extracted, write end pointer and return result
0:	brkb	p4.b, p1/z, p3.b		// prefix until first non-digit
	incp	x8, p4.b			// advance to first non-digit
	add	x0, x0, x8			// compute end pointer
	str	x0, [x1]			// *endptr = end
	cmp	w4, #'-'
	cneg	x0, x5, eq			// result = sign == '-' ? -result : result
	add	sp, sp, #16
	ret

	// decoding error: no valid digits found
.Lfail:	str	x0, [x1]			// *endptr = buf
	mov	x0, #0				// result = 0
	add	sp, sp, #16
	ret
	.size	mystrtol, .-mystrtol
