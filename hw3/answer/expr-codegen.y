%{
#include <iostream>
#include <ostream>
#include <string>
#include <cstdlib>
#include "decafast-defs.h"

int yylex(void);
int yyerror(char *); 

using namespace std;

// print AST?
bool printAST = true;

#include "expr-codegen.cc"

// Module
static Module *TheModule;

// IRBuilder
static IRBuilder<> Builder(getGlobalContext());


// --FUNCTION CODEGEN--
Function *gen_print_int_def() {
  // create a extern definition for print_int
  std::vector<Type*> args;
  args.push_back(IntegerType::get(getGlobalContext(), 32)); // print_int takes one integer argument
  FunctionType *print_int_type = FunctionType::get(IntegerType::get(getGlobalContext(), 32), args, false);
  return Function::Create(print_int_type, Function::ExternalLinkage, "print_int", TheModule);
}

// we also have to create a main function that contains
// all the code generated for the expression and the print_int call
Function *gen_main_def(/*Value *RetVal, Function *print_int*/) {
  /*if (RetVal == 0) {
    throw runtime_error("something went horribly wrong\n");
  }*/
  // create the top-level definition for main
  FunctionType *FT = FunctionType::get(IntegerType::get(getGlobalContext(), 32), false);
  Function *TheFunction = Function::Create(FT, Function::ExternalLinkage, "main", TheModule);
  if (TheFunction == 0) {
    throw runtime_error("empty function block"); 
  }
  // Create a new basic block which contains a sequence of LLVM instructions
  BasicBlock *BB = BasicBlock::Create(getGlobalContext(), "entary", TheFunction);
  // All subsequent calls to IRBuilder will place instructions in this location
  Builder.SetInsertPoint(BB);
  /* Function *CalleeF = TheModule->getFunction(print_int->getName());
  if (CalleeF == 0) {
    throw runtime_error("could not find the function print_int\n");
  }
  // print the value of the expression and we are done
  Value *CallF = Builder.CreateCall(CalleeF, RetVal, "calltmp"); */
  // Finish off the function.
  // return 0 from main, which is EXIT_SUCCESS
  Builder.CreateRet(ConstantInt::get(getGlobalContext(), APInt(32, 0)));
  return TheFunction;
}

// --END FUNCCODEGEN--



// ** HELPER FUNCTIONS **

// getLLVMType()	->	Gets the LLVM Type based on the Decaf Type.
Type *getLLVMType(decafType ty){
    switch(ty){
	case voidTy:	return Builder.getVoidTy();
	case intTy:	return Builder.getInt32Ty();
	case boolTy:	return Builder.getInt1Ty();
	case stringTy:	return Builder.getInt8PtrTy();
	default:	throw runtime_error("unknown type");
    }
}



// ***** end helper funcitons


#include <map> // for symbol table
#include <list> // for list of symbol tables
typedef std::map<std::string, llvm::Value*> SymbolTable;
SymbolTable symbol_table;       // A single symbol table
typedef list<SymbolTable> SymbolTableList;
SymbolTableList symbol_table_list;      // A collection (list) of symbol tables

%}

%union{
    class decafAST *ast;
    std::string *sval;
    int number;
    int decaftype;
 }

%token T_AND T_ASSIGN T_BREAK T_CLASS T_COMMENT T_COMMA T_CONTINUE T_DIV T_DOT T_ELSE T_EQ T_EXTENDS T_EXTERN 
%token T_FOR T_GEQ T_GT T_IF T_LCB T_LEFTSHIFT T_LEQ T_LPAREN T_LSB T_LT T_MINUS T_MOD T_MULT T_NEQ T_NEW T_NOT 
%token T_NULL T_OR T_PLUS T_RCB T_RETURN T_RIGHTSHIFT T_RPAREN T_RSB T_SEMICOLON T_STRINGTYPE
%token T_VOID T_WHILE T_WHITESPACE
%token T_INTTYPE T_BOOLTYPE

%token <number> T_CHARCONSTANT T_INTCONSTANT T_FALSE T_TRUE 
%token <sval> T_ID T_STRINGCONSTANT

