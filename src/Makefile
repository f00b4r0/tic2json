MAIN := tic2json
CFLAGS := -Wall -Os
TICVERSIONS := 01 02 01pme

# don't touch below this line

TICS := $(addprefix ticv,$(TICVERSIONS))
TICSDEFS := $(addprefix -DTICV,$(TICVERSIONS))
LEXSRCS := $(addsuffix .lex.c,$(TICS))

CFLAGS += $(TICSDEFS) -DBINNAME='"$(MAIN)"'

all:	$(MAIN)

%.lex.c: %.l %.tab.h
# The ideal size for the flex buffer is the length of the longest token expected, in bytes, plus a little more.
	flex --never-interactive -DYY_BUF_SIZE=128 -P$*yy -o$@ $<

%.tab.h %.tab.c: %.y
	bison -Wno-other -p $*yy -d $<

tic2json.o: $(addsuffix .tab.h,$(TICS))

$(MAIN):  $(addsuffix .tab.o,$(TICS)) $(addsuffix .lex.o,$(TICS)) tic.o tic2json.o

csources: $(LEXSRCS)

clean:
	$(RM) $(MAIN) *.output *.tab.h *.tab.c *.lex.c *.o
