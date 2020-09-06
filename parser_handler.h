#ifndef PARSERNODE_H
#define PARSERNODE_H
#include <stdbool.h>

typedef struct param_node {
	char name[256];
	int data_type;
	struct param_node* next;
} param_node;

typedef struct parse_node {
	char content[1024];
	struct parse_node *next;
} parse_node;

typedef struct parser_node {

	int scope_level;
	int symbol_number;

	int entry_type;
	int data_type;
	char data_type_pointer[256];
	char decl_name[256];
	bool declaration_type;
	struct initValue {
		bool init;
		char type;
		union {
			float f;
			char *s;
		} v;
	} val;

	char keep_function_name[256];
	char keep_function_type;
	char keep_init_variable_name[256];
	char formal_parameters[1024];
	int formal_parameters_number;

	char variable_reference[256];
	char function_reference[256];
	
	bool success;
	bool dump_symbol;
	bool dump_parse_result;
	bool insert_param;
	bool assigning;
	int assign_type;
	int operator_type;
	int relation_type;
	int if_num[1000];
	int while_num[1000];
	int current_exit_if[1000];
	int postfix_type;
	bool else_exist;
	bool while_stat;
	int dump_scope_level;
	int current_argument;
	int error_num;

	parse_node* parse_result;
} parser_node;

#endif

