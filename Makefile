all:	tic2json

%.lex.c: %.l %.tab.h
# The ideal size for the flex buffer is the length of the longest token expected, in bytes, plus a little more.
	flex -DYY_BUF_SIZE=128 -o$@ $<

%.tab.h %.tab.c: %.y
	bison -Wno-other -d $<

tic2json:	%: ticv02.tab.c ticv02.lex.c %.c
	$(CC) -DBINNAME='"$@"' -Os -Wall $^ -o $@

clean:
	$(RM) tic2json *.output *.tab.h *.tab.c *.lex.c

# disable implicit rules we don't want
%.c: %.y
%.c: %.l

