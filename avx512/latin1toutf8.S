	.section .rodata
	.align 4
.L0080:	.int		0x00800080
.L80c0:	.int		0x80c080c0

	.text
	.type		mylatin1_to_utf8, @function
	.globl		mylatin1_to_utf8

	// rdi: out
	// rsi: in
	// rdx: inlen
mylatin1_to_utf8:
	vpbroadcastd	.L0080(%rip), %zmm31
	vpbroadcastd	.L80c0(%rip), %zmm28
	vpternlogd	$0xff, %zmm30, %zmm30, %zmm30 // zmm30 = ffff ffff
	vpsrlw		$2, %zmm30, %zmm29	// zmm29 = 3fff 3fff
	vpaddw		%zmm31, %zmm31, %zmm27	// zmm27 = 0100 0100

	xor		%eax, %eax		// output length
	sub		$32, %rdx		// 32 bytes left to process?
	jb		1f

	.balign		16
0:	vpmovzxbw	(%rsi), %zmm0		// load 64 bytes of input as halfwords
	add		$32, %rsi		// advance to next chunk of input

	vpcmpnltuw	%zmm31, %zmm0, %k2	// 0x0080 <= zmm0?
	vpsrlw		$6, %zmm0, %zmm1	// 00000000 000000HG
	vpsllw		$8, %zmm0, %zmm2	// HGFEDCBA 00000000
	vpternlogd	$0xa8, %zmm29, %zmm2, %zmm1 // 00FEDCBA 000000HG  zmm1 = (zmm1|zmm2) & 0x3f3f
	vpaddw		%zmm28, %zmm1, %zmm0{%k2}   // 10FEDCBA 110000HG or 00000000 0GFEDCBA
	vpcmpnltub	%zmm27, %zmm0, %k3	// 01 if ASCII, 11 if 2 byte
	vpcompressb	%zmm0, (%rdi, %rax, 1){%k3} // store to destination

	kmovd		%k2, %ecx
	popcnt		%ecx, %ecx		// number of 2-byte characters processed this round
	lea		32(%rax, %rcx, 1), %rax	// advance outlen by number of bytes written
	sub		$32, %rdx		// 64 bytes left to process?
	jae		0b

	/* handle tail of 0--31 bytes */
1:	add		$32, %edx		// undo last subtraction
	jz		0f			// skip tail if empty

	mov		$-1, %ecx
	bzhi		%edx, %ecx, %ecx	// eax = 0xffffffff & (1 << edx) - 1
	kmovd		%ecx, %k1		// mask of valid words for next read

	vpmovzxbw	(%rsi), %zmm0{%k1}{z}	// load tail

	vpcmpnltuw	%zmm31, %zmm0, %k2{%k1}	// 0x0080 <= zmm0 and inside buffer?
	vpsrlw		$6, %zmm0, %zmm1	// 00000000 000000HG
	vpsllw		$8, %zmm0, %zmm2	// HGFEDCBA 00000000
	vpternlogd	$0xa8, %zmm29, %zmm2, %zmm1 // 00FEDCBA 000000HG  zmm1 = (zmm1|zmm2) & 0x3f3f
	vpaddw		%zmm28, %zmm1, %zmm0{%k2}   // 10FEDCBA 110000HG or 00000000 0GFEDCBA
	vpblendmw	%zmm27, %zmm30, %zmm1{%k1} // 0100 fo ASCII/2byte, FFFF behind end-of-buffer
	vpcmpnltub	%zmm1, %zmm0, %k3	// 01 if ASCII, 11 if 2 byte, 00 if behind buffer
	vpcompressb	%zmm0, (%rdi, %rax, 1){%k3} // store to destination

	kmovd		%k2, %ecx
	popcnt		%ecx, %ecx		// number of 2-byte characters processed this round
	add		%rdx, %rax		// one byte was written for each input byte
	add		%rcx, %rax		// and another byte for each 2-byte character
0:	ret
	.size		mylatin1_to_utf8, .-mylatin1_to_utf8
