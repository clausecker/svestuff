#include <stdio.h>
#include <string.h>

char *mystrncpy(const char *restrict, const char *restrict, size_t);

static void check_strncpy(char *dest, const char *src, size_t len)
{
	size_t i, srclen;
	const char *res;
	const char *fail = NULL;

	memset(dest, 0xee, len);

	/* write sentinels */
	dest[-1] = '{';
	dest[len] = '}';

	res = mystrncpy(dest, src, len);
	srclen = strnlen(src, len);

	if (dest[-1] != '{')
		fail = "start sentinel overwritten";
	else if (dest[len] != '}')
		fail = "end sentinel overwritten";
	else if (strncmp(src, dest, len) != 0)
		fail = "string not copied correctly";
	else if (res != dest)
		fail = "incorrect return value";
	else for (i = srclen; i < len; i++)
		if (dest[i] != '\0') {
			fail = "incomplete NUL padding";
			break;
		}

	if (fail) {
		printf("test case failed: %s\n", fail);
		printf("strncpy(%p \"%s\", %p \"%s\", %zu) = %p\n",
			dest, dest, src, src, len, res);
	}
}

static void
testcase(char *dest, char *src, size_t destlen, size_t srclen)
{
	size_t i;

	src[-1] = '(';
	src[srclen] = '\0';
	src[srclen+1] = ')';

	for (i = 0; i < srclen; i++)
		src[i] = '0' + i;

	check_strncpy(dest, src, destlen);
}

extern int
main()
{
	size_t srcalign, destalign, srclen, destlen;
	char src[15+3+64];
	char dest[15+2+64];

	for (srcalign = 0; srcalign < 16; srcalign++)
		for (destalign = 0; destalign < 16; destalign++)
			for (srclen = 0; srclen < 64; srclen++)
				for (destlen = 0; destlen < 64; destlen++)
					testcase(dest+destalign+1, src+srcalign+1, destlen, srclen);
}
