	/* string copying to fixed-length buffer with SVE */

	.text
	.type	mystrrncpy, %function
	.globl	mystrncpy
	// X0: dst
	// X1: src
	// X2: len
mystrncpy:
	mov	x3, #0			// index
	setffr
	whilelo	p0.b, x3, x2		// compute load mask
0:	ldff1b	z0.b, p0/z, [x1, x3]	// load from source
	rdffr	p1.b, p0/z		// compute how much items were loaded
	cmpeq	p1.b, p0/z, z0.b, #0	// NUL terminator found?
	b.any	.Leos

	st1b	z0.b, p0, [x0, x3]	// store string
	incp	x3, p0.b		// advance pointers
	setffr
	whilelo	p0.b, x3, x2		// prepare next iteration
	b.any	0b

	ret

	/* end of string encountered */
.Leos:	brka	p1.b, p0/z, p1.b	// characters that are in the string
	mov	z1.b, #0
	sel	z0.b, p1, z0.b, z1.b	// clear characters past EOS
	st1b	z0.b, p0, [x0, x3]	// store string
	incp	x3, p0.b		// advance pointers

	whilelo	p0.b, x3, x2
	b.any	.Lend

0:	st1b	z1.b, p0, [x0, x3]	// store NUL bytes into destination
	incp	x3, p0.b		// advance pointers
	whilelo	p0.b, x3, x2
	b.any	0b

.Lend:	ret
	.size	mystrncpy, .-mystrncpy
