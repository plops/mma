CC=gcc
CFLAGS=-Wall -Wextra -g -I/usr/local/include -pthread
IPMSLIB=/home/martin/mma-essentials-0209/
LDFLAGS=-landor -lglfw -L$(IPMSLIB) -lIPMS_SLM -Wl,-rpath=$(IPMSLIB)
combine:

libcombine.so: combine.c
	gcc $(CFLAGS) -DNOEXEC -fPIC -c combine.c && gcc -DNOEXEC -shared -Wl,-soname,libcombine.so $(LDFLAGS) -o libcombine.so combine.o