%type <decaftype> type method_type extern_type
%type <ast> rvalue expr constant bool_constant method_call method_arg method_arg_list assign assign_comma_list
%type <ast> block method_block statement statement_list var_decl_list var_decl var_list param_list param_comma_list 
%type <ast> method_decl method_decl_list field_decl_list field_decl field_list extern_type_list extern_defn
%type <ast> extern_list decafclass

%left T_OR
%left T_AND
%left T_EQ T_NEQ T_LT T_LEQ T_GEQ T_GT
%left T_PLUS T_MINUS
%left T_MULT T_DIV T_MOD T_LEFTSHIFT T_RIGHTSHIFT
%left T_NOT
%right UMINUS

%%

start: program
     {
	//Function *print_int = gen_print_int_def();
	//Function *TheFunction = gen_main_def();
     }

program: extern_list decafclass
    { 
        
        ProgramAST *prog = new ProgramAST((decafStmtList *)$1, (ClassAST *)$2); 
	
		if (printAST) {
	//		cout << getString(prog) << endl;
		}
        delete prog;
        
    }

extern_list: extern_list extern_defn
    { 
    	
	decafStmtList *slist = (decafStmtList *)$1; slist->push_back($2); $$ = slist; 

    }
    | /* extern_list can be empty */
    { 
     
	decafStmtList *slist = new decafStmtList(); $$ = slist; 
	
    }
    ;

extern_defn: T_EXTERN method_type T_ID T_LPAREN extern_type_list T_RPAREN T_SEMICOLON
    { 
    
	$$ = new ExternAST((decafType)$2, *$3, (TypedSymbolListAST *)$5); delete $3; 
	
    }
    | T_EXTERN method_type T_ID T_LPAREN T_RPAREN T_SEMICOLON
    {
    	$$ = new ExternAST((decafType)$2, *$3, NULL); delete $3; 
    }
    ;

extern_type_list: extern_type
    { 
    	$$ = new TypedSymbolListAST(string(""), (decafType)$1); 
    }
    | extern_type T_COMMA extern_type_list
    { 
        
        TypedSymbolListAST *tlist = (TypedSymbolListAST *)$3; 
        tlist->push_front(string(""), (decafType)$1); 
        $$ = tlist;
        
    }
    ;

extern_type: T_STRINGTYPE
    { 
    
	$$ = stringTy; 

    }
    | type
    {
    	
	$$ = $1; 

    }
    ;

decafclass: T_CLASS T_ID T_LCB field_decl_list method_decl_list T_RCB
    {
    	$$ = new ClassAST(*$2, (FieldDeclListAST *)$4, (decafStmtList *)$5); delete $2; 

    }
    | T_CLASS T_ID T_LCB field_decl_list T_RCB
    {

	$$ = new ClassAST(*$2, (FieldDeclListAST *)$4, new decafStmtList()); delete $2; 

    }
    ;

field_decl_list: field_decl_list field_decl
    { 
        //cout << "FIELD DECL LIST\n";
        decafStmtList *slist = (decafStmtList *)$1; slist->push_back($2); $$ = slist; 
        // cout << "Field Decl" << endl;

        // If there was some field declaration (aka if symbol_table is not empty)
        //if (symbo)
            // If the list is empty, insert the symbol_table. Edit the list if there is one present.
/*            if (symbol_table_list.size() == 0){
                // Insert symbol_table intothe list
                symbol_table_list.push_back(symbol_table); [*$2] = lineno;  
            } else if (symbol_table_list.size() > 0){
                // Edit front of the list
                for (std::map<std::string, llvm::Value*>::iterator it=symbol_table.begin(); it!=symbol_table.end(); it++){
                    symbol_table_list.front().insert( std::pair<std::string, int> (it->first, it->second) );
                }
                symbol_table.clear();
                // cout << "Size of list: " << symbol_table_list.size() << endl;
                // cout << "Size of symbol_table: " << symbol_table.size() << endl;
                
                
                std::map<std::string, int> table = symbol_table_list.back();
                for (std::map<std::string, int>::iterator it = table.begin(); it!=table.end(); it++){
                cout << it->first << ", " << it->second << endl;
                }
                */
                /* symbol_table_list.push_back(symbol_table);
             }*/
     }
    | /* empty */
    {
    
	decafStmtList *slist = new decafStmtList(); $$ = slist; 

        // cout << "EMPTY Field Decl\n";
    }
    ;

