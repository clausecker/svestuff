	/* string-copying to fixed-length buffers with AVX-512 */

	.section	.rodata
.Lmask:	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000

	.text
	.type		mystrncpy, @function
	.globl		mystrncpy
mystrncpy:
#define bounce		(-3*64)			/* location of on-stack bounce buffer */

	test		%rdx, %rdx		# no bytes to copy?
	jz		.L0

	mov		%esi, %ecx
	and		$~0x3f, %rsi		# align source to 64 bytes
	vmovdqa64	(%rsi), %zmm0		# load head
	and		$0x3f, %ecx		# offset from alignment
	mov		$-1, %r9
	lea		-128(%rcx), %rax	# set up overflow-proof comparison rdx+rcx<=128
	shl		%cl, %r9		# mask of bytes belonging to the string
	sub		%rcx, %rdi		# adjust RDI to correspond to RSI
	vpxor		%ymm1, %ymm1, %ymm1
	vmovdqu8	%zmm0, bounce(%rsp)	# stash copy of head on the stack
	vpcmpeqb	%zmm1, %zmm0, %k0
	kmovq		%k0, %r8

	lea		(%rdx, %rcx, 1), %r10	# buffer length from alignment boundary
	add		%rdx, %rax		# less than 2 chunks (32 bytes) to play with?
	jnc		.Lrunt			# if yes, use special runt processing

	vmovdqu8	%zmm1, -64(%rdi, %r10, 1) # clear final bytes of destination
	and		%r9, %r8		# end of string within head?
	jnz		.Lheadnul

	vmovdqu8	(%rsi, %rcx, 1), %zmm2	# load head from source buffer
	vmovdqu8	%zmm2, (%rdi, %rcx, 1)	# an deposit

	add		$64, %rsi
	add		$64, %rdi
	add		$-128, %r10

	/* main loop unrolled twice */
	.balign		16
0:	vmovdqa64	(%rsi), %zmm0
	vpcmpeqb	%zmm0, %zmm1, %k0	# NUL byte encountered?
	kmovq		%k0, %r8
	test		%r8, %r8
	jnz		3f

	vmovdqu8	%zmm0, (%rdi)
	cmp		$64, %r10		# more than a full chunk left?
	jbe		1f

	vmovdqa64	64(%rsi), %zmm0
	sub		$-128, %rdi		# advance pointers to next chunk
	sub		$-128, %rsi
	vpcmpeqb	%zmm0, %zmm1, %k0	# NUL byte encountered?
	kmovq		%k0, %r8
	test		%r8, %r8
	jnz		2f

	vmovdqu8	%zmm0, -64(%rdi)
	sub		$128, %r10		# more than another full chunk left?
	ja		0b

	sub		$64, %rdi		# undo second advancement
	sub		$64, %rsi
	add		$64, %r10d		# restore number of remaining bytes

	/* 1--64 bytes left but string has not ended yet */
1:	vpcmpeqb	64(%rsi), %zmm1, %k0	# NUL byte in source tail?
	kmovq		%k0, %r8
	bts		%r10, %r8		# treat end of buffer as NUL
	tzcnt		%r8, %r8		# where is the NUL byte?
	vmovdqu8	(%rsi, %r8, 1), %zmm0	# load source tail before NUL
	lea		64(%rdi, %r8, 1), %rax	# point return value to NUL byte
						# or end of buffer
	vmovdqu8	%zmm0, (%rdi, %r8, 1)	# store tail into the buffer
	ret

2:	sub		$64, %rdi		# undo second advancement
	sub		$64, %rsi
	sub		$64, %r10

	/* string has ended and buffer has not */
3:	tzcnt		%r8, %r8		# where did the string end?
	lea		.Lmask+64(%rip), %rcx
	lea		(%rdi, %r8, 1), %rax 	# where the NUL byte will be
	neg		%r8
	vpandd		(%rcx, %r8, 1), %zmm0, %zmm0	 # mask out bytes after the string
	vmovdqu8	%zmm0, (%rdi)	 	# store masked current chunk
	sub		$64, %r10		# another full chunk left?
	jbe		1f

	/* clear remaining destination buffer (tail has been cleared earlier) */
	.balign		16
