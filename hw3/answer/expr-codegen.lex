%{
#include "decaf-defs.h"
#include "expr-codegen.tab.h"
#include <cstring>
#include <string>
#include <sstream>
#include <iostream>

using namespace std;

int lineno = 1;
int tokenpos = 1;

string remove_newlines (string s) {
  string newstring;
  for (string::iterator i = s.begin(); i != s.end(); i++) {
    switch(*i) {
    case '\n':
      lineno += 1; tokenpos = 0;
      newstring.push_back('\\');
      newstring.push_back('n');
      break;
    case '(':
      newstring.push_back('\\');
      newstring.push_back('(');
      break;
    case ')':
      newstring.push_back('\\');
      newstring.push_back(')');
      break;
    default:
      newstring.push_back(*i);
    }
  }
  return newstring;
}

void process_ws() {
  tokenpos += yyleng;
  string lexeme(yytext);
  lexeme = remove_newlines(lexeme);
}



string *process_string (const char *s) {
  string *ns = new string("");
  size_t len = strlen(s);
  // remove the double quotes, use s[1..len-1]
  for (int i = 1; i < len-1; i++) {
    if (s[i] == '\\') {
      i++;
      switch(s[i]) {
      case 't': ns->push_back('\t'); break;
      case 'v': ns->push_back('\v'); break;
      case 'r': ns->push_back('\r'); break;
      case 'n': ns->push_back('\n'); break;
      case 'a': ns->push_back('\a'); break;
      case 'f': ns->push_back('\f'); break;
      case 'b': ns->push_back('\b'); break;
      case '\\': ns->push_back('\\'); break;
      case '\'': ns->push_back('\''); break;
      case '\"': ns->push_back('\"'); break;
      default: throw runtime_error("unknown char escape\n");  
      }
    } else {
      ns->push_back(s[i]);
    }
  }
  return ns;
}

int get_charconstant(const char *s) {
  if (s[1] == '\\') { // backslashed char
    switch(s[2]) {
    case 't': return (int)'\t';
    case 'v': return (int)'\v';
    case 'r': return (int)'\r';
    case 'n': return (int)'\n';
    case 'a': return (int)'\a';
    case 'f': return (int)'\f';
    case 'b': return (int)'\b';
    case '\\': return (int)'\\';
    case '\'': return (int)'\'';
    default: throw runtime_error("unknown char constant\n");
    }
  } else {
    return (int)s[1];
  }
}

int get_intconstant(const char *s) {
  if ((s[0] == '0') && (s[1] == 'x')) {
    int x;
    sscanf(s, "%x", &x);
    return x;
  } else {
    return atoi(s);
  }
}

%}

/* regexp definitions */


letter			[a-zA-Z_]
decimal_digit		[0-9]
A			[a-zA-Z_0-9]
hex_digit		[a-fA-F0-9]
digit			[0-9]
newline			[\n]
carriage_return 	[\r]
horizontal_tab  	[\t]
vertical_tab    	[\v]
form_feed       	[\f]
space           	[ ]
whitespace		[ \t\v\n\f\r]
bell			[\a]
backspace		[\b]

decimal_lit		{decimal_digit}+
hex_lit			(0[xX]){hex_digit}+

