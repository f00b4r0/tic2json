//
//  tic.y
//
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	int yylex();
	int yylex_destroy();
	extern FILE *yyin;
	void yyerror(const char *);

static int hooked;
static char fdelim;

struct tic_field {
	char label[8];
	char *horodate;
	char *data;
};

struct tic_field *make_field(char *label, char *horodate, char *data)
{
	struct tic_field *field;

	field = malloc(sizeof(*field));
	if (!field)
		return NULL;

	strncpy(field->label, label, sizeof(field->label));
	free(label);
	field->horodate = horodate;
	field->data = data;

	return field;
}

void free_field(struct tic_field *field)
{
	free(field->horodate);
	free(field->data);
	free(field);
}

%}

%union {
	char *text;
	struct tic_field *field;
}

%verbose

%token TOK_STX TOK_ETX TOK_SEP
%token FIELD_START FIELD_OK FIELD_KO

%token <text> TOK_HDATE TOK_DATA

%token <text> ET_ADSC ET_VTIC ET_DATE ET_NGTF ET_LTARF
%token <text> ET_EAST ET_EASF01 ET_EASF02 ET_EASF03 ET_EASF04 ET_EASF05 ET_EASF06 ET_EASF07 ET_EASF08 ET_EASF09 ET_EASF10
%token <text> ET_EASD01 ET_EASD02 ET_EASD03 ET_EASD04 ET_EAIT ET_ERQ1 ET_ERQ2 ET_ERQ3 ET_ERQ4
%token <text> ET_IRMS1 ET_IRMS2 ET_IRMS3 ET_URMS1 ET_URMS2 ET_URMS3 ET_PREF ET_PCOUP
%token <text> ET_SINSTS ET_SINSTS1 ET_SINSTS2 ET_SINSTS3 ET_SMAXSN ET_SMAXSN1 ET_SMAXSN2 ET_SMAXSN3
%token <text> ET_SMAXSNM1 ET_SMAXSN1M1 ET_SMAXSN2M1 ET_SMAXSN3M1 ET_SINSTI ET_SMAXIN ET_SMAXINM1
%token <text> ET_CCASN ET_CCASNM1 ET_CCAIN ET_CCAINM1 ET_UMOY1 ET_UMOY2 ET_UMOY3 ET_STGE ET_DPM1 ET_FPM1 ET_DPM2 ET_FPM2 ET_DPM3 ET_FPM3
%token <text> ET_MSG1 ET_MSG2 ET_PRM ET_RELAIS ET_NTARF ET_NJOURF ET_NJOURFP1 ET_PJOURFP1 ET_PPOINTE

%type <text> etiquette_horodate etiquette_nodate
%type <field> field_horodate field_nodate field

%destructor { free($$); } <text>
%destructor { free_field($$); } <field>
%destructor { } <>

%%

frames:
	frame
	| frames frame
;

frame:
	TOK_STX datasets TOK_ETX
		{
			if (!hooked) { hooked=1; printf("[\n["); }
			else { fdelim=' '; printf ("],\n["); }
		}
	| error TOK_ETX	{ hooked=0; }
;

datasets:
	dataset
	| datasets dataset
;

dataset:
	FIELD_START field FIELD_OK
		{
			if (!$2) YYABORT;	// OOM
			if (hooked) {
				printf("%c{ \"label\": \"%.8s\", \"data\": \"%s\"", fdelim, $2->label, $2->data ? $2->data : "");
				if ($2->horodate)
					printf(", \"horodate\": \"%s\"", $2->horodate);
				printf(" }");
				fdelim = ',';
			}
			free_field($2);
		}
	| FIELD_START field FIELD_KO	{ if (!$2) YYABORT; printf("invalid checksum\n"); free_field($2); }
	| FIELD_START error FIELD_OK
	| FIELD_START error FIELD_KO
;

field: 	field_horodate
	| field_nodate
;

field_horodate:
	etiquette_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_DATA TOK_SEP	{ $$ = make_field($1, $3, $5); }
	| etiquette_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_SEP	{ $$ = make_field($1, $3, NULL); }
;

field_nodate:
	etiquette_nodate TOK_SEP TOK_DATA TOK_SEP	{ $$ = make_field($1, NULL, $3); }
;

etiquette_horodate:
	ET_DATE
	| ET_SMAXSN
	| ET_SMAXSN1
	| ET_SMAXSN2
	| ET_SMAXSN3
	| ET_SMAXSNM1
	| ET_SMAXSN1M1
	| ET_SMAXSN2M1
	| ET_SMAXSN3M1
	| ET_SMAXIN
	| ET_SMAXINM1
	| ET_CCASN
	| ET_CCASNM1
	| ET_CCAIN
	| ET_CCAINM1
	| ET_UMOY1
	| ET_UMOY2
	| ET_UMOY3
	| ET_DPM1
	| ET_FPM1
	| ET_DPM2
	| ET_FPM2
	| ET_DPM3
	| ET_FPM3
;

etiquette_nodate:
	ET_ADSC
	| ET_VTIC
	| ET_NGTF
	| ET_LTARF
	| ET_EAST
	| ET_EASF01
	| ET_EASF02
	| ET_EASF03
	| ET_EASF04
	| ET_EASF05
	| ET_EASF06
	| ET_EASF07
	| ET_EASF08
	| ET_EASF09
	| ET_EASF10
	| ET_EASD01
	| ET_EASD02
	| ET_EASD03
	| ET_EASD04
	| ET_EAIT
	| ET_ERQ1
	| ET_ERQ2
	| ET_ERQ3
	| ET_ERQ4
	| ET_IRMS1
	| ET_IRMS2
	| ET_IRMS3
	| ET_URMS1
	| ET_URMS2
	| ET_URMS3
	| ET_PREF
	| ET_PCOUP
	| ET_SINSTS
	| ET_SINSTS1
	| ET_SINSTS2
	| ET_SINSTS3
	| ET_SINSTI
	| ET_STGE
	| ET_MSG1
	| ET_MSG2
	| ET_PRM
	| ET_RELAIS
	| ET_NTARF
	| ET_NJOURF
	| ET_NJOURFP1
	| ET_PJOURFP1
	| ET_PPOINTE
;


%%

int main(int argc, char **argv)
{
	hooked = 0;
	fdelim = ' ';
	yyparse();
	printf("]\n]\n");
	yylex_destroy();
	return 0;
}

void yyerror(const char * s)
{
}