field_decl: field_list T_SEMICOLON
    { 
    	$$ = $1; 

     // cout << "FIELD LIST \n"; 
    }
    | type T_ID T_ASSIGN constant T_SEMICOLON
    { 
    
	$$ = new AssignGlobalVarAST((decafType)$1, *$2, $4); //delete $2; 

        // cout << "ASSIGNGLOBAL Field Decl\n";
        //symbol_table[*$2] = lineno;
    }
    ;

field_list: field_list T_COMMA T_ID
    {
    
	FieldDeclListAST *flist = (FieldDeclListAST *)$1; flist->new_sym(*$3, -1); $$ = flist; //delete $3;

         // cout << "IDONTKONW " << *$3 << "\n";
         //symbol_table[*$3] = lineno;  
    }
    | field_list T_COMMA T_ID T_LSB T_INTCONSTANT T_RSB
    { 
    	
	FieldDeclListAST *flist = (FieldDeclListAST *)$1; flist->new_sym(*$3, $5); $$ = flist; //delete $3;

    }
    | type T_ID
    { 
    
	$$ = new FieldDeclListAST(*$2, (decafType)$1, -1); //delete $2; 

        // cout << "REALLY FIeld Decl\n";
//        symbol_table[*$2] = lineno;
    }
    | type T_ID T_LSB T_INTCONSTANT T_RSB
    {
    
	$$ = new FieldDeclListAST(*$2, (decafType)$1, $4); delete $2; 

    }
    ;

method_decl_list: method_decl_list method_decl 
    {
    
	decafStmtList *slist = (decafStmtList *)$1; slist->push_back($2); $$ = slist;

    }
    | method_decl
    {
    	
	decafStmtList *slist = new decafStmtList(); slist->push_back($1); $$ = slist;

    }
    ;

method_decl: T_VOID T_ID T_LPAREN param_list T_RPAREN method_block
    {
    	
	cout << "==Method DECL  - VOID ==";
	$$ = new MethodDeclAST(voidTy, *$2, (TypedSymbolListAST *)$4, (MethodBlockAST *)$6); delete $2;
	$$->Codegen();
	symbol_table.clear();

    }
    | type T_ID T_LPAREN param_list T_RPAREN method_block
    {
    	cout << "==Method DECL - INT/BOOL ==";
	$$ = new MethodDeclAST((decafType)$1, *$2, (TypedSymbolListAST *)$4, (MethodBlockAST *)$6); delete $2;
	$$->Codegen();
	symbol_table.clear();

    }
    ;

method_type: T_VOID
    {
    
	$$ = voidTy;

    }
    | type
    {
    	
	$$ = $1;

    }
    ;

// Insert a symbol table in the list regardless
param_list: param_comma_list
    {
    
	$$ = $1; 

        // cout << "PARAM LIST\n"; 
        // Put to list
        symbol_table_list.push_back(symbol_table);
        symbol_table.clear();
    }
    | /* empty */
    { 

	$$ = NULL;

        // cout << "EMPTINESS OF PARAM\n";
        symbol_table_list.push_back(symbol_table);
        symbol_table.clear();
    }
    ;

param_comma_list: type T_ID T_COMMA param_comma_list
    { 
        
	TypedSymbolListAST *tlist = (TypedSymbolListAST *)$4; 
        tlist->push_front(*$2, (decafType)$1); 
        $$ = tlist;
        // delete $2; 

        // cout << "Param COMMA List " << *$2 << endl;
//        symbol_table[*$2] = lineno;
    }
    | type T_ID
    {
     
	$$ = new TypedSymbolListAST(*$2, (decafType)$1); //delete $2; 
        // cout << "REAL Param " << *$2 << endl;
        // Put to symbol_table
//        symbol_table[*$2] = lineno;
        }
    ;

