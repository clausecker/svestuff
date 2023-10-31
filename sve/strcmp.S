	/* string comparison with SVE */

	.text
	.type	mystrcmp, %function
	.globl	mystrcmp
	// X0: a
	// X1: b
mystrcmp:
	ptrue	p0.b, all
	mov	x2, #0			// index
0:	setffr
	ldff1b	z0.b, p0/z, [x0, x2]	// load strings
	ldff1b	z1.b, p0/z, [x1, x2]
	rdffr	p1.b
	incp	x2, p1.b		// advance to next chunk
	cmpeq	p2.b, p1/z, z0.b, #0	// NUL byte found?
	bne	.Leos			// if yes, handle end of string
	cmpne	p2.b, p1/z, z0.b, z1.b	// mismatch?
	beq	0b			// if not, go again

	// mismatch between the strings
	brka	p2.b, p1/z, p2.b	// bytes up to including the mismatch
	lastb	w0, p2, z0.b		// mismatching byte of a
	lastb	w1, p2, z1.b		// mismatching byte of b
	sub	w0, w0, w1		// difference between the bytes
	ret

.Leos:	brka	p1.b, p1/z, p2.b	// only consider bytes in the strings
	cmpne	p2.b, p1/z, z0.b, z1.b	// where do they match?
	brka	p2.b, p1/z, p2.b	// bytes up to including the mismatch
	lastb	w0, p2, z0.b		// first mismatch
	lastb	w1, p2, z1.b
	sub	w0, w0, w1		// difference between the bytes
	ret
	.size	mystrcmp, .-mystrcmp
