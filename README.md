# access2tsv
Fast Apache Common log to TSV converter

This tool converts Apache's common log format to a tab-separated-values format, for easier processing using tools like cut, awk, and sort. This includes converting the timestamp to a more ISO-8601-like form: `YYYY-MM-DDTHH:MM:SS+ZZZZ`

The main motivation for a separate tool is that I was dealing with very large access logs that also logged the Cookie header. The Cookie header is enclosed in quotes, but also contains escaped quotes, making basic regex parsing difficult. access2tsv removes the enclosing quotes and unescapes any quotes inside each field.

I haven't worked with optimizing C code, so all the improvements I've made were through trial and error. It's likely that there are better, faster tools for this. But this one is mine, and if anything it was a fun project for me.

# Usage
`access2tsv [in-file [out-file]]`  
When called with no args, read from stdin and write to stdout  
When called with one arg, read from `in-file` and write to stdout  
When called with two args, read from `in-file` and write to `out-file`

# Building
Requires [flex](https://github.com/westes/flex) and a C compiler (I've tried GCC and clang).

GNU make has rules that can generate an executable from a Lex file. You can run:
```
make access2tsv CFLAGS=-O3
```
in the same directory as `access2tsv.l` and it'll build the executable. The included Makefile basically does the same.

# Behavior/Limitations
This won't recognize Windows-style newlines (\r\n), but modifying it to do so should be fairly easy.

If you feed access2tsv the following line:
```
192.168.0.1 - - [10/Mar/2020:15:03:38 -0600] "GET /hello/world HTTP/1.1" 200 5823 "http://192.168.0.1/example/referrer" "User-Agent/1.0 (example; like Gecko)" "cookie1=example; quotes=\"headache\""
```
you should receive:
```
192.168.0.1 -	- 2020-03-10T15:03:38-0600	GET /hello/world HTTP/1.1	200	5823	http://192.168.0.1/example/referrer	User-Agent/1.0 (example; like Gecko)	cookie1=example; quotes="headache"
```

The fields can be in any order, but the timestamp must follow the same format: `[DD/Mon/YYYY:HH:MM:SS +ZZZZ]`. It'll only recognize the standard English three-letter month abbreviations, and the 2nd and 3rd letter must be lower-case. The reason for this is that the code does some simple math on the ASCII values in order to get a string index that gives the number conversion.

## Mismatched quotes
I've come across Tomcat logs that don't properly escape quotes. This will cause access2tsv to produce a line with mangled fields, but it shouldn't affect any following good lines. If there's an odd number of quotes in the whole line, access2tsv will print a trailing `	!!!!` so you can filter those out with tools like grep.

In:
```
192.168.0.1 - - [10/Mar/2020:15:03:38 -0600] "GET /hello/world HTTP/1.1" 200 5823 "http://192.168.0.1/example/referrer" "User-Agent/1.0 (evil-quote; 7" tablet, yes Ive seen a screen size in the UA)" "quotes="just the worst"; user=test; hello=world"
```
Out:
```
192.168.0.1	-	-	2020-03-10T15:03:38-0600	GET /hello/world HTTP/1.1	200	5823	http://192.168.0.1/example/referrer	User-Agent/1.0 (evil-quote; 7	tablet,	yes	Ive	seen	a	screen	size	in	the	UA) quotes=just the worst;	user=test;	hello=world	!!!!
```
The line is clearly no longer usable, thus my rationale for adding the exclamation points at the end.
