	/* string comparison with SVE */

	.set	strcmp, mystrcmp
	.globl	strcmp

	.text
	.type	mystrcmp, %function
	.globl	mystrcmp
	// X0: a
	// X1: b
mystrcmp:
	ptrue	p0.b, all
	mov	x2, #0			// index
	setffr
0:	ldff1b	z0.b, p0/z, [x0, x2]	// load strings
	ldff1b	z1.b, p0/z, [x1, x2]
	rdffr	p1.b
	b.nlast	1f

	incb	x2, all			// advance to next chunk
	cmpeq	p2.b, p0/z, z0.b, #0	// NUL byte found?
	cmpne	p3.b, p0/z, z0.b, z1.b	// mismatch?
	orrs	p2.b, p0/z, p2.b, p3.b	// either?
	b.none	0b			// if not, go again

	// mismatch between the strings
	brka	p2.b, p0/z, p2.b	// bytes up to including the mismatch
	lastb	w0, p2, z0.b		// mismatching byte of a
	lastb	w1, p2, z1.b		// mismatching byte of b
	sub	w0, w0, w1		// difference between the bytes
	ret

	// partial read
1:	incp	x2, p1.b		// advance to next chunk
	cmpeq	p2.b, p1/z, z0.b, #0	// NUL byte found?
	cmpne	p3.b, p1/z, z0.b, z1.b	// mismatch?
	orrs	p2.b, p1/z, p2.b, p3.b	// either?
	setffr
	b.none	0b			// if not, go again

	// mismatch between the strings
	brka	p2.b, p1/z, p2.b	// bytes up to including the mismatch
	lastb	w0, p2, z0.b		// mismatching byte of a
	lastb	w1, p2, z1.b		// mismatching byte of b
	sub	w0, w0, w1		// difference between the bytes
	ret

	.size	mystrcmp, .-mystrcmp
