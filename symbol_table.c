#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "parser_handler.h"

extern int yylineno;
extern parser_node* parser;
extern int yyerror(char*);

/* the definition of symbol node */
typedef struct symbol_node {
	char* name;
	int index;
	int entry_type;
	char data_type;
	int scope_level;
	char* pointer;
	char* formal_parameters;
	struct symbol_node* next;
} symbol_node;

typedef struct indexed_symbol_node {
	int index;
	struct symbol_node *content;
} indexed_symbol_node;

symbol_node* symbol_table;

/* the function to check the existence of particular symbol */
int lookup_symbol(char* name, bool current) {
	symbol_node* iter = symbol_table;
	if (!iter) {
		return 0;
	}
	if (current) {
		if (strcmp(iter->name, name) == 0 && iter->scope_level == parser->scope_level) {
			return 1;
		}
		while (iter->next) {
			iter = iter->next;
			if (strcmp(iter->name, name) == 0 && iter->scope_level == parser->scope_level) {
				return 1;
			}
		}
	} else {
		if (strcmp(iter->name, name) == 0) {
			return 1;
		}
		while (iter->next) {
			iter = iter->next;
			if (strcmp(iter->name, name) == 0) {
				return 1;
			}
		}
	}
	return 0;
}

indexed_symbol_node* search_symbol(int level, char* name) {
	if (level < 0) {
		return NULL;
	}
	symbol_node *iter = symbol_table;
	int index = 0;
	while(iter) {
		if (iter->scope_level != level) {
			iter = iter->next;
			continue;
		}
		if (strcmp(iter->name, name) == 0) {
			indexed_symbol_node *target = (indexed_symbol_node*)malloc(sizeof(indexed_symbol_node));
			target->index = index;
			target->content = iter;
			return target;
		}
		index++;
		iter = iter->next;
	}
	return search_symbol(level - 1, name);
}

/* the function to create symbol */
void create_symbol() {
	symbol_table = NULL;
}

/* the function to insert one symbol to symbol table */
void insert_symbol() {
	int check = lookup_symbol(parser->decl_name, true);
	if (check) {
		char msg[1024];
		sprintf(msg, "Redeclared %s %s", parser->entry_type == 1 ? "function" : "variable", parser->decl_name);
		yyerror(msg);
		return;
	}
	// create new symbol bode
	symbol_node* target = (symbol_node*)malloc(sizeof(symbol_node));
	target->index = parser->symbol_number++;
	target->name = (char*)malloc(sizeof(char) * strlen(parser->decl_name));
	strcpy(target->name, parser->decl_name);
	// if the entry type is parameter, then plus 1 to scope level
	if (parser->entry_type == 3) {
		target->scope_level = parser->scope_level + 1;
	} else {
		target->scope_level = parser->scope_level;
	}
	target->entry_type = parser->entry_type;
	target->data_type = parser->data_type;
	target->pointer = (char*)malloc(sizeof(char) * strlen(parser->data_type_pointer));
	target->next = NULL;
	strcpy(target->pointer, parser->data_type_pointer);
	// if the entry type is function, then record the formal parameters
	if (parser->entry_type == 1) {
		target->formal_parameters = (char*)malloc(sizeof(char) * strlen(parser->formal_parameters));
		strcpy(target->formal_parameters, parser->formal_parameters);
	} else {
		target->formal_parameters = (char*)malloc(sizeof(char));
		*target->formal_parameters = '\0';
	}
	// insert the symbol node to the symbol table
	if (!symbol_table) {
		symbol_table = target;
	} else {
		symbol_node* iter = symbol_table;
		while (iter->next) {
			iter = iter->next;
		}
		iter->next = target;
	}
	// reset the global data
	if (parser->entry_type == 1) {
		memset(parser->formal_parameters, 0, sizeof(char) * 1024);
		parser->formal_parameters_number = 0;
	}
	memset(parser->decl_name, 0, sizeof(char) * 256);
	parser->entry_type = 0;
	memset(parser->data_type_pointer, 0, sizeof(char) * 256);
}

/* the function to dump and clean all symbol in symbol table */
void dump_symbol() {
	if (!symbol_table) {
		return;
	}
	bool print_header = false;
	int index = 0;
	symbol_node* iter = symbol_table;
	while (iter) {
		if (iter->scope_level != parser->dump_scope_level) {
			iter = iter->next;
			continue;
		}
		if (!print_header) {
			printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
					"Index", "Name", "Kind", "Type", "Scope", "Attribute");
			print_header = true;
		}
		char entry_type[128];
		char data_type[128];
		memset(entry_type, 0, sizeof(char) * 128);
		memset(data_type, 0, sizeof(char) * 128);
		// append pointer infomation first
		strcpy(data_type, iter->pointer);
		// map the entry_type to string
		switch (iter->entry_type) {
			case 1:
				strcpy(entry_type, "function");
				break;
			case 2:
				strcpy(entry_type, "variable");
				break;
			case 3:
				strcpy(entry_type, "parameter");
				break;
		}
		char formal_parameters[1024] = {0};
		memset(formal_parameters, 0, sizeof(char) * 1024);
		if (strlen(iter->formal_parameters) > 0) {
			switch (iter->formal_parameters[0]) {
				case 'I':
					strcat(formal_parameters, "int");
					break;
				case 'F':
					strcat(formal_parameters, "float");
					break;
				case 'Z':
					strcat(formal_parameters, "bool");
					break;
				case 'S':
					strcat(formal_parameters, "string");
					break;
				case 'V':
					strcat(formal_parameters, "void");
					break;
			}

		}
		// map the formal parameters to string
		for (int i = 1 ; i < strlen(iter->formal_parameters); ++i) {
			switch (parser->formal_parameters[i]) {
				case 'I':
					strcat(formal_parameters, ", int");
					break;
				case 'F':
					strcat(formal_parameters, ", float");
					break;
				case 'Z':
					strcat(formal_parameters, ", bool");
					break;
				case 'S':
					strcat(formal_parameters, ", string");
					break;
				case 'V':
					strcat(formal_parameters, ", void");
					break;
			}
		}
		// map thet data type to string
		switch (iter->data_type) {
			case 'I':
				strcat(data_type, "int");
				break;
			case 'F':
				strcat(data_type, "float");
				break;
			case 'Z':
				strcat(data_type, "bool");
				break;
			case 'S':
				strcat(data_type, "string");
				break;
			case 'V':
				strcat(data_type, "void");
				break;
		}
		printf("%-10d%-10s%-12s%-10s%-10d",
				index++, iter->name, entry_type, data_type, iter->scope_level);
		if (strlen(iter->formal_parameters) != 0) {
			printf("%s\n", formal_parameters);
		} else {
			printf("\n");
		}
		iter = iter->next;
	}
	if (print_header) {
		printf("\n");
	}
	// remove and free all symbol nodes in max scope level
	iter = symbol_table;
	symbol_node* prev = NULL;
	// the operation to remove and free the node if the node is the symbol table head
	if (iter->scope_level == parser->dump_scope_level) {
		prev = symbol_table;
		symbol_table = symbol_table->next;
		iter = iter->next;
		free(prev);
	}
	while (iter) {
		if (iter->scope_level == parser->dump_scope_level) {
			symbol_node* target = iter;
			prev->next = iter->next;
			iter = iter->next;
			target->next = NULL;
			free(target);
			continue;
		}
		prev = iter;
		iter = iter->next;
	}
	// turn off dump switch
	parser->dump_symbol = false;
	parser->dump_scope_level = -1;
}

