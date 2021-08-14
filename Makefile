all:	tic

tic:	tic.y tic.l
	bison -Wno-other -d tic.y
	flex -s tic.l
	$(CC) -Wall *.c -o $@

clean:
	$(RM) tic *.output *.tab.h *.tab.c *.yy.c
