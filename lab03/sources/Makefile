CFLAGS ?= -O2 -Wall -Wextra
objects = main.o output.o counter.o
pic_objects = output.pic.o counter.pic.o
programs = rdsu-args-objects rdsu-args-static rdsu-args-shared
libraries = librdsuargs.a librdsuargs.so
outputs = $(wildcard *.out)

.PHONY: all test clean distclean
.NOTPARALLEL: librdsuargs.a
.SECONDARY: output.o counter.o
all: $(programs)

$(objects) $(pic_objects): args.h

%.pic.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -c $< -o $@

librdsuargs.a(output.o counter.o):
librdsuargs.a: librdsuargs.a(output.o counter.o)

librdsuargs.so: $(pic_objects)
	$(CC) $(LDFLAGS) -shared -Wl,-soname,librdsuargs.so -o $@ $^ $(LDLIBS)

rdsu-args-objects: $(objects)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

rdsu-args-static: main.o librdsuargs.a
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

rdsu-args-shared: main.o librdsuargs.so
	$(CC) $(LDFLAGS) -o $@ main.o -L. -lrdsuargs $(LDLIBS)

test: all
	set -e; export LD_LIBRARY_PATH="$(CURDIR)"; \
	for program in $(programs); do \
	    ./$$program > $$program.zero.out 2>&1; \
	    ./$$program alpha > $$program.one.out 2>&1; \
	    ./$$program alpha beta gamma > $$program.three.out 2>&1; \
	done; \
	for mode in zero one three; do \
	    cmp rdsu-args-objects.$$mode.out rdsu-args-static.$$mode.out; \
	    cmp rdsu-args-objects.$$mode.out rdsu-args-shared.$$mode.out; \
	    cmp rdsu-args-static.$$mode.out rdsu-args-shared.$$mode.out; \
	done

clean:
	$(RM) $(objects) $(pic_objects)

distclean: clean
	$(RM) $(programs) $(libraries) $(outputs)