type: T_INTTYPE
    {
    	
	$$ = intTy;

    }
    | T_BOOLTYPE
    {
    
	$$ = boolTy;
    }
    ;

block: T_LCB var_decl_list statement_list T_RCB
    {
    
	$$ = new BlockAST((decafStmtList *)$2, (decafStmtList *)$3);

    }

method_block: T_LCB var_decl_list statement_list T_RCB
    {
    	
	$$ = new MethodBlockAST((decafStmtList *)$2, (decafStmtList *)$3); 

        // pop up list
        // cout << "Size of list b4: " << symbol_table_list.size() << endl;
        symbol_table_list.pop_back();
        /*
        cout << "Size of list after method_decl: " << symbol_table_list.size() << endl;
        std::map<std::string, int> table = symbol_table_list.back();
            for (std::map<std::string, int>::iterator it = table.begin(); it!=table.end(); it++){
            cout << it->first << ", " << it->second << endl;
            }
        */
     }

// Method parameters and Variable declarations 
// will have the same symbol_table
var_decl_list: var_decl var_decl_list
    { 

	decafStmtList *slist = (decafStmtList *)$2; slist->push_front($1); $$ = slist; 

        // cout << "VarDecl_LList\n"; 
            // If the list is *one *, insert the symbol_table. Edit the list if there is one present.
            /* if (symbol_table_list.size() == 1){
            // Insert symbol_table intothe list
            symbol_table_list.push_back(symbol_table); //[*$2] = lineno;  
            } else if (symbol_table_list.size() > 1){*/
        // Edit back of the list
/*        for (std::map<std::string, int>::iterator it=symbol_table.begin(); it!=symbol_table.end(); it++){
             std::pair<std::map<std::string,int>::iterator,bool> ret;
            ret = symbol_table_list.back().insert( std::pair<std::string, int> (it->first, it->second) );
            if (!(ret.second)){ 
                symbol_table_list.back()[it->first] = it->second;
            //}
        }
        symbol_table.clear();
		// 
            
            cout << "Size of list after var_decl: " << symbol_table_list.size() << endl;
            cout << "Size of symbol_table after var_decl: " << symbol_table.size() << endl;
            
            std::map<std::string, int> table = symbol_table_list.back();
            for (std::map<std::string, int>::iterator it = table.begin(); it!=table.end(); it++){
            cout << it->first << ", " << it->second << endl;
            }
            */
            /* symbol_table_list.push_back(symbol_table);*/
         // }
    }
    | /* empty */
    { 
    
	decafStmtList *slist = new decafStmtList(); $$ = slist; 

    }
    ;

var_decl: var_list T_SEMICOLON
    {
    	
	$$ = $1; 

    // cout << "Var LIST\n";
    }

var_list: var_list T_COMMA T_ID
    { 
        
        TypedSymbolListAST *tlist = (TypedSymbolListAST *)$1; 
        tlist->new_sym(*$3); 
        $$ = tlist;
        //delete $3;
        
        // cout << "VarIDKCOMMA " << *$3 << "\n";
        //symbol_table[*$3] = lineno;
    }
    | type T_ID
    { 
        
	$$ = new TypedSymbolListAST(*$2, (decafType)$1); //delete $2; 

        // cout << "REALVarDecl\n";
        //symbol_table[*$2] = lineno;
	
	//Type *RetType = Builder.getInt32Ty();
	//AllocaInst *RetVal = Builder.CreateAlloca(RetType, 0, *$2);

	
	
//	verifyFunction(*TheFunction);
         }
    ;

statement_list: statement statement_list
    { 
    
	decafStmtList *slist = (decafStmtList *)$2; slist->push_front($1); $$ = slist; 

    }
    | /* empty */ 
    {
    
	decafStmtList *slist = new decafStmtList(); $$ = slist; 

    }
    ;

