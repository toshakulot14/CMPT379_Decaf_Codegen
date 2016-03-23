%{
#include <iostream>
#include <ostream>
#include <string>
#include <cstdlib>
#include "decaf-defs.h"


int yylex(void);
int yyerror(char *); 

using namespace std;

// print AST?
bool printAST = true;

#include "decaf-ast.cc"

%}

%union{
    class decafAST *ast;
    std::string *sval;
    int number;
    int decaftype;
 }



%token T_AND T_ASSIGN T_BREAK T_CLASS T_COMMENT T_COMMA T_CONTINUE T_DIV T_DOT T_ELSE T_EQ T_EXTENDS T_EXTERN T_FOR T_GEQ T_GT T_IF T_LCB T_LEFTSHIFT T_LEQ T_LPAREN T_LSB T_LT T_MINUS T_MOD T_MULT T_NEQ T_NEW T_NOT T_NULL T_OR T_PLUS T_RCB T_RETURN T_RIGHTSHIFT T_RPAREN T_RSB T_SEMICOLON T_STRINGTYPE T_WHILE T_WHITESPACE T_INTTYPE T_BOOLTYPE T_VOID

%token <number> T_CHARCONSTANT T_INTCONSTANT T_FALSE T_TRUE
%token <sval> T_ID T_STRINGCONSTANT

%type <ast> rvalue expr constant bool_constant assign assign_list
%type <ast> extern_type_list extern_type extern_defn extern_list param_list var_decl_list var_decl param method_decl_list field_decl_list method_type_list return_type class field_decl method_decl decaf_type method_type void_type string_type int_type bool_type method_block block statement_list statement method_call method_arg method_arg_list ifstmt whilestmt forstmt returnstmt breakstmt continuestmt

%left T_OR
%left T_AND
%left T_EQ T_NEQ
%left T_LT T_GT T_LEQ T_GEQ
%left T_PLUS T_MINUS

%left T_RIGHTSHIFT T_LEFTSHIFT
%left T_MULT T_DIV T_MOD


%right T_NOT
%right UMINUS


%%

start: program



program: extern_list class
    {
        ProgramAST *prog = new ProgramAST($1, $2);
                if (printAST) {
                        cout << getString(prog) << endl;
                }
        delete prog;
    }
    | class
    {
        ProgramAST *prog = new ProgramAST(NULL, $1);
                if (printAST) {
                        cout << getString(prog) << endl;
                }
        delete prog;
    }
    ;

extern_list: extern_list extern_defn
  {
    decafStmtList *slist = (decafStmtList *)$1; slist->push_back($2); $$ = slist;
  }
  | extern_defn
  {
    decafStmtList *slist = new decafStmtList();
    slist->push_back($1);
    $$ = slist;
  }
  ;

extern_defn: T_EXTERN return_type T_ID T_LPAREN extern_type_list T_RPAREN T_SEMICOLON
  {
    $$ = new ExternFunctionAST(*$3, $2, $5); delete $3;
  }
  | T_EXTERN return_type T_ID T_LPAREN T_RPAREN T_SEMICOLON
  {
    $$ = new ExternFunctionAST(*$3, $2, NULL); delete $3;
  }
  ;
  
extern_type_list:  extern_type T_COMMA extern_type_list
  {
    decafStmtList *slist = (decafStmtList *)$3; slist->push_front($1); $$ = slist;
  }
    | extern_type
  {
    decafStmtList *slist = new decafStmtList(); slist->push_front($1); $$ = slist;
  }
  ;

extern_type: string_type
            {
                $$ = new ExternTypeAST($1);
            }

            | decaf_type
            {
                $$ = new ExternTypeAST($1);
            }
            ;

return_type: method_type
            {
                $$ = $1;
            }
            ;

decaf_type: int_type
            {
                $$ = new DecafTypeAST($1);
            }
          | bool_type
            {
                $$ = new DecafTypeAST($1);
            }
          ;

