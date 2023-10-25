#include <signal.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifndef PAGE_SIZE
#define PAGE_SIZE 16384
#endif

#define MAXDIGIT 18

long mystrtol(const char *restrict, char **restrict, int);

/* a signal handler that makes testpage writable and then returns */
static void *testpage;
static void
maptestpage(int sig)
{
	mprotect(testpage, PAGE_SIZE, PROT_READ|PROT_WRITE);
}

/*
 * Call mystrtol() on the given input with a page fault after the given
 * number of characters.  Print an error if the return value is not
 * equal to what strtol() says it should be.
 */
static void
test_mystrtol(const char *str, size_t off)
{
	struct sigaction sa;
	long expected, got;
	int res;
	char *data, *cpy, *endptr_expected = (char *)0xdeadbeef, *endptr_got = (char *)0xdeadbeef;

	data = mmap(NULL, 2*PAGE_SIZE, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
	if (data == MAP_FAILED) {
		perror("mmap");
		return;
	}

	cpy = data + PAGE_SIZE - off;
	strcpy(cpy, str);
	expected = strtol(cpy, &endptr_expected, 10);
	mprotect(data + PAGE_SIZE, PAGE_SIZE, PROT_NONE);
	testpage = data + PAGE_SIZE;

	sa.sa_handler = maptestpage;
	sa.sa_flags = SA_RESETHAND;
	res = sigaction(SIGSEGV, &sa, NULL);
	if (res != 0) {
		perror("sigaction");
		goto end;
	}

	got = mystrtol(cpy, &endptr_got, 10);
	signal(SIGSEGV, SIG_DFL);

	if (expected != got || endptr_expected != endptr_got)
		printf("FAIL\tmystrlcmp(%p \"%s\", endptr, 10) == %ld != %ld\nendptr == %p \"%s\" != %p \"%s\"\n",
		    cpy, cpy, got, expected, endptr_got, endptr_got, endptr_expected, endptr_expected);

end:	munmap(data, 2*PAGE_SIZE);
}

/*
 * Generate a random decimal integer with k digits and store it in buf.
 */
static void
random_number(char *buf, size_t len)
{
	size_t i;

	for (i = 0; i < len; i++)
		buf[i] = lrand48() % 10 + '0';

	buf[len] = '\0';
}

/*
 * Test the given number with all alignment offsets of up to n
 */
static void
test_all_offsets(char *buf, size_t n)
{
	size_t i;

	for (i = 0; i <= n; i++)
		test_mystrtol(buf, i);
}

/*
 * Test mystrtol() with random numbers of up to MAXDIGIT digits.
 */
static void
test_strtol(void)
{
	size_t i, j, k;
	char buf[MAXDIGIT+2];

	for (i = 1; i <= MAXDIGIT; i++) {
		random_number(buf+1, i);
		test_all_offsets(buf+1, i+1);
		buf[0] = '+';
		test_all_offsets(buf, i+2);
		buf[0] = '-';
		test_all_offsets(buf, i+2);
	}
}

int main()
{
	test_strtol();
}
