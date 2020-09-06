#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern int yylineno;
extern char buf[256];

typedef struct error_node {
	char* msg;
	int line;
	struct error_node* next;
} error_node;

error_node *error_list;

void insert_error(char* msg) {
	// create error node
	error_node* target = (error_node*)malloc(sizeof(error_node));
	target->msg = (char*)malloc(sizeof(char) * strlen(msg));
	strcpy(target->msg, msg);
	// insert the error node to error list
	if (!error_list) {
		error_list = target;
		return;
	}
	error_node* iter = error_list;
	while (iter->next) {
		iter = iter->next;
	}
	iter->next = target;
}

void dump_error() {
	if (!error_list) {
		return;
	}
	error_node* iter;
	error_node* prev;
	iter = error_list;
	prev = NULL;
	// loop all error node and output to the terminal
	while (iter) {
		printf("\n|-----------------------------------------------|\n");
		printf("| Error found in line %d: %s\n", yylineno, buf);
		printf("| %s\n", iter->msg);
		printf("|-----------------------------------------------|\n\n");
		// free the previous error node
		prev = iter;
		iter = iter->next;
		prev->next = NULL;
		free(prev->msg);
		free(prev);
	}
	error_list = NULL;
}
