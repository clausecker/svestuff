	/* string comparison with AVX-512 */

	.globl		strcmp
	.set		strcmp, mystrcmp

	.text
	.type		mystrcmp, @function
	.globl		mystrcmp
mystrcmp:
	mov		%edi, %eax
	mov		%esi, %ecx
	and		$0x1f, %eax		# offsets from alignment
	and		$0x1f, %ecx
	and		$~0x1f, %rdi		# align pointers
	and		$~0x1f, %rsi
	mov		$-1, %edx

	/* compare and prepare heads */
	shrx		%eax, %edx, %r8d	# prefix of RDI before alignment boundary
	shrx		%ecx, %edx, %r9d	# prefix of RSI before alignment boundary
	kmovd		%r8d, %k1
	kmovd		%r9d, %k2
	vmovdqu8	(%rdi, %rax), %ymm0{%k1}{z}
	vmovdqu8	(%rsi, %rcx), %ymm1{%k2}{z}
	vpxor		%ymm3, %ymm3, %ymm3	# zero register
	cmp		%ecx, %eax		# establish invariant: eax >= ecx
	jb		.Lswapped

	vpcmpnequb	%ymm0, %ymm1, %k3{%k1}	# compare RDI head with RSI head
	vpcmpeqb	%ymm1, %ymm3, %k4{%k2}	# check for NUL bytes in RSI head
	kortestd	%k3, %k4		# any mismatches or NUL bytes?
	jnz		.Lend_in_head

	sub		%rax, %rcx		# negated difference between alignments
	sub		%rsi, %rdi		# express RDI as distance from RSI
	add		$32, %rsi		# advance to next iteration

	/* main loop unrolled twice */
	.balign		16
0:	vmovdqa		(%rsi, %rdi), %ymm1	# RDI chunk
	vpcmpeqb	(%rsi), %ymm3, %k3	# NUL byte in RSI?
	vpcmpnequb	(%rsi, %rcx), %ymm1, %k4 # mismatch between the chunks?
	kortestd	%k3, %k4		# either?
	jnz		1f			# if yes, abort loop

	vmovdqa		32(%rsi, %rdi), %ymm1	# RDI chunk
	vpcmpeqb	32(%rsi), %ymm3, %k3	# NUL byte in RSI?
	vpcmpnequb	32(%rsi, %rcx), %ymm1, %k4 # mismatch between the chunks?
	add		$64, %rsi		# advance to next iteration
	kortestd	%k3, %k4		# either?
	jz		0b			# if not, keep going

	/* mismatch or NUL byte found */
	sub		$32, %rsi		# undo second iteration increment
1:	kmovd		%k3, %eax
	kmovd		%k4, %edx
	neg		%ecx			# turn alignment offset positive
	mov		%eax, %r8d
	add		%rsi, %rdi		# restore RDI
	shl		%cl, %eax		# adjust NUL mask to chunk in ymm1/ymm2
	or		%eax, %edx		# mismatches or NUL bytes in ymm1/ymm2?
	jz		1f			# if not, need to read another chunk

	/* NUL in ymm1/ymm2 chunk */
	sub		%rcx, %rsi		# make RSI correspond to RDI

.Lfind_return_value:
	tzcnt		%edx, %edx		# find mismatch/NUL
	movzbl		(%rdi, %rdx), %eax
	movzbl		(%rsi, %rdx), %ecx
	sub		%ecx, %eax		# compute return value
	ret	

	/* NUL in ymm0 behind ymm1/ymm2 chunk */
1:	vmovdqa		(%rsi), %ymm1		# re-load RSI chunk
	vpcmpnequb	(%rdi, %rcx), %ymm1, %k4 # mismatch between the chunks?
	add		%rcx, %rdi		# make RDI correspond to RSI
	kmovd		%k4, %edx
	or		%r8d, %edx		# mismatch or NUL bytes
	jmp		.Lfind_return_value

	/* NUL or mismatch found within string head */
