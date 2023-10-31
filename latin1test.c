#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

extern size_t mylatin1_to_utf8(char *out, char *in, size_t inlen);

/*
 * Dump memory in hexadecimal
 */
static void
dumpmem(const char *id, const char *buf, size_t len)
{
	const char *start, *end, *i;
	int j;

	start = (char *)((uintptr_t)buf & ~0xf);
	end = (char *)((uintptr_t)buf + len + 0xf & ~0xf);

	printf("\n<%s>:\n", id);

	for (i = start, j = 0; i < end; i++) {
		if (j == 0)
			printf("%p ", i);

		j = j + 1 & 0xf;

		if (buf <= i && i < buf + len)
			printf(" %02x", (unsigned char)*i);
		else
			printf("   ");

		if (j == 0)
			putchar('\n');
	}
}

static size_t
reflatin1_to_utf8(char *out, char *in, size_t inlen)
{
	size_t i, o = 0;
	unsigned char *buf = (unsigned char *)in;

	for (i = 0; i < inlen; i++)
		if (buf[i] <= 0x7f)
			out[o++] = buf[i];
		else {
			out[o++] = buf[i] >> 6 | 0xc0;
			out[o++] = buf[i] & ~0x40;
		}

	return (o);
}

static void
test_latin1_to_utf8(size_t len, long iters, const short seed[3])
{
	long i;
	size_t j, reflen, outlen;
	char *in, *out, *ref;
	short xseed[3];

	in = malloc(len);
	if (in == NULL) {
		perror("malloc");
		exit(EXIT_FAILURE);
	}

	out = calloc(2, len);
	if (out == NULL) {
		perror("calloc");
		exit(EXIT_FAILURE);
	}

	ref = calloc(2, len);
	if (ref == NULL) {
		perror("calloc");
		exit(EXIT_FAILURE);
	}

	memcpy(xseed, seed, sizeof xseed);

	for (i = 0; i < iters; i++) {
		for (j = 0; j < len; j++)
			in[j] = nrand48(xseed);

		reflen = reflatin1_to_utf8(ref, in, len);
		outlen = mylatin1_to_utf8(out, in, len);

		if (reflen != outlen || memcmp(ref, out, reflen) != 0) {
			outlen = mylatin1_to_utf8(out, in, len);

			printf("len = %zd, in = %p, out_ref = %zu, out_my = %zu\n",
			    len, (void *)in, reflen, outlen);
			dumpmem("in", in, len);
			dumpmem("out_ref", ref, reflen);
			dumpmem("out_my", out, outlen);
		}
	}

	free(ref);
	free(out);
	free(in);
}

static short *
makeseed(size_t i, long j)
{
	static short seed[3];

	seed[0] = 0x1234;
	seed[1] = i;
	seed[2] = j;

	/* make initial draws more random */
	nrand48(seed);
	nrand48(seed);
	nrand48(seed);

	return (seed);
}

extern int
main()
{
	size_t i;

	test_latin1_to_utf8(0, 1, makeseed(0, 0));
	test_latin1_to_utf8(1, 16, makeseed(1, 16));
	test_latin1_to_utf8(2, 256, makeseed(1, 256));

	for (i = 3; i < 128; i++)
		test_latin1_to_utf8(i, 4096, makeseed(i, 4096));
}
