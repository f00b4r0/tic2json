all:	tic

tic:	tic.y tic.l
	bison -Wno-other -d tic.y
# The ideal size for the flex buffer is the length of the longest token expected, in bytes, plus a little more.
	flex -DYY_BUF_SIZE=128 tic.l
	$(CC) -Os -Wall *.c -o $@

clean:
	$(RM) tic *.output *.tab.h *.tab.c *.yy.c