0:	vmovdqu8	%zmm1, 64(%rdi)
	cmp		$64, %r10
	jbe		1f

	vmovdqu8	%zmm1, 128(%rdi)
	sub		$-128, %rdi
	sub		$128, %r10
	ja		0b

1:	ret

	/* at least two chunks to play with and NUL while processing head */
.Lheadnul:
	vmovdqu8	bounce(%rsp, %rcx, 1), %zmm0 # load start of source from stack
	tzcnt		%r8, %r8		# find location of NUL byte
	vmovdqu8	%zmm0, (%rdi, %rcx, 1)	# deposit head in the destination
	vmovdqu8	%zmm1, (%rdi, %r8, 1)	# clear out following bytes
	vmovdqu8	%zmm1, 64(%rdi)		# clear out second chunk
	lea		(%rdi, %r8, 1), %rax	# make RAX point to the NUL byte

	sub		$-128, %rdi		# advance past first two chunks
	sub		$128+64, %r10		# advance past first three chunks
	jbe		1f			# did we pass the end of the buffer?

	/* clear remaining destination buffer (tail has been cleared earlier) */
	.balign		16
0:	vmovdqu8	%zmm1, (%rdi)		# clear out buffer chunk
	cmp		$64, %r10
	jbe		1f

	vmovdqu8	%zmm1, 64(%rdi)
	sub		$-128, %rdi
	sub		$128, %r10
	ja		0b

1:	ret

	/* 1--128 bytes to copy */
.Lrunt:	mov		$-1, %rax
	xor		%edx, %edx
	sub		%r10d, %edx		# 64-r10 + junk in upper bits
	and		%r9, %r8		# disregard NUL bytes before string
	shrx		%rdx, %rax, %rax	# mask of valid bytes in last buffer chunk
	cmp		$64, %r10d		# is the buffer 64 bytes or less?
	ja		0f

	/* 1--63 bytes to copy */
	blsmsk		%r8, %r8		# mask of bytes in ZMM0 before NUL byte
	and		%r9, %rax		# disregard bytes before the buffer
	kmovq		%r8, %k1
	kmovq		%rax, %k2
	vmovdqu8	%zmm0, %zmm0{%k1}{z}	# clear bytes in ZMM0 beyond NUL byte
	vmovdqu8	%zmm0, (%rdi){%k2}	# deposit into output buffer
	lea		(%rdi, %rcx, 1), %rax	# return pointer to destination
	ret

	/* 64--128 bytes to copy */
0:	xor		%edx, %edx
	blsmsk		%r8, %r8		# mask of bytes in ZMM0 before NUL byte
	cmovc		%r8, %rdx		# if no NUL in ZMM0, search for NUL in second chunk
	kmovq		%r9, %k1		# mask of buffer bytes in first chunk
	kmovq		%rdx, %k2		# mask for second string chunk
	kmovq		%rax, %k3		# mask of buffer bytes in second chunk
	kmovq		%r8, %k4		# mask of bytes in first buffer before NUL
	kxnorq		%k0, %k0, %k0		# -1
	vmovdqu8	%zmm0, %zmm0{%k4}{z}	# clear string head before NUL byte
	vmovdqu8	64(%rsi), %zmm2{%k2}{z}	# load second string chunk
	vpcmpeqb	%zmm1, %zmm2, %k4	# any NUL bytes?
	kaddq		%k0, %k4, %k0
	kxorq		%k0, %k4, %k4		# mask up to NUL byte
	vmovdqu8	%zmm2, %zmm2{%k4}{z}	# clear bytes beyond end of string
	vmovdqu8	%zmm0, (%rdi){%k1}	# deposit first chunk into buffer
	vmovdqu8	%zmm2, 64(%rdi){%k3}	# depsoit second chunk into buffer
	lea		(%rdi, %rcx, 1), %rax	# return pointer to destination
	ret

	/* length 0 buffer: just return dest */
.L0:	mov		%rdi, %rax
	ret
