%{
	#include <stdio.h>
	#include <string.h>
	#include <stdbool.h>
	#include "y.tab.h"
	#include "parser_handler.h"

	#include "symbol_table.c"
	#include "error_handler.c"
	#include "parser_handler.c"

	int yylex(void);
	int yyerror(char *s);
	int test = 0;
	extern int yylineno;
	extern char buf[256];
	extern FILE* yyin;
	extern void rest(void);

	parser_node* parser;
	param_node* param_list;
	
	void insert_temp_param (char*, char);
	void clear_param_list();
	void insert_param_to_symbol_table();

%}

%token int_const char_const float_const id string enumeration_const storage_const type_const qual_const struct_const enum_const DEFINE
%token TRUE FALSE PRINT IF FOR DO WHILE BREAK SWITCH CONTINUE RETURN CASE DEFAULT GOTO SIZEOF PUNC or_const and_const eq_const shift_const rel_const inc_const
%token point_const param_const ELSE HEADER
%token add_assign minus_assign multiply_assign divide_assign module_assign
%token equal_const not_equal_const rel_le_const rel_re_const
%token dec_const
%left '+' '-'
%left '*' '/'
%nonassoc "then"
%nonassoc ELSE
%expect 6

%union 	{
	int iVal;
	float fVal;
	char *sVal;
	char cVal;
}
%type <iVal> int_const
%type <fVal> float_const
%type <cVal> char_const
%type <sVal> id string type_const 

%start program_unit
%%
program_unit:		HEADER program_unit                               
			| DEFINE primary_exp program_unit                 	
			| translation_unit									
			;
translation_unit:	external_decl 									
			| translation_unit external_decl					
			;
external_decl: 		function_definition { 
	     			memset(parser->decl_name, 0, sizeof(char) * 256);
				strcpy(parser->decl_name, parser->keep_function_name);
				parser->data_type = parser->keep_function_type;

				int check = lookup_symbol(parser->decl_name, true);
				if (!check) {
	     				// insert function declaration
					parser->entry_type = 1;
					insert_symbol();
				}
			}
			| decl { 	
				if (parser->declaration_type) {
					parser->entry_type = 1;
					memset(parser->decl_name, 0, sizeof(char) * 256);
					strcpy(parser->decl_name, parser->keep_function_name);
					parser->data_type = parser->keep_function_type;
					parser->declaration_type = false;
				} else {
					// insert_symbol();
				}
			}
			;
function_definition: 	decl_specs declarator decl_list { 
		   		parser->insert_param = true;
				function_parse_output_dec();	
			} compound_stat { result_push_back(".end method"); }
			| declarator decl_list { 
				parser->insert_param = true;
				function_parse_output_dec();	
			} compound_stat { result_push_back(".end method"); }
			| decl_specs declarator {
				parser->insert_param = true;
				function_parse_output_dec();	
			} compound_stat { result_push_back(".end method"); }
			| declarator {
				parser->insert_param = true;
				function_parse_output_dec();	
			} compound_stat { result_push_back(".end method"); }
			;
decl: 			decl_specs init_declarator_list ';'
			| decl_specs ';'
			;
decl_list: 		decl 
			| decl_list decl
			;
decl_specs: 		storage_class_spec decl_specs
			| storage_class_spec
			| type_spec decl_specs								
			| type_spec 										
			| type_qualifier decl_specs
			| type_qualifier
			;
storage_class_spec: 	storage_const
			;
type_spec: 		type_const {
				if (strcmp(yylval.sVal, "int") == 0) { parser->data_type = 'I'; }
				if (strcmp(yylval.sVal, "float") == 0) { parser->data_type = 'F'; }
				if (strcmp(yylval.sVal, "bool") == 0) { parser->data_type = 'Z'; }
				if (strcmp(yylval.sVal, "string") == 0) { parser->data_type = 'S'; }
				if (strcmp(yylval.sVal, "void") == 0) { parser->data_type = 'V'; }
			}
			| struct_or_union_spec
			| enum_spec
			| typedef_name
			;
type_qualifier: 	qual_const
			;
struct_or_union_spec: 	struct_or_union id '{' struct_decl_list '}'
			| struct_or_union '{' struct_decl_list '}'
			| struct_or_union id
			;
struct_or_union: 	struct_const
			;
struct_decl_list: 	struct_decl
			| struct_decl_list struct_decl
			;
init_declarator_list: 	init_declarator
			| init_declarator_list ',' init_declarator
			;
