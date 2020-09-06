%option yylineno

%{
	#include <stdio.h>
	#include <math.h>
	#include <stdbool.h>
	#include "y.tab.h"
	#include "parser_handler.h"


	extern YYSTYPE yylval; //YYSTYPE
	char buf[256];
	bool long_comment = false;

	/* This macro is used to record code line */
	#define CONCAT { strncat(buf, yytext, 256 - strlen(buf) - 1); }
	#define CLEAR { memset(buf, 0, sizeof(char) * 256); }

	extern int yyerror(char*);
	extern void dump_error();
	extern void dump_symbol();
	extern void clear_param_list();
	extern void insert_param_to_symbol_table();

	extern parser_node* parser;
	void comment(void);
	void rest(void);
%}

long_comment (\/\*([^*]|[\r\n]|(\*+([^*\/]|[\r\n])))*\*+\/)

%%
"#include"([ ]+)?((<(\\.|[^>])+>)|(\"(\\.|[^"])+\")) { CONCAT return HEADER; }
"#define"[ ]+[a-zA-z_][a-zA-z_0-9]* { CONCAT return DEFINE; }
"auto"|"register"|"static"|"extern"|"typedef" { CONCAT return storage_const; }
"void"|"char"|"short"|"int"|"long"|"float"|"double"|"signed"|"unsigned"|"string"|"bool" { CONCAT yylval.sVal = strdup(yytext); return type_const; }
"const"|"volatile" { CONCAT return qual_const; }
"enum" { CONCAT return enum_const; }
"case" { CONCAT return CASE; }	
"default" { CONCAT return DEFAULT; }
"if" { CONCAT return IF; }
"switch" { CONCAT return SWITCH; }
"else" { CONCAT return ELSE; }
"for" { CONCAT return FOR; }
"do" { CONCAT return DO; }
"while" { CONCAT return WHILE; }
"goto" { CONCAT return GOTO; }
"continue" { CONCAT return CONTINUE; }
"break" { CONCAT return BREAK; }
"struct"|"union" { CONCAT return struct_const; }
"return" { CONCAT return RETURN; }
"sizeof" { CONCAT return SIZEOF; }
"print" { CONCAT return PRINT; }
"true" { CONCAT return TRUE; }
"false" { CONCAT return FALSE; }
"||" { CONCAT return or_const; }
"&&" { CONCAT return and_const; }
"==" { CONCAT return equal_const; }
"!=" { CONCAT return not_equal_const; }
">=" { CONCAT return rel_re_const; }
"<=" { CONCAT return rel_le_const; }
"..." { CONCAT return param_const; }
">>"|"<<" { CONCAT return shift_const; }
"++" { CONCAT return inc_const; }
"--" { CONCAT return dec_const; }
"->" { CONCAT return point_const; }
";"|"="|"*"|"+"|"-"|"/"|","|"{"|"}"|"("|")"|"["|"]"|"?"|":"|"&"|"|"|"^"|"!"|"~"|"%"|"<"|">" { CONCAT return yytext[0]; }
">>="|"<<="|"&="|"^="|"|=" { CONCAT return PUNC; }
"+=" { CONCAT return add_assign; }
"-=" { CONCAT return minus_assign; }
"*=" { CONCAT return multiply_assign; }
"/=" { CONCAT return divide_assign; }
"%=" { CONCAT return module_assign; }
[0-9]+ { CONCAT yylval.iVal = atoi(yytext); return int_const; }
[0-9]+"."[0-9]+ { CONCAT yylval.fVal = atof(yytext); return float_const; }	
"'"."'"	{ CONCAT yylval.cVal = yytext[0]; return char_const; }
[a-zA-z_][a-zA-z_0-9]* { CONCAT yylval.sVal = strdup(yytext); return id; }
\"(\\.|[^\"])*\" { CONCAT yylval.sVal = strdup(yytext); return string; }
"//"(\\.|[^\n])* { CONCAT }
"/*" { CONCAT comment(); }
[ \t] { CONCAT }
[\n] {
	if (long_comment) {
		long_comment = false;
		printf("%s\n", buf);
	} else {
		if (strlen(buf) == 0) {
			printf("%d:\n", yylineno);
		} else {
			printf("%d: %s\n", yylineno, buf);
		}
	}
	if (parser->insert_param) {
		insert_param_to_symbol_table();
		parser->insert_param = false;
	} else {
		clear_param_list();
	}
	dump_error();
	memset(buf, 0, sizeof(char) * 256);
	if (parser->dump_symbol) {
		dump_symbol();
	}
}
%%

int yywrap(void)
{
	return 1;
}

void comment(void)
{
	long_comment = true;
	char c[2];
	memset(c, 0, sizeof(char) * 2);
	// add lineno first if the buf is not empty
	if (strlen(buf) != 0) {
		char temp[256];
		sprintf(temp, "%d: ", yylineno + 1);
		strncat(temp, buf, 256 - strlen(temp) - 1);
		strcpy(buf, temp);
	}

	while ((c[0] = input()) != 0) {
		strncat(buf, c, 256 - strlen(buf) - 1);
		// printf("%c", c);
		if (c[0] == '\n') {
			char linestring[16];
			sprintf(linestring, "%d: ", yylineno + 1);
			strncat(buf, linestring, 256 - strlen(buf) - 1);
			// printf("%d: ", yylineno + 1);
		}
		if (c[0] == '*') {
			while (1) {
				c[0] = input();
				strncat(buf, c, 256 - strlen(buf) - 1);
				// printf("%c", c);
				if (c[0] != '*') {
					break;
				}
			}
			if (c[0] == '/') {
				return;
			}
			if (c[0] == 0)
				break;
		}
	}
	yyerror("Unterminated comment");
}

void rest(void) {
	char c;
	while ((c = input()) != 0) {
		if (c == '\n') {
			break;
		}
		strncat(buf, &c, 256 - strlen(buf) - 1);
	}
	printf("%d: %s\n", yylineno, buf);
}