statement: assign T_SEMICOLON
    {
    	$$ = $1; 
    }
    | method_call T_SEMICOLON
    {
    	$$ = $1; 
    }
    | T_IF T_LPAREN expr T_RPAREN block T_ELSE block
    {
    	$$ = new IfStmtAST($3, (BlockAST *)$5, (BlockAST *)$7); 
    }
    | T_IF T_LPAREN expr T_RPAREN block 
    {
    	$$ = new IfStmtAST($3, (BlockAST *)$5, NULL); 
    }
    | T_WHILE T_LPAREN expr T_RPAREN block
    {
        $$ = new WhileStmtAST($3, (BlockAST *)$5); 
    }
    | T_FOR T_LPAREN assign_comma_list T_SEMICOLON expr T_SEMICOLON assign_comma_list T_RPAREN block
    {
        $$ = new ForStmtAST((decafStmtList *)$3, $5, (decafStmtList *)$7, (BlockAST *)$9); 
    }
    | T_RETURN T_LPAREN expr T_RPAREN T_SEMICOLON
    {
        $$ = new ReturnStmtAST($3); 
    }
    | T_RETURN T_LPAREN T_RPAREN T_SEMICOLON
    {
        $$ = new ReturnStmtAST(NULL); 
    }
    | T_RETURN T_SEMICOLON
    {
        $$ = new ReturnStmtAST(NULL); 
    }
    | T_BREAK T_SEMICOLON
    {
        $$ = new BreakStmtAST(); 
    }
    | T_CONTINUE T_SEMICOLON
    {
        $$ = new ContinueStmtAST(); 
    }
    | block
    {
        $$ = $1; 
    }
    ;

assign: T_ID T_ASSIGN expr
    {  
        
        $$ = new AssignVarAST(*$1, $3); //delete $1; 

        /*cout << " // using decl on line: " ;
        std::list< std::map<std::string, int> >::iterator it = symbol_table_list.end();
        it--;
        bool found = false;
        int num_iteration=0;
        while ( (!found) && !(num_iteration>symbol_table_list.size()) ){
        // it==symbol_table_list.begin())){
            if ( (*it).find(*$1) == (*it).end() ){  Not found  } 
            else { // Found
                cout << (*it)[*$1];
                found = true;
            }
            num_iteration++;
            it--;
        }
        // cout        << symbol_table_list.back()[*$1]; */
        }
    | T_ID T_LSB expr T_RSB T_ASSIGN expr
    { 
        
        $$ = new AssignArrayLocAST(*$1, $3, $6); delete $1; 

    }
    ;

method_call: T_ID T_LPAREN method_arg_list T_RPAREN
    {
        
        $$ = new MethodCallAST(*$1, (decafStmtList *)$3); delete $1; 


    }
    | T_ID T_LPAREN T_RPAREN
    {
        
        $$ = new MethodCallAST(*$1, (decafStmtList *)NULL); delete $1; 

    }
    ;

method_arg_list: method_arg
    {
        decafStmtList *slist = new decafStmtList(); slist->push_front($1); $$ = slist; 
    }
    | method_arg T_COMMA method_arg_list
    {
        decafStmtList *slist = (decafStmtList *)$3; slist->push_front($1); $$ = slist; 
    }
    ;

method_arg: expr
    {
        $$ = $1; 
    }
    | T_STRINGCONSTANT
    {

        $$ = new StringConstAST(*$1); delete $1; 

    }
    ;
   
assign_comma_list: assign
    {

        decafStmtList *slist = new decafStmtList(); slist->push_front($1); $$ = slist; 

    }
    | assign T_COMMA assign_comma_list
    {

        decafStmtList *slist = (decafStmtList *)$3; slist->push_front($1); $$ = slist; 

    }
    ;