init_declarator: 	declarator {
	     			// insert variable declaration
				parser->entry_type = 2;
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				insert_symbol();
				// according LHS variable datatype to store the data
				if (parser->scope_level > 0) {
					indexed_symbol_node* target = search_symbol(parser->scope_level, parser->keep_init_variable_name);
					char temp[1024] = {0};
					memset(temp, 0, sizeof(char) * 1024);
					switch (target->content->data_type) {
						case 'I':
							result_push_back("ldc 0");
							sprintf(temp, "istore %d", target->index);
							break;
						case 'F':
							result_push_back("ldc 0.0");
							sprintf(temp, "fstore %d", target->index);
							break;
						case 'Z':
							result_push_back("ldc 0");
							sprintf(temp, "istore %d", target->index);
							break;
						case 'S':
							result_push_back("ldc \"\"");
							sprintf(temp, "astore %d", target->index);
							break;
					}
					result_push_back(temp);
				}
				global_variable_parse_output();
				parser->assigning = false;
	       		}
			| declarator {
	     			// insert variable declaration
				parser->entry_type = 2;
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				insert_symbol();
			} '=' {
				parser->assigning = true;
		   		parser->assign_type = 0;	
			} initializer {
				// according LHS variable datatype to store the data
				if (parser->scope_level > 0) {
					indexed_symbol_node* target = search_symbol(parser->scope_level, parser->keep_init_variable_name);
					if (target) {
						if (parser->postfix_type == 0) {
							result_push_back("ldc -1.0");
							result_push_back("fadd");
						} else if (parser->postfix_type == 1) {
							result_push_back("ldc 1.0");
							result_push_back("fadd");
						}
						char temp[1024] = {0};
						memset(temp, 0, sizeof(char) * 1024);
						switch (target->content->data_type) {
							case 'I':
								if (parser->operator_type != 4) {
									result_push_back("f2i");
								}
								sprintf(temp, "istore %d", target->index);
								break;
							case 'F':
								if (strlen(parser->function_reference) > 0 && parser->operator_type == -1) {
									indexed_symbol_node *function_node = search_symbol(parser->scope_level, parser->function_reference);
									if (function_node) {
										if (function_node->content->data_type == 'I') {
											result_push_back("i2f");
										}
									}
								}
								if (parser->operator_type == 4) {
									result_push_back("i2f");
								}
								sprintf(temp, "fstore %d", target->index);
								break;
							case 'Z':
								sprintf(temp, "istore %d", target->index);
								break;
							case 'S':
								sprintf(temp, "astore %d", target->index);
								break;
						}
						result_push_back(temp);
					}
				}
				global_variable_parse_output();
				parser->assigning = false;
				parser->assign_type = parser->operator_type = parser->postfix_type = -1;
			}
			;
struct_decl: 		spec_qualifier_list struct_declarator_list ';'
			;
spec_qualifier_list: 	type_spec spec_qualifier_list
			| type_spec
			| type_qualifier spec_qualifier_list
			| type_qualifier
			;
struct_declarator_list: struct_declarator
			| struct_declarator_list ',' struct_declarator
			;
struct_declarator: 	declarator
			| declarator ':' const_exp
			| ':' const_exp
			;
enum_spec: 		enum_const id '{' enumerator_list '}'
			| enum_const '{' enumerator_list '}'
			| enum_const id
			;
enumerator_list:	enumerator
			| enumerator_list ',' enumerator
			;
enumerator: 		id
			| id '=' const_exp
			;
declarator: 		pointer direct_declarator
			| direct_declarator
			;
direct_declarator: 	id {
	     			// variable declaration
				parser->entry_type = 2;
		 		memset(parser->decl_name, 0, sizeof(char) * 256);
				strcpy(parser->decl_name, yylval.sVal);
			}
			| '(' declarator ')'
			| direct_declarator '[' const_exp ']'
			| direct_declarator '['	']'
			| direct_declarator  '(' { 
				printf("test2\n");
				parser->declaration_type = true;
				// keep the function declaration if there is parameters
				strcpy(parser->keep_function_name, parser->decl_name);
				parser->keep_function_type = parser->data_type;
				memset(parser->decl_name, 0, sizeof(char) * 256);
				parser->data_type = '\0';
			} param_type_list {
				parser->formal_parameters_number = 0; 
			} ')' 			
			| direct_declarator '(' { 
				// function declaration
				parser->declaration_type = true;
				// keep the function declaration if there is parameters
				strcpy(parser->keep_function_name, parser->decl_name);
				parser->keep_function_type = parser->data_type;
				memset(parser->decl_name, 0, sizeof(char) * 256);
				parser->data_type = '\0';
			} id_list ')'
			| direct_declarator '(' { 
				// function declaration
				parser->declaration_type = true;
				// keep the function declaration if there is parameters
				strcpy(parser->keep_function_name, parser->decl_name);
				parser->keep_function_type = parser->data_type;
				memset(parser->decl_name, 0, sizeof(char) * 256);
				parser->data_type = '\0';
			} ')' 							
			;
