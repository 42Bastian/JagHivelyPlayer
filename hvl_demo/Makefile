DEMO=hvl_demo

OS:=$(shell uname -s)

TJASS= lyxass
RMAC= rmac
RLN= rln

_68KFLAGS=-4 ~oall -i$(BJL_ROOT)
TJFLAGS= -w -s

ifdef DEBUG
_68KFLAGS+= -DDEBUG
endif

ifdef SKUNK
_68KFLAGS+= -DSKUNK
endif

ALL: $(DEMO).cof $(DEMO).j64

%.o	: %.js
	$(TJASS) $(TJFLAGS) $<

%.o	: %.S
	$(RMAC) $(_68KFLAGS) $< -o $@

hively_player.bin: hively_player_v21.S
	rmac -4 -fb -u -i$(BJL_ROOT)/68k_inc $<
	rln -z -n -a f1b000 x x -o $@ hively_player_v21.o

$(DEMO).o: gpu.o ../player/hively_player.bin

$(DEMO).cof: $(DEMO).o
	@$(RLN) -z -e -a 4000 x x -o $@ $<

$(DEMO).rom: $(DEMO).o
	@$(RLN) -rw -z -n -a 802000 x x -o $@ $<

.ONESHELL:
$(DEMO).j64: $(DEMO).rom
	@cat $(BJL_ROOT)/bin/Univ.bin $< >$@
	cat $< >> $@
	bzcat $(BJL_ROOT)/bin/allff.bin.bz2 >> $@
	truncate -s 128K $@


include Rules.launch

.ONESHELL:
.PHONY: clean
clean:
	rm -f *.o
	rm -f *.equ
	rm -f *~
	rm -f *.rom *.abs
