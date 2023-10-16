#include <stdio.h>

extern long mystrtol(const char *restrict buf, char **restrict endptr, int base);

int main(int argc, char *argv[])
{
	long n;
	char *endptr;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s string\n", argv[0]);

		return (0);
	}

	n = mystrtol(argv[1], &endptr, 10);

	printf("strtol(%p \"%s\", &endptr, 10) = %ld\nendptr = %p \"%s\"\n", argv[1], argv[1], n, endptr, endptr);
}
