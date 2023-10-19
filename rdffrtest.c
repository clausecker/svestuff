/* test the behaviour of rdffr with extending loads */

#include <assert.h>
#include <arm_sve.h>
#include <sys/mman.h>
#include <stdio.h>
#include <unistd.h>

int main()
{
	svuint16_t h;
	svuint8_t b;
	svbool_t p;
	size_t pagesize;
	char *buf;

	assert(svcntb() == 32);

	pagesize = sysconf(_SC_PAGESIZE);
	buf = mmap(NULL, 2*pagesize, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
	mprotect(buf + pagesize, pagesize, PROT_NONE);

	svsetffr();
	h = svldff1ub_u16(svptrue_b16(), buf + pagesize - 1);
	p = svrdffr();

	printf("h: %08x\n", *(uint32_t *)&p);

	svsetffr();
	b = svldff1_u8(svptrue_b8(), buf + pagesize - 1);
	p = svrdffr();

	printf("b: %08x\n", *(uint32_t *)&p);
}