pointer:		'*'  type_qualifier_list { strcat(parser->data_type_pointer, "*"); }
			|'*' { strcat(parser->data_type_pointer, "*"); }
			| '*' type_qualifier_list { strcat(parser->data_type_pointer, "*"); } pointer
			| '*' { strcat(parser->data_type_pointer, "*"); } pointer
			;
type_qualifier_list: 	type_qualifier
			| type_qualifier_list type_qualifier
			;
param_type_list: 	param_list
	       		| param_list ',' param_const
			;
param_list: 		param_decl {
	  			parser->entry_type = 3;
				if (strlen(parser->keep_function_name) > 0 && !lookup_symbol(parser->keep_function_name, true)) {
					parser->formal_parameters[strlen(parser->formal_parameters)] = parser->data_type;
					parser->formal_parameters_number++;
				}
				insert_temp_param(parser->decl_name, parser->data_type);
			}
	  		| param_list ',' param_decl {
	  			parser->entry_type = 3;
				if (strlen(parser->keep_function_name) > 0 && !lookup_symbol(parser->keep_function_name, true)) {
					parser->formal_parameters[strlen(parser->formal_parameters)] = parser->data_type;
					parser->formal_parameters_number++;
				}
				insert_temp_param(parser->decl_name, parser->data_type);
			}
			;
param_decl: 		decl_specs  declarator
			| decl_specs abstract_declarator
			| decl_specs
			;
id_list: 		id
			| id_list ',' id
			;
initializer: 		assignment_exp
			| '{' initializer_list '}'
			| '{' initializer_list ',' '}'
			;
initializer_list: 	initializer
			| initializer_list ',' initializer
			;
type_name: 		spec_qualifier_list abstract_declarator
			| spec_qualifier_list
			;
abstract_declarator: 	pointer
			| pointer direct_abstract_declarator
			|	direct_abstract_declarator
			;
direct_abstract_declarator: '(' abstract_declarator ')'
			| direct_abstract_declarator '[' const_exp ']'
			| '[' const_exp ']'
			| direct_abstract_declarator '[' ']'
			| '[' ']'
			| direct_abstract_declarator '(' param_type_list ')'
			| '(' param_type_list ')'
			| direct_abstract_declarator '(' ')'
			| '(' ')'
			;
typedef_name:		't'
			;
stat: 			labeled_stat 									      	
			| exp_stat 											  	
			| compound_stat  	
			| selection_stat { parser->if_num[parser->scope_level]++; } 
			| iteration_stat
			| jump_stat
			| decl_list
			;
labeled_stat: 		id ':' stat
			| CASE const_exp ':' stat
			| DEFAULT ':' stat
			;
exp_stat: 		exp {
				if (parser->postfix_type != -1) {
					indexed_symbol_node *target = search_symbol(parser->scope_level, yylval.sVal);
					if (target) {
						char temp[1024] = {0};
						memset(temp, 0, sizeof(char) * 1024);
						switch (target->content->data_type) {
							case 'I':
								result_push_back("f2i");
								sprintf(temp, "istore %d", target->index);
								break;
							case 'F':
								sprintf(temp, "fstore %d", target->index);
								break;
						}
						result_push_back(temp);
					}
					parser->postfix_type = -1;
				}
			}';'
			| ';'
			;
compound_stat: 		'{' { insert_param_to_symbol_table(); parser->scope_level++; } stat_list '}' { parser->dump_symbol = true; parser->dump_scope_level = parser->scope_level;  parser->scope_level--; }
			| '{' { insert_param_to_symbol_table(); parser->scope_level++; } '}' { parser->dump_symbol = true; parser->dump_scope_level = parser->scope_level; parser->scope_level--; }
			;
stat_list: 		stat
			| stat_list stat  										
			;
selection_stat: 	IF '(' exp ')' stat {	
	      			char temp[1024] = {0};
				memset(temp, 0, sizeof(char) * 1024);
				printf("%d\n", parser->if_num[parser->scope_level]);
				if (parser->current_exit_if[parser->scope_level] == -1) {
					parser->current_exit_if[parser->scope_level] = parser->if_num[parser->scope_level];
				}
				sprintf(temp, "Exit_%d_%d:", parser->scope_level, parser->current_exit_if[parser->scope_level]);
				result_push_back(temp);
				memset(temp, 0, sizeof(char) * 1024);
				sprintf(temp, "Label_%d_%d:", parser->scope_level, parser->if_num[parser->scope_level]);
				result_push_back(temp);

			}  %prec "then"
			| IF '(' exp ')' stat ELSE {
				parser->else_exist = true;
	      			char temp[1024] = {0};
				memset(temp, 0, sizeof(char) * 1024);
				if (parser->current_exit_if[parser->scope_level] == -1) {
					parser->current_exit_if[parser->scope_level] = parser->if_num[parser->scope_level];
				}

				sprintf(temp, "goto Exit_%d_%d", parser->scope_level, parser->current_exit_if[parser->scope_level]);
				result_push_back(temp);

				memset(temp, 0, sizeof(char) * 1024);
				sprintf(temp, "Label_%d_%d:", parser->scope_level, parser->if_num[parser->scope_level]);
				result_push_back(temp);
			} stat {
				if (parser->current_exit_if[parser->scope_level] > -1) {
					char temp[1024] = {0};
					memset(temp, 0, sizeof(char) * 1024);
					sprintf(temp, "Exit_%d_%d:", parser->scope_level, parser->current_exit_if[parser->scope_level]);
					result_push_back(temp);
					parser->current_exit_if[parser->scope_level] = -1;
				}

			}
			| SWITCH '(' exp ')' stat
			;