.Lend_in_head:
	kxnord		%k0, %k0, %k0		# k0 = -1
	kord		%k3, %k4, %k4		# mismatches or NUL bytes
	kaddd		%k0, %k4, %k3
	kxord		%k3, %k4, %k3		# mask of head until mismatch or NUL
	vpcmpnequb	(%rdi, %rax), %ymm1, %k3{%k3} # redo comparison if no NUL within %k1
	add		%rax, %rdi		# restore head pointers
	add		%rcx, %rsi
	kord		%k3, %k4, %k4		# mismatch or NUL bytes
	kmovd		%k4, %edx
	jmp		.Lfind_return_value

.Lswapped:
	vpcmpnequb	%ymm0, %ymm1, %k3{%k2}	# compare RSI head with RDI head
	vpcmpeqb	%ymm0, %ymm3, %k4{%k1}	# check for NUL bytes in RDI head
	kortestd	%k3, %k4		# any mismatches or NUL bytes?
	jnz		.Lend_in_head_swapped

	sub		%rcx, %rax		# negated difference between alignments
	sub		%rdi, %rsi		# express RSI as distance from RDI
	add		$32, %rdi		# advance to next iteration

	/* main loop unrolled twice */
	.balign		16
0:	vmovdqa		(%rdi, %rsi), %ymm1	# RSI chunk
	vpcmpeqb	(%rdi), %ymm3, %k3	# NUL byte in RDI?
	vpcmpnequb	(%rdi, %rax), %ymm1, %k4 # mismatch between the chunks?
	kortestd	%k3, %k4		# either?
	jnz		1f			# if yes, abort loop

	vmovdqa		32(%rdi, %rsi), %ymm1	# RSI chunk
	vpcmpeqb	32(%rdi), %ymm3, %k3	# NUL byte in RDI?
	vpcmpnequb	32(%rdi, %rax), %ymm1, %k4 # mismatch between the chunks?
	add		$64, %rdi		# advance to next iteration
	kortestd	%k3, %k4		# either?
	jz		0b			# if not, keep going

	/* mismatch or NUL byte found */
	sub		$32, %rdi		# undo second iteration increment
1:	kmovd		%k3, %ecx
	kmovd		%k4, %edx
	neg		%eax			# turn alignment offset positive
	mov		%ecx, %r8d
	add		%rdi, %rsi		# restore RSI
	shlx		%eax, %ecx, %ecx	# adjust NUL mask to chunk in ymm1/ymm2
	or		%ecx, %edx		# mismatches or NUL bytes in ymm1/ymm2?
	jz		1f			# if not, need to read another chunk

	/* NUL in ymm1/ymm2 chunk */
	sub		%rax, %rdi		# make RDI correspond to RSI
	jmp		.Lfind_return_value

	/* NUL in ymm0 behind ymm1/ymm2 chunk */
1:	vmovdqa		(%rdi), %ymm1		# re-load RDI chunk
	vpcmpnequb	(%rsi, %rax), %ymm1, %k4 # mismatch between the chunks?
	add		%rax, %rsi		# make RSI correspond to RDI
	kmovd		%k4, %edx
	or		%r8d, %edx		# mismatch or NUL bytes
	jmp		.Lfind_return_value

	/* NUL or mismatch found within string head */
.Lend_in_head_swapped:
	kxnord		%k0, %k0, %k0		# k0 = -1
	kord		%k3, %k4, %k4		# mismatches or NUL bytes
	kaddd		%k0, %k4, %k3
	kxord		%k3, %k4, %k3		# mask of head until mismatch or NUL
	vpcmpnequb	(%rsi, %rcx), %ymm0, %k3{%k3} # redo comparison if no NUL within %k2
	add		%rax, %rdi		# restore head pointers
	add		%rcx, %rsi
	kord		%k3, %k4, %k4		# mismatch or NUL bytes
	kmovd		%k4, %edx
	jmp		.Lfind_return_value

	.size		mystrcmp, .-mystrcmp
