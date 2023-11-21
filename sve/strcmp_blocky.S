	/* string comparison with SVE, using the AVX-512 approach */

	.set	strcmp, mystrcmp
	.globl	strcmp

	.text
	.type	mystrcmp, %function
	.globl	mystrcmp
	// X0: a
	// X1: b
mystrcmp:
	cntb	x6, all
	ptrue	p0.b, all
	sub	x2, x6, #1		// mask of bits below the natural alignment of a vector
	and	x3, x0, x2		// offset of a from vector alignment
	and	x4, x1, x2		// offset of b from vector alignment
	whilelo	p3.b, x3, x6		// bytes in a until alignment boundary
	whilelo	p4.b, x4, x6		// bytes in b until alignment boundary
	ld1b	z0.b, p3/z, [x0]	// head of a
	ld1b	z1.b, p4/z, [x1]	// head of b
	bic	x0, x0, x2		// align a to vector alignment
	bic	x1, x1, x2		// align b to vector alignment
	cmp	x3, x4			// which of the strings has a higher alignment offset?
	blo	.Lswapped		// invariant: x2 >= x3.  If it fails, swap and proceed.

	/* here we have x3 >= x4 */
	cmpne	p1.b, p3/z, z0.b, z1.b	// compare heads for mismatches
	cmpeq	p2.b, p4/z, z1.b, #0	// any NUL byte in longer head?
	orrs	p1.b, p4/z, p1.b, p2.b	// any mismatch or NUL byte?
	b.any	.Lend_in_head

	sub	x4, x4, x3		// negated difference between alignments
	sub	x0, x0, x1		// express second buffer as distance from the first
	add	x1, x1, x6		// advance to next iteration
	add	x3, x4, x6		// x4 + vector length (for unrolling)
	add	x5, x0, x6		// x0 + vector length (for unrolling)

	/* main loop unrolled twice */