iteration_stat: 	WHILE {
	      			parser->while_stat = true;
	      			parser->while_num[parser->scope_level]++;
	      			char temp[1024] = {0};
				memset(temp, 0, sizeof(char) * 1024);
				sprintf(temp, "WLabel_%d_%d:", parser->scope_level, parser->while_num[parser->scope_level]);
				result_push_back(temp);
	      		} '(' exp ')' { parser->while_stat = false; } stat {
				char temp[1024] = {0};
				memset(temp, 0, sizeof(char) * 1024);
				sprintf(temp, "goto WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level] - 1);
				result_push_back(temp);
				
				memset(temp, 0, sizeof(char) * 1024);
				sprintf(temp, "WLabel_%d_%d:", parser->scope_level, parser->while_num[parser->scope_level] );
				result_push_back(temp);
			}
			| DO stat WHILE '(' exp ')' ';'
			| FOR '(' exp ';' exp ';' exp ')' stat 
			| FOR '(' exp ';' exp ';'	')' stat 
			| FOR '(' exp ';' ';' exp ')' stat 
			| FOR '(' exp ';' ';' ')' stat 
			| FOR '(' ';' exp ';' exp ')' stat 
			| FOR '(' ';' exp ';' ')' stat 
			| FOR '(' ';' ';' exp ')' stat 
			| FOR '(' ';' ';' ')' stat 
			;
jump_stat:		GOTO id ';'
			| CONTINUE ';'
			| BREAK ';'
			| RETURN { parser->assigning = true; } exp {
				if (parser->operator_type == -1) {
					local_variable_load();
				}
			} ';' {
				if (parser->keep_function_type == 'I') {
					result_push_back("f2i");
					result_push_back("ireturn");
				} else if (parser->keep_function_type == 'F') {
					result_push_back("freturn");
				}
			} { parser->assigning = false; }
			| RETURN ';' {
				result_push_back("return");
			}
			;
exp: 			assignment_exp
			| exp ',' assignment_exp
			;
assignment_exp: 	conditional_exp
			| unary_exp assignment_operator assignment_exp {
				// according LHS variable datatype to store the data
				if (parser->scope_level > 0) {
					indexed_symbol_node* target = search_symbol(parser->scope_level, parser->keep_init_variable_name);
					if (target) {
						char temp[1024] = {0};
						memset(temp, 0, sizeof(char) * 1024);
						if (parser->postfix_type == 0) {
							result_push_back("ldc -1.0");
							result_push_back("fadd");
						} else if (parser->postfix_type == 1) {
							result_push_back("ldc 1.0");
							result_push_back("fadd");
						}
						switch (parser->assign_type) {
							case 1:
								result_push_back("fadd");
								break;
							case 2:
								result_push_back("fsub");
								break;
							case 3:
								result_push_back("fmul");
								break;
							case 4:
								result_push_back("fdiv");
								break;
							case 5:
								result_push_back("irem");
								break;
						}
						switch (target->content->data_type) {
							case 'I':
								if (parser->operator_type != 4) {
									result_push_back("f2i");
								}
								sprintf(temp, "istore %d", target->index);
								break;
							case 'F':
								if (strlen(parser->function_reference) > 0 && parser->operator_type == -1) {
									indexed_symbol_node *function_node = search_symbol(parser->scope_level, parser->function_reference);
									if (function_node->content->data_type == 'I') {
										result_push_back("i2f");
									}
								}
								if (parser->operator_type == 4) {
									result_push_back("i2f");
								}
								sprintf(temp, "fstore %d", target->index);
								break;
							case 'Z':
								sprintf(temp, "istore %d", target->index);
								break;
							case 'S':
								sprintf(temp, "astore %d", target->index);
								break;
						}
						result_push_back(temp);
					}
				}
				parser->assigning = false;
				parser->assign_type = parser->operator_type = parser->postfix_type = -1;
			}
			;
assignment_operator: 	 '=' { 
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
		   		parser->assign_type = 0;
				parser->assigning = true;
			}
		   	| PUNC
			| add_assign {
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				parser->assigning = true;

				parser->assign_type = 1;
				load_lhs_variable();
			}
			| minus_assign {
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				parser->assigning = true;

				parser->assign_type = 2;
				load_lhs_variable();
			}
			| multiply_assign {
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				parser->assigning = true;

				parser->assign_type = 3;
				load_lhs_variable();
			}
			| divide_assign {
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				parser->assigning = true;

				parser->assign_type = 4;
				load_lhs_variable();
			}
			| module_assign {
				memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
				strcpy(parser->keep_init_variable_name, parser->decl_name);
				parser->assigning = true;

				parser->assign_type = 5;
				load_lhs_variable();
			}
			;
conditional_exp: 	logical_or_exp
			| logical_or_exp '?' exp ':' conditional_exp
			;	
const_exp: 		conditional_exp
			;
logical_or_exp: 	logical_and_exp
			| logical_or_exp or_const logical_and_exp
			;
logical_and_exp: 	inclusive_or_exp
			| logical_and_exp and_const inclusive_or_exp
			;
inclusive_or_exp: 	exclusive_or_exp
			| inclusive_or_exp '|' exclusive_or_exp
			;
exclusive_or_exp: 	and_exp
			| exclusive_or_exp '^' and_exp
			;
and_exp:		equality_exp
			| and_exp '&' equality_exp
			;
equality_exp: 		relational_exp
			| equality_exp eq_const relational_exp
			;
relational_exp: 	shift_expression
			| relational_exp { parser->assigning = true; local_variable_load(); } equal_const { parser->relation_type = 0; } shift_expression {
				local_variable_load();
				relation_parse_output();
				parser->assigning = false;
			}
			| relational_exp { parser->assigning = true; local_variable_load(); } not_equal_const { parser->relation_type = 1; } shift_expression { 
				local_variable_load();
				relation_parse_output();
				parser->assigning = false;
			}
			| relational_exp { parser->assigning = true; local_variable_load(); } '<'{ parser->relation_type = 2; } shift_expression { 
				local_variable_load();
				relation_parse_output();
				parser->assigning = false;
			}
			| relational_exp { parser->assigning = true; local_variable_load(); } '>' { parser->relation_type = 3; } shift_expression {
				local_variable_load();
				relation_parse_output();
				parser->assigning = false;
			}
			| relational_exp { parser->assigning = true; local_variable_load(); } rel_le_const { parser->relation_type = 4; } shift_expression {
				local_variable_load();
				relation_parse_output();
				parser->assigning = false;
			}
			| relational_exp { parser->assigning = true; local_variable_load(); } rel_re_const { parser->relation_type = 5; } shift_expression {
				local_variable_load();
				relation_parse_output();
				parser->assigning = false;
			}
			;
shift_expression: 	additive_exp
			| shift_expression shift_const additive_exp
			;
additive_exp: 		mult_exp
			| additive_exp { local_variable_load(); } '+' { parser->operator_type = 0; } mult_exp {
				local_variable_load();
				result_push_back("fadd");
				memset(parser->decl_name, 0, sizeof(char) * 256);
			}
			| additive_exp { local_variable_load(); } '-' { parser->operator_type = 1; } mult_exp {
				local_variable_load();
				result_push_back("fsub");
				memset(parser->decl_name, 0, sizeof(char) * 256);
			}
			;
mult_exp: 		cast_exp
			| mult_exp { local_variable_load(); } '*' { parser->operator_type = 2; } cast_exp {
				local_variable_load();
				result_push_back("fmul");
				memset(parser->decl_name, 0, sizeof(char) * 256);
			}
			| mult_exp { local_variable_load(); } '/' { parser->operator_type = 3; } cast_exp {
				local_variable_load();
				if (parser->val.init && parser->val.v.f == 0) {
					char msg[1024];
					sprintf(msg, "Detect divided by zero!");
					yyerror(msg);
				}

				result_push_back("fdiv");
				memset(parser->decl_name, 0, sizeof(char) * 256);
			}
			| mult_exp { local_variable_load(); } '%' {
				parser->operator_type = 4;
				if (parser->val.init && parser->val.type != 'I') {
					char msg[1024];
					sprintf(msg, "The operand should be integer!");
					yyerror(msg);
				}
				result_push_back("f2i");
			} cast_exp {
				local_variable_load();
				if (parser->val.init && parser->val.type != 'I') {
					char msg[1024];
					sprintf(msg, "The operand should be integer!");
					yyerror(msg);
				}
				result_push_back("f2i");

				result_push_back("irem");
				memset(parser->decl_name, 0, sizeof(char) * 256);
			}
			;
cast_exp: 		unary_exp
			| '(' type_name ')' cast_exp
			;
unary_exp: 		postfix_exp
	 		| inc_const {
				result_push_back("ldc 1.0");
			} unary_exp {
				parser->assigning = true;
				local_variable_load();
				if (parser->assign_type == -1) {
					parser->assigning = false;
				}
				result_push_back("fadd");
				parser->postfix_type = -1;
			}
			| dec_const {
				result_push_back("ldc -1.0");
			} unary_exp {
				parser->assigning = true;
				local_variable_load();
				if (parser->assign_type == -1) {
					parser->assigning = false;
				}
				result_push_back("fadd");
				parser->postfix_type = -1;
			}
			| unary_operator cast_exp
			| SIZEOF unary_exp
			| SIZEOF '(' type_name ')'
			;
unary_operator: 	'&' | '*' | '+' | '-' | '~' | '!' 				
			;
postfix_exp: 		primary_exp
	   		| postfix_exp '[' exp ']'
			| postfix_exp '(' {
				// keep function call name
				memset(parser->function_reference, 0, sizeof(char) * 256);
				strcpy(parser->function_reference, parser->decl_name); 
				memset(parser->decl_name, 0, sizeof(char) * 256);
				// check semantic error
				int check = lookup_symbol(parser->function_reference, false);
				if (!check) {
					char msg[1024];
					sprintf(msg, "Undeclared function %s", parser->function_reference);
					yyerror(msg);
				} else {
					// check the function return type
					indexed_symbol_node *function_target = search_symbol(parser->scope_level, parser->function_reference);
					if (function_target->content->data_type == 'V' && parser->assigning) {
						char msg[1024];
						sprintf(msg, "Assign void value with %s function return type", parser->function_reference);
						yyerror(msg);
					}
				}
			} argument_exp_list ')' { 
				parser->current_argument = 0;

				indexed_symbol_node *target = search_symbol(parser->scope_level, parser->function_reference);
				if (target) {
					char temp[1024] = {0};
					memset(temp, 0, sizeof(char) * 1024);
					sprintf(temp, "invokestatic compiler_hw3/%s(%s)%c", target->content->name, target->content->formal_parameters, target->content->data_type);
					result_push_back(temp);
					if (target->content->data_type == 'I') {
						result_push_back("i2f");
					}
				}

			} 
			| postfix_exp '.' id
			| postfix_exp point_const id
			| postfix_exp {
				parser->assigning = true;
				local_variable_load();
			} inc_const {
				if (parser->assign_type == -1) {
					parser->assigning = false;
				}
				result_push_back("ldc 1.0");
				result_push_back("fadd");
				parser->postfix_type = 0;
			}
			| postfix_exp {
				parser->assigning = true;
				local_variable_load();
			} dec_const {
				if (parser->assign_type == -1) {
					parser->assigning = false;
				}
				result_push_back("ldc -1.0");
				result_push_back("fadd");
				parser->postfix_type = 1;
			}
			| PRINT '(' primary_exp {
				local_variable_load();
				/*
				int status = local_variable_load();
				if (!status) {
					char temp[1024] = {0};
					memset(temp, 0, sizeof(char) * 1024);
					switch (parser->val.type) {
						case 'I':
							sprintf(temp, "ldc %d\n", parser->)
							break;
						case 'F':
							break;
						case 'Z':
							break;
						case 'S':
							break;
					}
				}
				*/
			} ')' {
				if (strlen(parser->decl_name) != 0) {
					indexed_symbol_node* target = search_symbol(parser->scope_level, parser->decl_name);
					if (target) {
						result_push_back("getstatic java/lang/System/out Ljava/io/PrintStream;");
						result_push_back("swap");
						char temp[1024] = {0};
						memset(temp, 0, sizeof(char) * 1024);
						if (target->content->data_type == 'S') {
							sprintf(temp, "invokevirtual java/io/PrintStream/println(%s)V", "Ljava/lang/String;");
						} else {
							sprintf(temp, "invokevirtual java/io/PrintStream/println(%c)V", target->content->data_type);
						}
						result_push_back(temp);
					}
				} else {
					if (parser->val.init && parser->val.type == 'I') {
						result_push_back("getstatic java/lang/System/out Ljava/io/PrintStream;");
						result_push_back("swap");
						result_push_back("invokevirtual java/io/PrintStream/println(I)V");
					} else if (parser->val.init && parser->val.type == 'F') {
						result_push_back("getstatic java/lang/System/out Ljava/io/PrintStream;");
						result_push_back("swap");
						result_push_back("invokevirtual java/io/PrintStream/println(F)V");
					} else if (parser->val.init && parser->val.type == 'Z') {
						result_push_back("getstatic java/lang/System/out Ljava/io/PrintStream;");
						result_push_back("swap");
						result_push_back("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V");

					} else if (parser->val.init && parser->val.type == 'S') {
						result_push_back("getstatic java/lang/System/out Ljava/io/PrintStream;");
						result_push_back("swap");
						result_push_back("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V");
					}
				}
			}
			;
primary_exp: 		id {
	   			memset(parser->decl_name, 0, sizeof(char) * 256);
				strcpy(parser->decl_name, yylval.sVal);
			}
			| consts {
				if (parser->scope_level > 0) {
					char temp[1024] = {0};
					memset(temp, 0, sizeof(char) * 1024);
					if (parser->val.init) {
						switch (parser->val.type) {
							case 'I':
								sprintf(temp, "ldc %d", (int)parser->val.v.f);
								result_push_back(temp);
								if (parser->assigning) {
									result_push_back("i2f");
								}
								break;
							case 'F':
								sprintf(temp, "ldc %f", parser->val.v.f);
								result_push_back(temp);
								break;
							case 'Z':
								sprintf(temp, "ldc %d", (int)parser->val.v.f);
								result_push_back(temp);
								break;
							case 'S':
								sprintf(temp, "ldc %s", parser->val.v.s);
								result_push_back(temp);
								break;
						}
					}
					if (parser->assign_type == 4 && parser->val.v.f == 0) {
						char msg[1024];
						sprintf(msg, "Detect divide by zero");
						yyerror(msg);
					}
				}
			}
			| '(' exp ')'
			;
argument_exp_list: 	assignment_exp {
				indexed_symbol_node* function_node = search_symbol(parser->scope_level, parser->function_reference);
				if (function_node) {
		 			if (strlen(parser->decl_name) != 0) {
						// load the argument
						bool temp = parser->assigning;
						parser->assigning = false;
						int status = local_variable_load();
						parser->assigning = temp;
						if (status) {
							// check argument type meet the function
							indexed_symbol_node* variable_node = search_symbol(parser->scope_level, yylval.sVal);
							if (function_node->content->formal_parameters[parser->current_argument] != variable_node->content->data_type &&
								variable_node->content->data_type == 'V') {
								char msg[1024];
								sprintf(msg, "Passing incompatible argument type to the %s function", parser->function_reference);
								yyerror(msg);
							}
							if (function_node->content->formal_parameters[parser->current_argument] != variable_node->content->data_type &&
								variable_node->content->data_type == 'S') {
								char msg[1024];
								sprintf(msg, "Passing incompatible argument type to the %s function", parser->function_reference);
								yyerror(msg);
							}
							if (function_node->content->formal_parameters[parser->current_argument] == 'I' && variable_node->content->data_type != 'I') {
								result_push_back("f2i");
							} else if (function_node->content->formal_parameters[parser->current_argument] == 'F' && variable_node->content->data_type == 'I') {
								result_push_back("i2f");
							}
						}
					} else {
						if (function_node->content->formal_parameters[parser->current_argument] != parser->val.type && parser->val.type == 'S') {
							char msg[1024];
							sprintf(msg, "Passing incompatible argument type to the %s function", parser->function_reference);
							yyerror(msg);
						}
						if (function_node->content->formal_parameters[parser->current_argument] == 'I') {
							result_push_back("f2i");
						} else if (function_node->content->formal_parameters[parser->current_argument] == 'F' && parser->val.type == 'I') {
							result_push_back("i2f");
						}
					}
					parser->current_argument++;
				}
			}
			| argument_exp_list ',' assignment_exp {
				indexed_symbol_node* function_node = search_symbol(parser->scope_level, parser->function_reference);
				if (function_node) {
		 			if (strlen(parser->decl_name) != 0) {
						// load the argument
						int status = local_variable_load();
						if (status) {
							// check argument type meet the function
							indexed_symbol_node* variable_node = search_symbol(parser->scope_level, parser->decl_name);
							if (function_node->content->formal_parameters[parser->current_argument] != variable_node->content->data_type &&
								variable_node->content->data_type == 'V') {
								char msg[1024];
								sprintf(msg, "Passing incompatible argument type to the %s function", parser->function_reference);
								yyerror(msg);
							}
							if (function_node->content->formal_parameters[parser->current_argument] != variable_node->content->data_type &&
								variable_node->content->data_type == 'S') {
								char msg[1024];
								sprintf(msg, "Passing incompatible argument type to the %s function", parser->function_reference);
								yyerror(msg);
							}
							if (function_node->content->formal_parameters[parser->current_argument] == 'I' && variable_node->content->data_type != 'I') {
								result_push_back("f2i");
							} else if (function_node->content->formal_parameters[parser->current_argument] == 'F' && variable_node->content->data_type == 'I') {
								result_push_back("i2f");
							}
						}
					} else {
						if (function_node->content->formal_parameters[parser->current_argument] != parser->val.type && parser->val.type == 'S') {
							char msg[1024];
							sprintf(msg, "Passing incompatible argument type to the %s function", parser->function_reference);
							yyerror(msg);
						}
						if (function_node->content->formal_parameters[parser->current_argument] == 'I') {
							result_push_back("f2i");
						} else if (function_node->content->formal_parameters[parser->current_argument] == 'F' && parser->val.type == 'I') {
							result_push_back("i2f");
						}
					}
					parser->current_argument++;
				}
			}
			| {}
			;
consts: 		int_const { parser->val.init = true; parser->val.type = 'I'; parser->val.v.f = yylval.iVal; } 											
			| char_const { parser->val.init = true; parser->val.type = 'S'; char *temp = malloc(sizeof(char) * strlen(yylval.sVal)); strcpy(temp, yylval.sVal); parser->val.v.s = temp; }
			| string { parser->val.init = true; parser->val.type = 'S'; char *temp = malloc(sizeof(char) * strlen(yylval.sVal)); strcpy(temp, yylval.sVal); parser->val.v.s = temp; }
			| float_const { parser->val.init = true; parser->val.type = 'F'; parser->val.v.f = yylval.fVal; }
			| enumeration_const
			| TRUE { parser->val.init = true; parser->val.type = 'Z'; parser->val.v.f = 1; } 
			| FALSE { parser->val.init = true; parser->val.type = 'Z'; parser->val.v.f = 0; } 
			;
%%
int main(int args, char* argv[])
{
	// initialize the global varaible and parser node
	yylineno = 0;
	
	parser = (parser_node*)malloc(sizeof(parser_node));
	parser->scope_level = 0;
	parser->symbol_number = 0;
	parser->entry_type = 0;
	parser->data_type = '\0';
	parser->declaration_type = false;
	memset(parser->data_type_pointer, 0, sizeof(char) * 256);

	memset(parser->decl_name, 0, sizeof(char) * 256);
	memset(parser->formal_parameters, 0, sizeof(char) * 1024);
	parser->formal_parameters_number = 0;

	parser->keep_function_type = 0;
	memset(parser->keep_function_name, 0, sizeof(char) * 256);
	memset(parser->keep_init_variable_name, 0, sizeof(char) * 256);
	memset(parser->function_reference, 0, sizeof(char) * 256);
	memset(parser->variable_reference, 0, sizeof(char) * 256);

	parser->success = true;
	parser->dump_symbol = false;
	parser->assigning = false;
	parser->assign_type = -1;
	parser->operator_type = -1;
	parser->relation_type = -1;
	parser->postfix_type = -1;
	memset(parser->current_exit_if, -1, sizeof(int) * 1000);
	memset(parser->if_num, -1, sizeof(int) * 1000);
	memset(parser->while_num, -1, sizeof(int) * 1000);
	parser->else_exist = false;
	parser->while_stat = false;
	parser->dump_scope_level = -1;
	parser->current_argument = 0;

	param_list = NULL;
		
	yyparse();
	// dump all symbol in the scope level 0
	if (parser->success) {
		// dump the final symbol table
		parser->dump_symbol = true;
		parser->dump_scope_level = 0;
		dump_symbol();
		printf("\nTotal lines: %d \n", yylineno);
		dump_parse_result();
	} else {
		rest();
		parser->dump_symbol = true;
		parser->dump_scope_level = 0;
		dump_error();
	}
	return 0;
}
int yyerror(char *msg)
{
	parser->error_num++;
	// insert the error message to the error list
	insert_error(msg);
	if (strstr(msg, "syntax error") != NULL) {
		parser->success = false;
	}
	return 0;
}

void insert_temp_param (char* name, char data_type) {
	param_node *target = (param_node*)malloc(sizeof(param_node));
	memset(target->name, 0, sizeof(char) * 256);
	strcpy(target->name, name);
	target->data_type = data_type;
	if (!param_list) {
		param_list = target;
		return;
	}
	param_node *iter = param_list;
	while (iter->next) {
		iter = iter->next;
	}
	iter->next = target;
}

void clear_param_list() {
	if (!param_list) {
		return;
	}
	param_node *prev = NULL;
	param_node *iter = param_list;
	while(iter) {
		// erase the param node
		prev = iter;
		iter = iter->next;
		prev->next = NULL;
		free(prev);
	}
	param_list = NULL;
}

void insert_param_to_symbol_table() {
	if (!param_list) {
		return;
	}
	param_node *prev = NULL;
	param_node *iter = param_list;
	while(iter) {
		// set the parser data
		memset(parser->decl_name, 0, sizeof(char) * 256);
		strcpy(parser->decl_name, iter->name);
		parser->data_type = iter->data_type;
		parser->entry_type = 3;
		// insert the parameter to the symbol table
		insert_symbol();
		// erase the param node
		prev = iter;
		iter = iter->next;
		prev->next = NULL;
		free(prev);
	}
	param_list = NULL;
}
