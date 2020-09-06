#include "parser_handler.h"

extern parser_node* parser;
extern FILE* output;

void result_push_back(char *content) {
	parse_node* target = (parse_node*)malloc(sizeof(parse_node));
	memset(target->content, 0, sizeof(char) * 1024);
	strcpy(target->content, content);

	parse_node* head = parser->parse_result;
	if (!head) {
		parser->parse_result = target;
		return;
	}
	while (head->next) {
		head = head->next;
	}
	head->next = target;
}

void result_push_front(char *content) {
	parse_node* target = (parse_node*)malloc(sizeof(parse_node));
	memset(target->content, 0, sizeof(char) * 1024);
	strcpy(target->content, content);

	parse_node* head = parser->parse_result;
	if (!head) {
		parser->parse_result = target;
		return;
	}
	target->next = parser->parse_result;
	parser->parse_result = target;
}

void dump_parse_result() {
	if (parser->error_num > 0) {
		return;
	}
	// initialize the output file pointer
	FILE* output = fopen("compiler_hw3.j", "w");
	if (output == NULL) {
		printf("Error opening file!\n");
		exit(1);
	}

	// output the class info first
	char text[1024] = ".class public compiler_hw3\n.super java/lang/Object";
	fprintf(output, "%s\n", text);

	parse_node* iter = parser->parse_result;
	parse_node* prev = NULL;
	while(iter) {
		prev = iter;
		fprintf(output, "%s\n", iter->content);
		iter = iter->next;
		prev->next = NULL;
		free(prev);
	}
	parser->parse_result = NULL;
	fclose(output);
}

void function_parse_output_dec() {
	// push front the function declaration
	if (strcmp(parser->keep_function_name, "main") == 0) {
		result_push_back(".method public static main([Ljava/lang/String;)V");
	} else {
		char temp[1024] = {0};
		sprintf(temp, ".method public static %s(", parser->keep_function_name);
		for (int i = 0 ; i < strlen(parser->formal_parameters); ++i) {
			temp[strlen(temp)] = parser->formal_parameters[i];
		}
		temp[strlen(temp)] = ')';
		temp[strlen(temp)] = parser->keep_function_type;
		result_push_back(temp);
	}
	// push front the stack size declaration
	result_push_back(".limit locals 50");
	result_push_back(".limit stack 50");
}

void global_variable_parse_output() {
	// global variable declaration
	if (parser->scope_level == 0) {
		char temp[1024];
		memset(temp, 0, sizeof(char) * 1024);
		if (parser->data_type == 'S') {
			sprintf(temp, ".field public static %s %s",
					parser->keep_init_variable_name, "Ljava/lang/String");
		} else {
			sprintf(temp, ".field public static %s %c",
					parser->keep_init_variable_name, parser->data_type);
		}
		if (parser->val.init) {
			char initValue[256];
			memset(initValue, 0, sizeof(char) * 256);
			switch (parser->data_type) {
				case 'I':
					sprintf(initValue, " = %d", (int)parser->val.v.f);
					break;
				case 'F':
					sprintf(initValue, " = %f", parser->val.v.f);
					break;
				case 'Z':
					sprintf(initValue, " = %s", parser->val.v.f ? "true" : "false");
					break;
				case 'S':
					sprintf(initValue, " = %s", parser->val.v.s);
					break;
			}
			strcat(temp, initValue);
			parser->val.init = false;
		}
		result_push_back(temp);
	}

}