rvalue: T_ID
    {

        $$ = new VariableExprAST(*$1); //delete $1; 

        /*cout << " // using decl on line: " ;
        std::list< std::map<std::string, int> >::iterator it = symbol_table_list.end();
        it--;
        bool found = false;
        int num_iteration=0;
        while ( (!found) && !(num_iteration>symbol_table_list.size()) ){
        // it==symbol_table_list.begin())){
            if ( (*it).find(*$1) == (*it).end() ){  Not found  } 
            else { // Found
                cout << (*it)[*$1];
                found = true;
            }
            num_iteration++;
            it--;
        }*/
    }
    | T_ID T_LSB expr T_RSB
    {

        $$ = new ArrayLocExprAST(*$1, $3); delete $1; 
    }
    ;

expr: rvalue
    {
        $$ = $1; 
    }
    | method_call 
    {
	// Required
        $$ = $1; 
    }
    | constant
    {
	// Required
        $$ = $1; 
    }
    | expr T_PLUS expr
    {
        $$ = new BinaryExprAST(T_PLUS, $1, $3); 
    }
    | expr T_MINUS expr
    {
        $$ = new BinaryExprAST(T_MINUS, $1, $3); 
    }
    | expr T_MULT expr
    {
        $$ = new BinaryExprAST(T_MULT, $1, $3); 
    }
    | expr T_DIV expr
    {
        $$ = new BinaryExprAST(T_DIV, $1, $3); 
    }
    | expr T_LEFTSHIFT expr
    {
        $$ = new BinaryExprAST(T_LEFTSHIFT, $1, $3); 
    }
    | expr T_RIGHTSHIFT expr
    {
        $$ = new BinaryExprAST(T_RIGHTSHIFT, $1, $3); 
    }
    | expr T_MOD expr
    {
        $$ = new BinaryExprAST(T_MOD, $1, $3); 
    }
    | expr T_LT expr
    {
        $$ = new BinaryExprAST(T_LT, $1, $3); 
    }
    | expr T_GT expr
    {
        $$ = new BinaryExprAST(T_GT, $1, $3); 
    }
    | expr T_LEQ expr
    {
        $$ = new BinaryExprAST(T_LEQ, $1, $3); 
    }
    | expr T_GEQ expr
    {
        $$ = new BinaryExprAST(T_GEQ, $1, $3); 
    }
    | expr T_EQ expr
    {
        $$ = new BinaryExprAST(T_EQ, $1, $3); 
    }
    | expr T_NEQ expr
    {
        $$ = new BinaryExprAST(T_NEQ, $1, $3); 
    }
    | expr T_AND expr
    {
        $$ = new BinaryExprAST(T_AND, $1, $3); 
    }
    | expr T_OR expr
    {
        $$ = new BinaryExprAST(T_OR, $1, $3); 
    }
    | T_MINUS expr %prec UMINUS 
    {
        $$ = new UnaryExprAST(T_MINUS, $2); 
    }
    | T_NOT expr
    {
        $$ = new UnaryExprAST(T_NOT, $2); 
    }
    | T_LPAREN expr T_RPAREN
    {
        $$ = $2; 
    }
    ;

constant: T_INTCONSTANT
    {
        $$ = new NumberExprAST($1); 
    }
    | T_CHARCONSTANT
    {
        $$ = new NumberExprAST($1); 
    }
    | bool_constant
    {
        $$ = $1; 
    }
    ;

bool_constant: T_TRUE
    {
        $$ = new BoolExprAST(true); 
    }
    | T_FALSE 
    {
        $$ = new BoolExprAST(false); 
    }
    ;

%%


// CODE GEN:
Value *ProgramAST::Codegen(){
    return 0;
}

Value *ExternAST::Codegen(){
    return 0;
}

Value *ClassAST::Codegen(){
    return 0;
}

Value *FieldDeclListAST::Codegen(){
    return 0;
}

Value *FieldDecl::Codegen(){
    return 0;
}

Value *AssignGlobalVarAST::Codegen(){
    return 0;
}

