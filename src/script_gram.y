%{
#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <limits.h>

#include "script_gram.tab.h"

int yylex(YYSTYPE* yylval_param, YYLTYPE* yylloc_param, void* ctx, yyscan_t yyscanner);

int yyerror(YYLTYPE* llocp, struct script_parse_ctx* ctx, yyscan_t scanner, const char* msg) {
    script_parse_ctx_add_diag(ctx, &(struct script_diag) {.kind = DIAG_ERR,
            .line = llocp->first_line,
            .col = llocp->first_column,
            .msg = strdup(msg)
        });
    return 0;
}
%}

%code requires {
    /**
     * Auto-generated from script_gram.y -- do not edit this file!
     */
    #include "script_parse_ctx.h"

    #ifndef YYSTYPE
        #define YYSTYPE SCRIPT_STYPE
    #endif
    #ifndef YYLTYPE
        #define YYLTYPE SCRIPT_LTYPE
    #endif

    #ifndef YYSCAN_T
    #define YYSCAN_T
    typedef void* yyscan_t;
    #endif

    /* Auto-increment yyloc */
    #define YY_USER_ACTION \
        yylloc->first_line = yylloc->last_line; \
        yylloc->first_column = yylloc->last_column; \
        for(int i = 0; yytext[i] != '\0'; i++) { \
                if(yytext[i] == '\n') { \
                        yylloc->last_line++; \
                        yylloc->last_column = 0; \
                } \
                else { \
                        yylloc->last_column++; \
                } \
        }
}

%define api.pure full
%define api.prefix {script_}
%define api.token.prefix {SCRIPT_}

%define parse.error verbose
%locations

%initial-action /* YYLOC @$ */ {
    @$.first_column = 1;
    @$.last_column = 1;
    @$.first_line = 1;
    @$.last_line = 1;
}

%param {struct script_parse_ctx* ctx} {yyscan_t scanner}

%union {
    uintmax_t uval;
    char* sval;
    struct script_stmt stmt;
    struct script_arg_list arg_list;
    struct script_arg arg;
    struct script_byte_stmt byte;
    struct script_begin_end_stmt begin_end;
}

%destructor {assert($$); free($$);} <sval>

/* Terminals */
%token BYTE BEGIN END
%token <uval> OP
%token <sval> ID STR
%token <uval> NUM

/* Non-terminals */
%type <stmt> STMT ANY_STMT
%type <arg_list> ARGS
%type <arg> ARG
%type <byte> BYTE_STMT;
%type <begin_end> BEGIN_END_STMT;
%%

/* If we encounter an error here, keep parsing. We'll abort later if we see the diags */

STMTS:
    STMTS ANY_STMT {
        if (!script_ctx_add_stmt(ctx, &$2))
            yyerror(&@$, ctx, scanner, "Too many statements");
    } | ';' | %empty ;

ANY_STMT:
    STMT {
        $$ = $1;
    } | ID ':' STMT { /* Labeled */
        $3.label = strdup($1);
        $$ = $3;
    };

STMT: BEGIN_END_STMT {
        $$ = (struct script_stmt){
            .ty = STMT_TY_BEGIN_END, .label = NULL, .line = @$.first_line, .begin_end = $1
        };
    } | BYTE_STMT {
        $$ = (struct script_stmt){
            .ty = STMT_TY_BYTE, .label = NULL, .line = @$.first_line, .byte = $1
        };
    } | ID '(' ARGS ')' ';' {
        $$ = (struct script_stmt){.ty = STMT_TY_OP, .label = NULL, .line = @$.first_line};
        if (!script_op_idx($1, &$$.op.idx))
            yyerror(&@$, ctx, scanner, "Unrecognised operation");
        $$.op.args = $3;
    };

BEGIN_END_STMT: '.' BEGIN ID {
        $$ = (struct script_begin_end_stmt){.begin = true, .section = strdup($3)};
    } | '.' END ID {
        $$ = (struct script_begin_end_stmt){.begin = false, .section = strdup($3)};
    };

BYTE_STMT: '.' NUM BYTE NUM {
        $$ = (struct script_byte_stmt){.n = $2, .val = $4};
    } | '.' BYTE NUM {
        $$ = (struct script_byte_stmt){.n = 1, .val = $3};
    };

ARGS: ARGS ',' ARG {
        /* Need to check it this early, as we won't be able to notice this later */
        if (!script_arg_list_add_arg(&$1, &$3))
            yyerror(&@$, ctx, scanner, "Too many arguments");
        $$ = $1;
    } | ARG {
        $$ = (struct script_arg_list){.nargs = 1, .args = {$1}};
    } | %empty {
        $$ = (struct script_arg_list){.nargs = 0};
    };

ARG: NUM {
        $$ = (struct script_arg){.type = ARG_TY_NUM, .num = $1};
    } | STR {
        $$ = (struct script_arg){.type = ARG_TY_STR, .str = strdup($1)};
    } | '(' NUM ')' STR {
        $$ = (struct script_arg){.type = ARG_TY_NUMBERED_STR, .numbered_str = {$2, strdup($4)}};
    } | ID {
        $$ = (struct script_arg){.type = ARG_TY_LABEL, .label = strdup($1)};
    };
%%

// yydebug = 1;
