# Makefile for generating the access2tsv Apache log reformatter
#
# Most of the work is done by GNU make's built-in rules, which assume
# that prog.l --> prog.c --> prog.o --> prog
#
# I've found clang 5.0.1 produces slightly faster binaries than
# gcc 6.4.0 on my Cygwin install. If you have it, use CC=clang
#
# -tkiselev

CFLAGS=-O3 -pipe

all: access2tsv

clean:
	rm -f *.c *.o access2tsv access2tsv.exe
