	/* string comparison with AVX-512 */

	.globl		strcmp
	.set		strcmp, mystrcmp

	.text
	.type		mystrcmp, @function
	.globl		mystrcmp
mystrcmp:
	mov		%edi, %eax
	mov		%esi, %ecx
	and		$0x3f, %eax		# offsets from alignment
	and		$0x3f, %ecx
	and		$~0x3f, %rdi		# align pointers
	and		$~0x3f, %rsi
	mov		$-1, %rdx

	/* compare and prepare heads */
	shrx		%rax, %rdx, %r8		# prefix of RDI before alignment boundary
	shrx		%rcx, %rdx, %r9		# prefix of RSI before alignment boundary
	kmovq		%r8, %k1
	kmovq		%r9, %k2
	vmovdqu8	(%rdi, %rax), %zmm0{%k1}{z}
	vmovdqu8	(%rsi, %rcx), %zmm1{%k2}{z}
	vpxor		%ymm3, %ymm3, %ymm3	# zero register
	cmp		%ecx, %eax		# establish invariant: eax >= ecx
	jb		.Lswapped

	vpcmpnequb	%zmm0, %zmm1, %k3{%k1}	# compare RDI head with RSI head
	vpcmpeqb	%zmm1, %zmm3, %k4{%k2}	# check for NUL bytes in RSI head
	kortestq	%k3, %k4		# any mismatches or NUL bytes?
	jnz		.Lend_in_head

	sub		%rax, %rcx		# negated difference between alignments
	sub		%rsi, %rdi		# express RDI as distance from RSI
	add		$64, %rsi		# advance to next iteration

	/* main loop unrolled twice */
	.balign		16
0:	vmovdqa64	(%rsi, %rdi), %zmm1	# RDI chunk
	vpcmpeqb	(%rsi), %zmm3, %k3	# NUL byte in RSI?
	vpcmpnequb	(%rsi, %rcx), %zmm1, %k4 # mismatch between the chunks?
	kortestq	%k3, %k4		# either?
	jnz		1f			# if yes, abort loop

	vmovdqa64	64(%rsi, %rdi), %zmm1	# RDI chunk
	vpcmpeqb	64(%rsi), %zmm3, %k3	# NUL byte in RSI?
	vpcmpnequb	64(%rsi, %rcx), %zmm1, %k4 # mismatch between the chunks?
	sub		$-128, %rsi		# advance to next iteration
	kortestq	%k3, %k4		# either?
	jz		0b			# if not, keep going

	/* mismatch or NUL byte found */
	sub		$64, %rsi		# undo second iteration increment
1:	kmovq		%k3, %rax
	kmovq		%k4, %rdx
	neg		%ecx			# turn alignment offset positive
	mov		%rax, %r8
	add		%rsi, %rdi		# restore RDI
	shl		%cl, %rax		# adjust NUL mask to chunk in ZMM1/ZMM2
	or		%rax, %rdx		# mismatches or NUL bytes in ZMM1/ZMM2?
	jz		1f			# if not, need to read another chunk

	/* NUL in ZMM1/ZMM2 chunk */
	sub		%rcx, %rsi		# make RSI correspond to RDI

.Lfind_return_value:
	tzcnt		%rdx, %rdx		# find mismatch/NUL
	movzbl		(%rdi, %rdx), %eax
	movzbl		(%rsi, %rdx), %ecx
	sub		%ecx, %eax		# compute return value
	ret	

	/* NUL in ZMM0 behind ZMM1/ZMM2 chunk */
1:	vmovdqa64	(%rsi), %zmm1		# re-load RSI chunk
	vpcmpnequb	(%rdi, %rcx), %zmm1, %k4 # mismatch between the chunks?
	add		%rcx, %rdi		# make RDI correspond to RSI
	kmovq		%k4, %rdx
	or		%r8, %rdx		# mismatch or NUL bytes
	jmp		.Lfind_return_value

	/* NUL or mismatch found within string head */