string_type: T_STRINGTYPE
    {
        $$ = new StringTypeAST();
    }

int_type: T_INTTYPE
    {
        $$ = new IntTypeAST();
    }

bool_type: T_BOOLTYPE
    {
        $$ = new BoolTypeAST();
    }




class: T_CLASS T_ID T_LCB field_decl_list method_decl_list T_RCB
      {
        $$ = new ClassAST(*$2, $4, $5); delete $2;
      }
      | T_CLASS T_ID T_LCB field_decl_list T_RCB
      {
        $$ = new ClassAST(*$2, $4, NULL); delete $2;
      }
      | T_CLASS T_ID T_LCB method_decl_list T_RCB
      {
        $$ = new ClassAST(*$2, NULL, $4); delete $2;
      }
      | T_CLASS T_ID T_LCB T_RCB
      {
        $$ = new ClassAST(*$2, NULL, NULL); delete $2;
      }
      ;

field_decl_list: field_decl field_decl_list
                    {
                        decafStmtList *slist = (decafStmtList *)$2;
                        slist->push_front($1);
                        $$ = slist;
                    }
                  | field_decl
                    {
                        decafStmtList *slist = new decafStmtList(); 
                        slist->push_front($1);
                        $$ = slist; 
                    }
            ;


field_decl: decaf_type T_ID T_SEMICOLON
            {
                $$ = new FieldDeclScalarAST(*$2, $1); delete $2;
            }
          
            | decaf_type T_ID T_LSB T_INTCONSTANT T_RSB T_SEMICOLON
            {
                $$ = new FieldDeclArrayAST(*$2, $1, $4); delete $2;
            }
            | decaf_type T_ID T_ASSIGN constant T_SEMICOLON
            {
                $$ = new AssignGlobalVarAST(*$2, $1, $4); delete $2;
            }

            /*| decaf_type T_ID T_ASSIGN constant T_SEMICOLON
            {
                $$ = new FieldDeclAST(*$2, $1, $4); delete $2;
            }*/
    ;


method_decl_list: method_decl method_decl_list
                    {
                        decafStmtList *slist = (decafStmtList *)$2;
                        slist->push_front($1);
                        $$ = slist;
                    }
                  | method_decl
                    {
                        decafStmtList *slist = new decafStmtList(); $$ = slist;
                        slist->push_front($1);
                        $$ = slist; 
                    }
            ;


method_decl: method_type_list T_ID T_LPAREN T_RPAREN method_block
    {
        $$ = new MethodDeclAST(*$2, $1, NULL, $5); delete $2;
    }
    | method_type_list T_ID T_LPAREN param_list T_RPAREN method_block
    {
        $$ = new MethodDeclAST(*$2, $1, $4, $6); delete $2;
    }          
    ;

method_type_list: method_type
    {
        $$ = $1;
    }


method_type: decaf_type
            {
                $$ = $1;
            }
            | void_type
            {
                $$ = $1;
            }
            ;

void_type:  T_VOID
            {
                $$ = new VoidTypeAST();
            }
          ;

param_list: param T_COMMA param_list
                    {
                        decafParamList *slist = (decafParamList *)$3;
                        slist->push_front($1);
                        $$ = slist;
                    }
            | param
            {
                decafParamList *slist = new decafParamList();
                slist->push_front($1);
                $$ = slist;
            }
            ;

param: decaf_type T_ID 
    {
        $$ = new VarDefAST(*$2, $1); delete $2;
    }



method_block:   T_LCB T_RCB
                {
                    $$ = new MethodBlockAST(NULL, NULL);
                }
            |   T_LCB var_decl_list T_RCB  
                {
                    $$ = new MethodBlockAST($2, NULL);
                }
            |   T_LCB statement_list T_RCB
                {
                    $$ = new MethodBlockAST(NULL, $2);
                }
            |    T_LCB var_decl_list statement_list T_RCB
                {
                    $$ = new MethodBlockAST($2, $3);
                }
            ;

