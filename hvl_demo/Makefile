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

# Start of RAM code must be >= 6000
#_68K_START=6000
# Run in ROM (this address is a fix, do not change!)
_68K_START=800410

$(DEMO).o: gpu.o ../player/hively_player.bin

$(DEMO).cof: $(DEMO).o
	@$(RLN) -z -e -a $(_68K_START) x x -o $@ $<

$(DEMO).bin: $(DEMO).o
	@$(RLN) -rw -z -n -a $(_68K_START) x x -o $@ $<

$(DEMO).j64: $(DEMO).bin
	cp sbl.XXX  $@
	cat $< >> $@
	bzcat $(BJL_ROOT)/bin/allff.bin.bz2 >> $@
	truncate -s 1M $@

include Rules.launch

.ONESHELL:
.PHONY: clean
clean:
	rm -f *.o
	rm -f *.equ
	rm -f *~
	rm -f $(DEMO).bin

.ONESHELL:
.PHONY: real-clean
real-clean: clean
	rm -f  $(DEMO).j64