0:	ld1b	z1.b, p0/z, [x1, x0]	// chunk of a
	ld1b	z0.b, p0/z, [x1]	// chunk of b
	ld1b	z2.b, p0/z, [x1, x4]	// chunk of b corresponding to z1
	cmpeq	p3.b, p0/z, z0.b, #0	// NUL byte in b chunk?
	cmpne	p4.b, p0/z, z1.b, z2.b	// mismatch between chunks?
	orrs	p1.b, p0/z, p3.b, p4.b	// either?
	b.any	1f			// if yes, abort loop

	ld1b	z1.b, p0/z, [x1, x5]	// chunk of a
	ld1b	z0.b, p0/z, [x1, #1, mul vl] // chunk of b
	ld1b	z2.b, p0/z, [x1, x3]	// chunk of b corresponding to z1
	cmpeq	p3.b, p0/z, z0.b, #0	// NUL byte in b chunk?
	cmpne	p4.b, p0/z, z1.b, z2.b	// mismatch between chunks?
	add	x1, x1, x6, lsl #1	// advance to next iteration
	orrs	p1.b, p0/z, p3.b, p4.b	// either?
	b.none	0b			// if yes, abort loop

	sub	x1, x1, x6		// undo second iteration increment
1:	cmpeq	p1.b, p0/z, z1.b, #0	// NUL byte in a chunk?
	sub	x5, x0, x4		// a - b + alignment offset
	orrs	p4.b, p0/z, p1.b, p4.b	// NUL byte or mismatch in a chunk?
	b.none	2f

	brkb	p4.b, p0/z, p4.b	// bytes in a chunk before mismatch/NUL
	lasta	w0, p4, z1.b		// first mismatching/NUL byte in a chunk
	lasta	w1, p4, z2.b		// first mismatching/NUL byte in b chunk
	sub	w0, w0, w1		// difference between the bytes
	ret

	/* no mismatch in a chunk, but NUL beyond it */
2:	ld1b	z3.b, p0/z, [x1, x5]	// chunk of a corresponding to z0
	cmpne	p2.b, p0/z, z0.b, z3.b	// mismatch between chunks?
	orr	p2.b, p0/z, p3.b, p2.b	// mismatch or NUL bytes?
	brkb	p2.b, p0/z, p2.b	// bytes in chunk before mismatch/NUL
	lasta	w0, p2, z3.b
	lasta	w1, p2, z0.b
	sub	w0, w0, w1
	ret

.Lend_in_head:
	brka	p1.b, p0/z, p2.b	// bytes until (and incl.) the mismatch/NUL
	ld1b	z0.b, p1/z, [x0, x3]	// reload a head until mismatch/NUL
	cmpne	p1.b, p1/z, z0.b, z1.b	// mismatch between extended heads?
	orr	p1.b, p0/z, p1.b, p2.b	// mismatch or NUL byte?
	brkb	p1.b, p0/z, p1.b	// bytes in chunk before mismatch/NUL
	lasta	w0, p1, z0.b
	lasta	w1, p1, z1.b
	sub	w0, w0, w1
	ret

	/* here we have x3 < x4 */
.Lswapped:
	cmpne	p1.b, p4/z, z0.b, z1.b	// compare heads for mismatches
	cmpeq	p2.b, p3/z, z0.b, #0	// any NUL byte in longer head?
	orrs	p1.b, p3/z, p1.b, p2.b	// any mismatch or NUL byte?
	b.any	.Lend_in_head_swapped

	sub	x4, x3, x4		// negated difference between alignments
	sub	x1, x1, x0		// express second buffer as distance from the first
	add	x0, x0, x6		// advance to next iteration
	add	x3, x4, x6		// x4 + vector length (for unrolling)
	add	x5, x1, x6		// x0 + vector length (for unrolling)

	/* main loop unrolled twice */
0:	ld1b	z1.b, p0/z, [x0, x1]	// chunk of b
	ld1b	z0.b, p0/z, [x0]	// chunk of a
	ld1b	z2.b, p0/z, [x0, x4]	// chunk of a corresponding to z1
	cmpeq	p3.b, p0/z, z0.b, #0	// NUL byte in a chunk?
	cmpne	p4.b, p0/z, z1.b, z2.b	// mismatch between chunks?
	orrs	p1.b, p0/z, p3.b, p4.b	// either?
	b.any	1f			// if yes, abort loop

	ld1b	z1.b, p0/z, [x0, x5]	// chunk of b
	ld1b	z0.b, p0/z, [x0, #1, mul vl] // chunk of a
	ld1b	z2.b, p0/z, [x0, x3]	// chunk of a corresponding to z1
	cmpeq	p3.b, p0/z, z0.b, #0	// NUL byte in a chunk?
	cmpne	p4.b, p0/z, z1.b, z2.b	// mismatch between chunks?
	add	x0, x0, x6, lsl #1	// advance to next iteration
	orrs	p1.b, p0/z, p3.b, p4.b	// either?
	b.none	0b			// if yes, abort loop

	sub	x0, x0, x6		// undo second iteration increment
1:	cmpeq	p1.b, p0/z, z1.b, #0	// NUL byte in a chunk?
	sub	x5, x1, x4		// b - a + alignment offset
	orrs	p4.b, p0/z, p1.b, p4.b	// NUL byte or mismatch in a chunk?
	b.none	2f

	brkb	p4.b, p0/z, p4.b	// bytes in a chunk before mismatch/NUL
	lasta	w0, p4, z2.b		// first mismatching/NUL byte in a chunk
	lasta	w1, p4, z1.b		// first mismatching/NUL byte in b chunk
	sub	w0, w0, w1		// difference between the bytes
	ret

	/* no mismatch in a chunk, but NUL beyond it */
2:	ld1b	z3.b, p0/z, [x0, x5]	// chunk of a corresponding to z0
	cmpne	p2.b, p0/z, z0.b, z3.b	// mismatch between chunks?
	orr	p2.b, p0/z, p3.b, p2.b	// mismatch or NUL bytes?
	brkb	p2.b, p0/z, p2.b	// bytes in chunk before mismatch/NUL
	lasta	w0, p2, z0.b
	lasta	w1, p2, z3.b
	sub	w0, w0, w1
	ret

.Lend_in_head_swapped:
	brka	p1.b, p0/z, p2.b	// bytes until (and incl.) the mismatch/NUL
	ld1b	z1.b, p1/z, [x1, x4]	// reload a head until mismatch/NUL
	cmpne	p1.b, p1/z, z0.b, z1.b	// mismatch between extended heads?
	orr	p1.b, p0/z, p1.b, p2.b	// mismatch or NUL byte?
	brkb	p1.b, p0/z, p1.b	// bytes in chunk before mismatch/NUL
	lasta	w0, p1, z0.b
	lasta	w1, p1, z1.b
	sub	w0, w0, w1
	ret
	.size	mystrcmp, .-mystrcmp