Value *MethodDeclAST::Codegen(){
    // Return type
    Type *returnTy = getLLVMType(ReturnType);
    
    // Create the function type
    // *note* consider functions with parameters.
    list<Type*> paramTy_list;
    // Iterate through the parameters/arguments
    TypedSymbolListAST *func_args = FunctionArgs;
    //list<TypedSymbol *> func_args_arglist = func_args->arglist;
   
    //list<TypedSymbol*>::iterator it = (FunctionArgs->arglist).begin();
    // for (list<TypedSymbol*>::iterator it = func_args_arglist.begin(); it!=func_args_arglist.end(); it++){
	//paramTy_list.push_back( getLLVMType( (*it)->Ty ) );
   // }
    FunctionType *funcTy = FunctionType::get(returnTy, false);
    
    // Create the function
    Function *TheFunction = Function::Create(funcTy, Function::ExternalLinkage, Name, TheModule);
    // Check if successful
    if (TheFunction == 0)  throw runtime_error("empty function block");

    // Create Basic Block
    BasicBlock *BB = BasicBlock::Create(getGlobalContext(), "entry", TheFunction);
    Builder.SetInsertPoint(BB);  // Set insertion point of instructions

    // -- Do other stuff here --  -> the function body
    Block->Codegen();  
   
    // Return statement
    if (ReturnType == intTy)		Builder.CreateRet( ConstantInt::get(getGlobalContext(), APInt(32,0)) );
    else if (ReturnType == voidTy)	Builder.CreateRetVoid();


    return 0;
}

Value *ContinueStmtAST::Codegen(){
    return 0;
}

Value *BreakStmtAST::Codegen(){
    return 0;
}

Value *ReturnStmtAST::Codegen(){
    return 0;
}

Value *ForStmtAST::Codegen(){
    return 0;
}

Value *WhileStmtAST::Codegen(){
    return 0;
}

Value *IfStmtAST::Codegen(){
    return 0;
}

Value *MethodBlockAST::Codegen(){
    // Codegen for function body

    // Call codegens of variable declarations
    // and statements
    Vars->Codegen();
    Statements->Codegen();
    
    return 0;
}

Value *BlockAST::Codegen(){
    return 0;
}

Value *ArrayLocExprAST::Codegen(){
    return 0;
}

Value *AssignArrayLocAST::Codegen(){
    return 0;
}

Value *AssignVarAST::Codegen(){
    // Retrieve value of the variable from the symboltable
    llvm::Value *varValue = this->Value->Codegen();
    //llvm::Value *varPointer = Module::getGlobalVariable(Name, true);

    //if (varPointer == 0){ cout << "Var NULL"; }
    //else { cout << "Var NOT NULL";}
    
    // ** CHECK if value is same type as the variable: not implemented right now **
    /*
    cout << "\nVar name: " << Name << endl;
    cout << "\n" << varValue->getType()->getTypeID();
    cout << "  " << symbol_table[Name]->getType()->getTypeID() << endl;
    if (varValue->getType() == symbol_table[Name]->getType()){
	return Builder.CreateStore(varValue, symbol_table[Name]);
    }
    else throw runtime_error("Mismatch type at line number " + lineno);
//    return 0;
    */
    return Builder.CreateStore(varValue, symbol_table[Name]);
}

Value *UnaryExprAST::Codegen(){
    return 0;
}

Value *BinaryExprAST::Codegen(){
    // Codegen for Binary expr: L op R

    llvm::Value *L = LHS->Codegen();
    llvm::Value *R = RHS->Codegen();
    if (L == 0 || R == 0) return 0;

    switch(Op){
	// -- Arithmetic Operations
	// As of now, can't deal with negative numbers
	case T_PLUS: return Builder.CreateAdd(L, R, "addtmp");
	case T_MINUS: return Builder.CreateSub(L, R, "subtmp");
	case T_MULT: return Builder.CreateMul(L, R, "multmp");
	case T_DIV: return Builder.CreateSDiv(L, R, "divtmp");
	case T_LEFTSHIFT: return Builder.CreateShl(L, R);
	case T_RIGHTSHIFT: return Builder.CreateLShr(L, R);
	case T_MOD: return Builder.CreateSRem(L, R);

	// -- Relational Operations
	case T_LT: return Builder.CreateICmpSLT(L, R);
	case T_GT: return Builder.CreateICmpSGT(L, R);
	case T_LEQ: return Builder.CreateICmpSLE(L, R);
	case T_GEQ: return Builder.CreateICmpSGE(L, R); 
	
	// -- Equallity Operations
	case T_EQ: return Builder.CreateICmpEQ(L, R);
	case T_NEQ: return Builder.CreateICmpNE(L, R);

	// -- Conditional Operations
	// Not sure what the output should be on:
	// 'true || true && false' <- Outputs false right now.
	case T_AND: return Builder.CreateAnd(L, R);
	case T_OR: return Builder.CreateOr(L, R);

	default: throw runtime_error("Unknown operator ");

    }
    
//    return 0;
}

