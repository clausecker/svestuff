	/* convert Latin1 to UTF-8 */

	/*
	 * 0GFE DCBA -> ---- ----  0GFE DCBA
	 * 1GFE DCBA -> 1100 001G  10FE DCBA
	 */

	.text
	.type	mylatin1_to_utf8, %function
	.globl	mylatin1_to_utf8
	// X0: out
	// X1: in
	// X2: inlen
	// returns outlen
mylatin1_to_utf8:
	mov	x4, #0			// input index
	mov	x3, #0			// output index
	mov	z31.s, #0xc0		// 1100000
	mov	z30.s, #0x40		// 0100000
	whilelo	p0.s, x4, x2		// mask of bytes until x4 reached
	b.none	1f			// loop until the end of input

0:	ld1b	z0.s, p0/z, [x1, x4]	// load input zero-extended

	cmphi	p1.s, p0/z, z0.s, #0x7f	// which of bytes are 1GFEDCBA?
	movprfx	z1.s, p1/z, z0.s	// 1GFEDCBA if >0x7f, 00000000 otherwise
	lsr	z1.s, p1/m, z1.s, #6	// 0000001G if >0x7f, 00000000 otherwise
	bic	z0.s, p1/m, z0.s, z30.s	// 10FEDCBA if >0x7f, 0GFEDCBA otherwise
	orr	z1.s, p1/m, z1.s, z31.s	// 1100001G if >0x7f, 00000000 otherwise

	zip1	p2.s, p1.s, p0.s	// bit masks indicating bytes to keep
	zip2	p3.s, p1.s, p0.s
	zip1	z2.s, z1.s, z0.s	// low half of UTF-8 output
	zip2	z3.s, z1.s, z0.s	// high half of UTF-8 output
	compact	z2.s, p2, z2.s		// discard unwanted high bytes
	compact	z3.s, p3, z3.s

	cntp	x5, p2, p2.s		// number of valid elements in z2
	cntp	x6, p3, p3.s		// number of valid elements in z3
	whilelo	p2.s, xzr, x5		// mask of valid elements in z2
	whilelo	p3.s, xzr, x6		// mask of valid elements in z3
	st1b	z2.s, p2, [x0, x3]	// store first half
	add	x3, x3, x5		// advance to second half
	st1b	z3.s, p3, [x0, x3]	// store second half
	add	x3, x3, x6		// advance past second half

	incp	x4, p0.s		// advance input by processed bytes
	whilelo	p0.s, x4, x2		// mask of next input bytes
	b.any	0b

1:	mov	x0, x3			// return output length
	ret