int local_variable_load() {
	if (parser->scope_level > 0 && strlen(parser->decl_name) > 0) { 
		indexed_symbol_node *target = search_symbol(parser->scope_level, parser->decl_name);
		if (!target) {
			char msg[1024];
			sprintf(msg, "Undeclared variable %s", parser->decl_name);
			yyerror(msg);
			memset(parser->decl_name, 0, sizeof(char) * 256);
			return 0;
		}
		char temp[1024] = {0};
		memset(temp, 0, sizeof(char) * 1024);
		if (target->content->scope_level > 0) {
			switch (target->content->data_type) {
				case 'I':
					sprintf(temp, "iload %d", target->index);
					break;
				case 'F':
					sprintf(temp, "fload %d", target->index);
					break;
				case 'S':
					sprintf(temp, "aload %d", target->index);
					break;
			}
		} else {
			switch (target->content->data_type) {
				case 'I':
					sprintf(temp, "getstatic compiler_hw3/%s %c", target->content->name, target->content->data_type);
					break;
				case 'F':
					sprintf(temp, "getstatic compiler_hw3/%s %c", target->content->name, target->content->data_type);
					break;
				case 'S':
					sprintf(temp, "getstatic compiler_hw3/%s %s", target->content->name, "Ljava/lang/String;");
					break;
			}
		}
		result_push_back(temp);
		if (target->content->data_type == 'I' && parser->assigning) {
			result_push_back("i2f");
		}
		memset(parser->decl_name, 0, sizeof(char) * 256);
		return 1;
	}
	memset(parser->decl_name, 0, sizeof(char) * 256);
	return 0;
}

void load_lhs_variable() {
	if (parser->scope_level > 0 && parser->assigning && strlen(parser->keep_init_variable_name) > 0) { 
		indexed_symbol_node *target = search_symbol(parser->scope_level, parser->keep_init_variable_name);
		char temp[1024] = {0};
		memset(temp, 0, sizeof(char) * 1024);
		if (target->content->scope_level > 0) {
			switch (target->content->data_type) {
				case 'I':
					sprintf(temp, "iload %d", target->index);
					break;
				case 'F':
					sprintf(temp, "fload %d", target->index);
					break;
				case 'S':
					sprintf(temp, "aload %d", target->index);
					break;
			}
		} else {
			switch (target->content->data_type) {
				case 'I':
					sprintf(temp, "getstatic compiler_hw3/%s %c", target->content->name, target->content->data_type);
					break;
				case 'F':
					sprintf(temp, "getstatic compiler_hw3/%s %c", target->content->name, target->content->data_type);
					break;
				case 'S':
					sprintf(temp, "getstatic compiler_hw3/%s %s", target->content->name, "Ljava/lang/String;");
					break;
			}
		}
		result_push_back(temp);
		if (target->content->data_type == 'I') {
			result_push_back("i2f");
		}
	}

}

void relation_parse_output() {
	if (!parser->while_stat) {
		parser->else_exist = false;
		parser->if_num[parser->scope_level]++;
	} else {
		parser->while_num[parser->scope_level]++;
	}
	char temp[1024] = {0};
	memset(temp, 0, sizeof(char) * 1024);
	result_push_back("fsub");
	result_push_back("f2i");
	switch (parser->relation_type) {
		case 0:
			if (!parser->while_stat) {
				sprintf(temp, "ifne Label_%d_%d", parser->scope_level, parser->if_num[parser->scope_level]);
			} else {
				sprintf(temp, "ifne WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level]);
			}
			break;
		case 1:
			if (!parser->while_stat) {
				sprintf(temp, "ifeq Label_%d_%d", parser->scope_level, parser->if_num[parser->scope_level]);
			} else {
				sprintf(temp, "ifeq WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level]);
			}
			break;
		case 2:
			if (!parser->while_stat) {
				sprintf(temp, "ifge Label_%d_%d", parser->scope_level, parser->if_num[parser->scope_level]);
			} else {
				sprintf(temp, "ifge WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level]);
			}
			break;
		case 3:
			if (!parser->while_stat) {
				sprintf(temp, "ifle Label_%d_%d", parser->scope_level, parser->if_num[parser->scope_level]);
			} else {
				sprintf(temp, "ifle WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level]);
			}
			break;
		case 4:
			if (!parser->while_stat) {
				sprintf(temp, "ifgt Label_%d_%d", parser->scope_level, parser->if_num[parser->scope_level]);
			} else {
				sprintf(temp, "ifgt WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level]);
			}
			break;
		case 5:
			if (!parser->while_stat) {
				sprintf(temp, "iflt Label_%d_%d", parser->scope_level, parser->if_num[parser->scope_level]);
			} else {
				sprintf(temp, "iflt WLabel_%d_%d", parser->scope_level, parser->while_num[parser->scope_level]);
			}
			break;
	}

	result_push_back(temp);
}