Value *MethodCallAST::Codegen(){
    // COdegen for MethodCall here
   
    // Create funcitn
    Function *CalleeF = TheModule->getFunction(Name);
    if (CalleeF == 0) throw runtime_error("Unknown function");

    // Create Args
    std::vector<Value*> ArgsV;
//    std::list<decafAST *> argsit;
    // Handle empty args
    if (Args!=NULL) {
	for (list<decafAST *>::iterator argsit = Args->stmts.begin(); argsit!=Args->stmts.end(); argsit++){
	    ArgsV.push_back( (*argsit)->Codegen() );
	}
    } 
    //argsit = Args->stmts;
    else cout << "ARGS NULL!";
    // = Args->stmts;
    //for (list<decafAST *>::iterator argsit = (Args->stmts).begin(); argsit!=(Args->stmts).end(); argsit++){
//	ArgsV.push_back();
   // }
//    Builder.CreateCall(Function,Args);
    if (ArgsV.size()==0) cout << "ARGFUCKINGV NULL";
    else cout << "ARGSV not null";

    // Get Fucntiontype, then return call based on that
    llvm::Type *funcTy = CalleeF->getReturnType();
    //llvm::Type::TypeID funcTyID = funcTy->llvm::Type::TypeID;
    if (funcTy->getTypeID() == 0) return Builder.CreateCall(CalleeF, ArgsV);
    else return Builder.CreateCall(CalleeF, ArgsV, "calltmp");
    
    //return 0;
}

Value *VariableExprAST::Codegen(){
    // Load Instruction
    // Get variable from the symbol table
    return Builder.CreateLoad(symbol_table[Name], Name);
}

Value *BoolExprAST::Codegen(){
    // Codegen for bool constants
    
    return ConstantInt::get(getGlobalContext(), APInt(1, Val));
}

Value *StringConstAST::Codegen(){
    
    return 0;
}

Value *NumberExprAST::Codegen(){
    // Codegen for number constants
    
    return ConstantInt::get(getGlobalContext(), APInt(32, Val));
}

Value *decafStmtList::Codegen(){
    // Codegen for decafStmtList (list of decafs)

    // Iterate through the list
    for (std::list<decafAST*>::iterator it = stmts.begin(); it!=stmts.end(); it++){
        (*it) -> Codegen();
    }

    return 0;
}

Value *TypedSymbolListAST::Codegen(){
    // Iterate through the arglist
    for (std::list<TypedSymbol*>::iterator it = arglist.begin(); it!=arglist.end(); it++){
	(*it) -> Codegen();
    }

    return 0;
}

Value *TypedSymbol::Codegen(){
    // Var_decl!
    Type *RetType = getLLVMType(Ty);
    llvm::AllocaInst *Alloca = Builder.CreateAlloca(RetType, 0, Sym);

    symbol_table[Sym] =  Alloca;

  
    return 0;
}













int main() {
  // initialize LLVM
  LLVMContext &Context = getGlobalContext();
  // Make the module, which holds all the code.
  TheModule = new Module("module for very simple expressions", Context);
  // parse the input and create the abstract syntax tree
  int retval = yyparse();
  // Print out all of the generated code to stderr
  TheModule->dump();

  // parse the input and create the abstract syntax tree
  //int retval = yyparse();
  return(retval >= 1 ? 1 : 0);
}