var_decl_list: var_decl var_decl_list
    {
        decafStmtList *slist = (decafStmtList *)$2;
                        slist->push_front($1);
                        $$ = slist;
    }
            | var_decl
            {
                decafStmtList *slist = new decafStmtList();
                slist->push_front($1);
                $$ = slist;
            }
            ;


var_decl: decaf_type T_ID T_SEMICOLON
            { 
                $$ = new VarDefAST(*$2, $1); delete $2;
            }
            ;
/*
id_comma_list: id_comma_list T_COMMA T_ID
            {
                decafStmtList *slist = (decafStmtList *)$3;
                        slist->push_front($2);
                        $$ = slist;
            }
            | typed_symbol T_COMMA T_ID
            {
                decafStmtList *slist = new decafStmtList(); $$ = slist;
            }
            ;
*/


statement_list: statement statement_list
                {
                    
                    decafStmtList *slist = (decafStmtList *)$2;
                    slist->push_front($1);
                    $$ = slist;
                }
              | statement
                {
                    decafStmtList *slist = new decafStmtList();
                    slist->push_front($1);
                    $$ = slist; 
                }
              ;


statement:  assign_list T_SEMICOLON 
            { $$ = $1; }
         /*|  assign
            { $$ = $1; }*/
         |  method_call T_SEMICOLON
            {
                $$ = $1;
            }
         | ifstmt
           {
                $$=$1;
           }
        | block
            {
                $$ = $1;
            }
        | whilestmt
            {
                $$=$1;
            }
        | returnstmt
            {
                $$=$1;
            }
        | continuestmt
            {
                $$=$1;
            }
        | breakstmt
            {
                $$=$1;
            }
        | forstmt
            {
                $$=$1;
            }
        ;

block: T_LCB T_RCB
                {
                    $$ = new BlockAST(NULL, NULL);
                }
            |   T_LCB var_decl_list T_RCB  
                {
                    $$ = new BlockAST($2, NULL);
                }
            |   T_LCB statement_list T_RCB
                {
                    $$ = new BlockAST(NULL, $2);
                }
            |    T_LCB var_decl_list statement_list T_RCB
                {
                    $$ = new BlockAST($2, $3);
                }
            ;


ifstmt: T_IF T_LPAREN expr T_RPAREN block
            {
                 $$ = new IfStmtAST($3, $5, NULL);
            }
        | T_IF T_LPAREN expr T_RPAREN block T_ELSE block
            {
                 $$ = new IfStmtAST($3, $5, $7);
            }
            ;
whilestmt: T_WHILE T_LPAREN expr T_RPAREN block
            {
                 $$ = new WhileStmtAST($3, $5);
            }
            ;

forstmt: T_FOR T_LPAREN assign_list T_SEMICOLON expr T_SEMICOLON assign_list T_RPAREN block
    { $$ = new ForStmtAST($3, $5, $7, $9); }

returnstmt: T_RETURN T_SEMICOLON
            {
                 $$ = new ReturnStmtAST(NULL);
            }
            | T_RETURN T_LPAREN T_RPAREN T_SEMICOLON
            {
                 $$ = new ReturnStmtAST(NULL);
            }
            | T_RETURN T_LPAREN expr T_RPAREN T_SEMICOLON
            {
                 $$ = new ReturnStmtAST($3);
            }
            ;
breakstmt: T_BREAK T_SEMICOLON
            {
                 $$ = new BreakStmtAST();
            }
continuestmt: T_CONTINUE T_SEMICOLON
            {
                 $$ = new ContinueStmtAST();
            }

assign_list: assign assign_list
    {
        decafStmtList *slist = (decafStmtList *)$2; slist->push_front($1); $$ = slist;
    }
    | assign
    {
       decafStmtList *slist = new decafStmtList(); slist->push_front($1); $$ = slist; 
    }

