CFLAGS=-Wno-incompatible-pointer-types

%.o: %.c
	gcc -c  $(CFLAGS) $<

OBJ=hvl_replay.o hvl_tables.o main.o

hvl2stream: $(OBJ)
	gcc -o $@ $(CFLAGS) $(OBJ) -lm

.PHONY: clean
clean:
	rm -f *.o hvl2stream *~