.Lend_in_head:
	kxnorq		%k0, %k0, %k0		# k0 = -1
	korq		%k3, %k4, %k4		# mismatches or NUL bytes
	kaddq		%k0, %k4, %k3
	kxorq		%k3, %k4, %k3		# mask of head until mismatch or NUL
	vpcmpnequb	(%rdi, %rax), %zmm1, %k3{%k3} # redo comparison if no NUL within %k1
	add		%rax, %rdi		# restore head pointers
	add		%rcx, %rsi
	korq		%k3, %k4, %k4		# mismatch or NUL bytes
	kmovq		%k4, %rdx
	jmp		.Lfind_return_value

.Lswapped:
	vpcmpnequb	%zmm0, %zmm1, %k3{%k2}	# compare RSI head with RDI head
	vpcmpeqb	%zmm0, %zmm3, %k4{%k1}	# check for NUL bytes in RDI head
	kortestq	%k3, %k4		# any mismatches or NUL bytes?
	jnz		.Lend_in_head_swapped

	sub		%rcx, %rax		# negated difference between alignments
	sub		%rdi, %rsi		# express RSI as distance from RDI
	add		$64, %rdi		# advance to next iteration

	/* main loop unrolled twice */
	.balign		16
0:	vmovdqa64	(%rdi, %rsi), %zmm1	# RSI chunk
	vpcmpeqb	(%rdi), %zmm3, %k3	# NUL byte in RDI?
	vpcmpnequb	(%rdi, %rax), %zmm1, %k4 # mismatch between the chunks?
	kortestq	%k3, %k4		# either?
	jnz		1f			# if yes, abort loop

	vmovdqa64	64(%rdi, %rsi), %zmm1	# RSI chunk
	vpcmpeqb	64(%rdi), %zmm3, %k3	# NUL byte in RDI?
	vpcmpnequb	64(%rdi, %rax), %zmm1, %k4 # mismatch between the chunks?
	sub		$-128, %rdi		# advance to next iteration
	kortestq	%k3, %k4		# either?
	jz		0b			# if not, keep going

	/* mismatch or NUL byte found */
	sub		$64, %rdi		# undo second iteration increment
1:	kmovq		%k3, %rcx
	kmovq		%k4, %rdx
	neg		%eax			# turn alignment offset positive
	mov		%rcx, %r8
	add		%rdi, %rsi		# restore RSI
	shlx		%rax, %rcx, %rcx	# adjust NUL mask to chunk in ZMM1/ZMM2
	or		%rcx, %rdx		# mismatches or NUL bytes in ZMM1/ZMM2?
	jz		1f			# if not, need to read another chunk

	/* NUL in ZMM1/ZMM2 chunk */
	sub		%rax, %rdi		# make RDI correspond to RSI
	jmp		.Lfind_return_value

	/* NUL in ZMM0 behind ZMM1/ZMM2 chunk */
1:	vmovdqa64	(%rdi), %zmm1		# re-load RDI chunk
	vpcmpnequb	(%rsi, %rax), %zmm1, %k4 # mismatch between the chunks?
	add		%rax, %rsi		# make RSI correspond to RDI
	kmovq		%k4, %rdx
	or		%r8, %rdx		# mismatch or NUL bytes
	jmp		.Lfind_return_value

	/* NUL or mismatch found within string head */
.Lend_in_head_swapped:
	kxnorq		%k0, %k0, %k0		# k0 = -1
	korq		%k3, %k4, %k4		# mismatches or NUL bytes
	kaddq		%k0, %k4, %k3
	kxorq		%k3, %k4, %k3		# mask of head until mismatch or NUL
	vpcmpnequb	(%rsi, %rcx), %zmm0, %k3{%k3} # redo comparison if no NUL within %k2
	add		%rax, %rdi		# restore head pointers
	add		%rcx, %rsi
	korq		%k3, %k4, %k4		# mismatch or NUL bytes
	kmovq		%k4, %rdx
	jmp		.Lfind_return_value

	.size		mystrcmp, .-mystrcmp