assign: T_ID T_ASSIGN expr
    { $$ = new AssignVarAST(*$1, $3); delete $1; }
    | T_ID T_LSB expr T_RSB T_ASSIGN expr
    {
        $$ = new AssignArrayLocAST(*$1, $3, $6); delete $1;
    }
    ;

method_call:    T_ID T_LPAREN T_RPAREN
                {
                    $$ = new MethodCallAST(*$1, NULL);
                }
            |   T_ID T_LPAREN method_arg_list T_RPAREN
                {
                    $$ = new MethodCallAST(*$1, $3);
                }
             ;

method_arg_list: method_arg T_COMMA method_arg_list
    {
        decafStmtList *slist = (decafStmtList *)$3; slist->push_front($1); $$ = slist;
    }
    | method_arg
    {
        decafStmtList *slist = new decafStmtList(); slist->push_front($1); $$ = slist;
    }
  ;

method_arg:    T_STRINGCONSTANT
                {
                    $$ = new StringConstAST(*$1);
                }
            |   expr
                {
                    $$=$1;
                }
            ;



rvalue: T_ID T_LSB expr T_RSB
	{ $$ = new ArrayLocExprAST(*$1, $3); }
	| T_ID
    	{ $$ = new VariableExprAST(*$1); }
    	;

expr: rvalue
    	{ $$ = $1; }
        | method_call { $$ = $1; }
    	| constant
    	{ $$ = $1; }
    	| expr T_PLUS expr
    	{ $$ = new BinaryExprAST(T_PLUS, $1, $3); }
    	| expr T_MINUS expr
    	{ $$ = new BinaryExprAST(T_MINUS, $1, $3); }
    	| expr T_MULT expr
    	{ $$ = new BinaryExprAST(T_MULT, $1, $3); }
    	| expr T_DIV expr
    	{ $$ = new BinaryExprAST(T_DIV, $1, $3); }
	| expr T_RIGHTSHIFT expr
    	{ $$ = new BinaryExprAST(T_RIGHTSHIFT, $1, $3); }
	| expr T_LEFTSHIFT expr
    	{ $$ = new BinaryExprAST(T_LEFTSHIFT, $1, $3); }
    	| expr T_MOD expr
    	{ $$ = new BinaryExprAST(T_MOD, $1, $3); }
	| expr T_LT expr
    	{ $$ = new BinaryExprAST(T_LT, $1, $3); }
	| expr T_GT expr
    	{ $$ = new BinaryExprAST(T_GT, $1, $3); }
	| expr T_LEQ expr
    	{ $$ = new BinaryExprAST(T_LEQ, $1, $3); }
	| expr T_GEQ expr
    	{ $$ = new BinaryExprAST(T_GEQ, $1, $3); }
	| expr T_EQ expr
    	{ $$ = new BinaryExprAST(T_EQ, $1, $3); }
	| expr T_NEQ expr
    	{ $$ = new BinaryExprAST(T_NEQ, $1, $3); }
	| expr T_AND expr
    	{ $$ = new BinaryExprAST(T_AND, $1, $3); }
	| expr T_OR expr
    	{ $$ = new BinaryExprAST(T_OR, $1, $3); }
    	| T_MINUS expr %prec UMINUS 
    	{ $$ = new UnaryExprAST(T_MINUS, $2); }
    	| T_NOT expr
    	{ $$ = new UnaryExprAST(T_NOT, $2); }
    	| T_LPAREN expr T_RPAREN
    	{ $$ = $2; }   

    	;

constant: T_INTCONSTANT
    { $$ = new NumberExprAST($1); }
    | T_CHARCONSTANT
    { $$ = new NumberExprAST($1); }
    | bool_constant
    { $$ = $1; }
    ;

bool_constant: T_TRUE
    { $$ = new BoolExprAST(true); }
    | T_FALSE 
    { $$ = new BoolExprAST(false); }
    ;

%%

int main() {
  // parse the input and create the abstract syntax tree
  int retval = yyparse();
  return(retval >= 1 ? 1 : 0);
}