string_lit		\"(\\([^"\\\n])|(\\['"\\nrtvfab]))*\"



escaped_char		(\\['"\\nrtvfab])

chars    [ !\"#\$%&\(\)\*\+,\-\.\/0-9:;\<=>\?\@A-Z\[\]\^\_\`a-z\{\|\}\~\t\v\r\n\a\f\b]
charesc  \\[\'tvrnafb\\]
stresc   \\[\'\"tvrnafb\\]

%%
  /*
    Pattern definitions for all tokens 
  */

"//"([^\\\n])*\n			{ process_ws(); } /* ignore comments */

"bool"					{ cout << yytext; return T_BOOLTYPE; }
"break"					{ cout << yytext; return T_BREAK; }
"class"					{ cout << yytext; return T_CLASS; }
"continue"				{ cout << yytext; return T_CONTINUE; }
"else"					{ cout << yytext; return T_ELSE; }
"extends"				{ cout << yytext; return T_EXTENDS; }
"extern"				{ cout << yytext; return T_EXTERN; }
"false"					{ cout << yytext; return T_FALSE; }
"for"					{ cout << yytext; return T_FOR; }
"if"					{ cout << yytext; return T_IF; }
"int"					{ cout << yytext; return T_INTTYPE; }
"new"					{ cout << yytext; return T_NEW; }
"null"					{ cout << yytext; return T_NULL; }
"return"				{ cout << yytext; return T_RETURN; }
"string"				{ cout << yytext; return T_STRINGTYPE; }
"true"					{ cout << yytext; return T_TRUE; }
"void"					{ cout << yytext; return T_VOID; }
"while"					{ cout << yytext; return T_WHILE; }




('{chars}')|('{charesc}')  		{ cout << yytext; yylval.number = get_charconstant(yytext); return T_CHARCONSTANT; }


(0x[0-9a-fA-F]+)|([0-9]+)  		{ cout << yytext; yylval.number = get_intconstant(yytext); return T_INTCONSTANT; }

\"([^\n\"\\]*{stresc}?)*\" 		{ cout << yytext; yylval.sval = process_string(yytext); return T_STRINGCONSTANT; }


"&&"					{ cout << yytext; return T_AND; }
"="					{ cout << yytext; return T_ASSIGN; }
","					{ cout << yytext; return T_COMMA; }
"/"					{ cout << yytext; return T_DIV; }
"."					{ cout << yytext; return T_DOT; }
"=="					{ cout << yytext; return T_EQ; }
">="					{ cout << yytext; return T_GEQ; }
">"					{ cout << yytext; return T_GT; }
"{"					{ cout << yytext; return T_LCB; }
"<<"					{ cout << yytext; return T_LEFTSHIFT; }
"<="					{ cout << yytext; return T_LEQ; }
"("					{ cout << yytext; return T_LPAREN; }
"["					{ cout << yytext; return T_LSB; }
"<"					{ cout << yytext; return T_LT; }
"-"					{ cout << yytext; return T_MINUS; }
"%"					{ cout << yytext; return T_MOD; }
"*"					{ cout << yytext; return T_MULT; }
"!="					{ cout << yytext; return T_NEQ; }
"!"					{ cout << yytext; return T_NOT; }
"||"					{ cout << yytext; return T_OR; }
"+"					{ cout << yytext; return T_PLUS; }
"}"					{ cout << yytext; return T_RCB; }
">>"					{ cout << yytext; return T_RIGHTSHIFT; }
")"					{ cout << yytext; return T_RPAREN; }
"]"					{ cout << yytext; return T_RSB; }
";"					{ cout << yytext; return T_SEMICOLON; }

[a-zA-Z\_][a-zA-Z\_0-9]*   		{ cout << yytext; yylval.sval = new string(yytext); return T_ID; } /* note that identifier pattern must be after all keywords */

[\n]        { lineno++; cout << yytext; }

\'(\\['"\\nrtvfab]|[^'\\\n])(\\['"\\nrtvfab]|[^'\\\n])+\'	{ cerr << "Error: char constant length is greater than one" << endl; exit(1); }

\'\'					{ cerr << "Error: char constant has zero width" << endl; exit(1); }

\'\\\'					{ cerr << "Error: unterminated char constant" << endl; exit(1); }

\'[^\'\n][^\'\n][\n]			{ cerr << "Error: unterminated char constant" << endl; exit(1); }

\"[^\"]*[\n]				{ cerr << "Error: newline in string constant" << endl; exit(1);}

\"\\\"					{ cerr << "Error: newline in string constant" << endl; exit(1);}




(\"([^"\\\n]|(\\['"\\nrtvfab]))*(\\[^'"\\nrtvfab])+([^"\\\n]|(\\['"\\nrtvfab]))*\")	{ cerr << "Error: unknown escape sequence in string constant" << endl; exit(1);}





%%

int yyerror(const char *s) {
  cerr << lineno << ": " << s << " at " << yytext << endl;
  return 1;
}

