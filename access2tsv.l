/* Apache access log to tab-separated-values converter
 *
 * To build, you need:
 * Flex (https://github.com/westes/flex)
 * GCC, clang, or other C compiler.
 *
 * GNU Make has built-in rules that know about LEX programs.
 * You can just drop this in a folder and run:
 *
 *     make access2tsv CFLAGS=-O3
 *
 *
 * In the interest of speed, this program assumes input is valid and
 * well-formed, and will produce undefined behavior if it isn't.
 * Mis-quoted strings may produce a garbage line, but should no longer
 * crash the program entirely.
 *
 * Things I've tried to make this faster:
 *   - using strptime to parse the timestamp (around 16% slower)
 *   - printing the hour-minute-second and timezone directly (slightly slower)
 *   - earlier version used a date struct of char[]s and fprintf (around 10% slower)
 *
 * -tkiselev
 */

/* Most of these options trade program size for speed */
%option nomain noyywrap 8bit full read align

%{
char* get_month (const char *str);
%}

%x STR DATE
%%
%{
/* I'll be repeatedly modifying this string in-place, then printing.
 */
static char tstamp[] = "0000-00-00T00:00:00-0000";
%}

[^ \"\[]+/[ ]   ECHO;               /* Print non-quoted field that's followed by a trailing space */
[ ]             putc('\t', yyout);  /* If not in a special ruleset, convert spaces to tabs */
\n              ECHO;               /* Preserve newlines */

\"              BEGIN(STR);         /* Start parsing a quoted field, switch to different set of rules */
<STR>[^\\\"\n]+ ECHO;               /* Print anything that's not a backslash, quote, or newline */
<STR>\\[\\\"]   putc(yytext[1], yyout);   /* Un-escape quotes and slashes */
<STR>\"         BEGIN(INITIAL);     /* Found the endquote, return to initial parsing rules */
<STR>\n         {                   /* Match newline, means there's been a misquoted string. Emit warning.*/
                        fputs("\t!!!!\n", yyout);
                        BEGIN(INITIAL);
                } 
"["             BEGIN(DATE);        /* Start parsing the timestamp */
<DATE>{
([0-9]{2}:){2}[0-9]{2}  memcpy(tstamp + 11, yytext, 8);    /* Match the time, HH:MM:SS, and save it */
[0-9][0-9]/\/           memcpy(tstamp + 8, yytext, 2);     /* The day, 2 digits followed by / */
[0-9]{4}/:              memcpy(tstamp, yytext, 4);         /* The year, 4 digits followed by : */
[A-Z][a-z][a-z]         memcpy(tstamp + 5, get_month(yytext), 2);  /* Find the month abbreviation, use hash function to convert */
[+-][0-9]{4}            memcpy(tstamp + 19, yytext, 5);    /* Save the timezone string */
[/: ]                                                      /* Discard the timestamp delimiters */
"]"             {       /* Print the collected date in ISO format, and return to normal parsing rules */
                        fwrite(tstamp, sizeof(char), 24, yyout);
                        BEGIN(INITIAL);
                }
}
%%
/**
 * I discovered that a three-letter month abbreviation can be uniquely
 * identified by the sum of the numeric values of the 2nd and 3rd letters.
 *
 * Add up the values for the 2nd and 3rd letters, subtract the lowest possible
 * sum, then use that to index into a string containing the abbreviations at
 * the correct positions. We use memcpy elsewhere to only get the two chars
 * that we need.
 *
 * This used to be a large block of gperf generated code that basically did
 * the same thing, but with a couple extra array lookups. This is *slightly*
 * faster.
 */
char* get_month (register const char *str) {
    static char* monthstr = "0212000000000000010000000300090010000005000800000000070406001100";
    return monthstr + (((unsigned char)str[1] + (unsigned char)str[2] - 199) * 2);
}

/* Main method.
 *
 * 0 args: read stdin, write stdout
 * 1 arg:  read file, write stdout
 * 2 args: read file, write file
 */

int main (int argc, char** argv) {
    ++argv, --argc;
    yyout = stdout;
    if (argc > 1)
        yyout = fopen(argv[1], "w");
    if (argc > 0)
        yyin = fopen(argv[0], "r");
    else
        yyin = stdin;
    yylex();
}
