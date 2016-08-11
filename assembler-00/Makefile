ASFLAGS=-g

.PHONY: clean rerun

all: main

run: all
	-./main

clean:
	rm -vf main *.o

rerun:
	rerun -p *.s -c -x make run
