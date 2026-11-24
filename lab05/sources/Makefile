CC ?= cc
WARN = -Wall -Wextra

.PHONY: all debug check clean
all: progression progression-debug progression-opt progression.o libprogression.so
debug: progression-debug

progression: progression.c
	$(CC) -no-pie -Wl,--build-id=sha1 -o $@ $<

progression-debug: progression.c
	$(CC) -O0 -g $(WARN) -no-pie -Wl,--build-id=sha1 -o $@ $<

progression-opt: progression.c
	$(CC) -O2 -g $(WARN) -no-pie -Wl,--build-id=sha1 -o $@ $<

progression.o: progression.c
	$(CC) -O0 -g $(WARN) -fPIC -c -o $@ $<

libprogression.so: progression.o
	$(CC) -shared -o $@ $<

check: progression-debug
	bash ../check/check-gdb.sh

clean:
	$(RM) progression progression-debug progression-opt progression.o libprogression.so
