//
//  tic.y
//
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/*
 * Outputs as JSON a series of frames formatted as a list of fields.
 * Fields are { "label": "xxx", "data": "xxx", horodate: "xxx" } with horodate optional and data possibly empty.
 * Data errors can result in some/all fields being omitted in the output frame: the JSON list is then empty.
 * Output JSON is guaranteed to always be valid for each frame.
 * This parser complies with Enedis-NOI-CPT_54E.pdf version 3.
 */

%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <inttypes.h>
	#include <unistd.h>
	#include "tic.h"

	int yylex();
	int yylex_destroy();
	extern FILE *yyin;
	void yyerror(const char *);

static int hooked;
static char fdelim;
static int mask_allzeros;

void make_field(struct tic_field *field, enum f_type type, char *label, char *horodate, char *data)
{
	if (!field)
		return;

	field->label = label;
	field->horodate = horodate;
	field->type = type;
	switch (type) {
		case F_STRING:
			field->data.s = data;
			break;
		case F_INT:
			field->data.i = (int)strtol(data, NULL, 10);
			free(data);
			break;
		case F_HEX:
			field->data.i = (int)strtol(data, NULL, 16);
			free(data);
			break;
		default:
			break;
	}
}

void print_field(struct tic_field *field)
{
	if (mask_allzeros && (F_INT == field->type) && (0 == field->data.i))
		return;

	printf("%c{ \"label\": \"%.8s\", \"data\": ", fdelim, field->label);
	switch (field->type) {
		case F_STRING:
			printf("\"%s\"", field->data.s ? field->data.s : "");
			break;
		case F_INT:
		case F_HEX:
			printf("%d", field->data.i);
			break;
	}
	if (field->horodate)
		printf(", \"horodate\": \"%s\"", field->horodate);
	printf(" }");
}

void free_field(struct tic_field *field)
{
	free(field->label);
	free(field->horodate);
	switch (field->type) {
		case F_STRING:
			free(field->data.s);
			break;
		default:
			break;
	}
}

%}

%union {
	char *text;
	struct tic_field field;
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

%type <text> etiquette_str_horodate etiquette_str_nodate etiquette_int_horodate etiquette_int_nodate etiquette_hex_nodate
%type <field> field_horodate field_nodate field

%destructor { free($$); } <text>
%destructor { free_field(&$$); } <field>
%destructor { } <>

%%

frames:
	frame
	| frames frame
;

frame:
	TOK_STX datasets TOK_ETX
		{
			if (!hooked) { hooked=1; printf("["); }
			else { fdelim=' '; printf ("]\n["); }
		}
	| error TOK_ETX
		{
			if (hooked) { fdelim=' '; printf ("]\n["); }
			fprintf(stderr, "frame error\n");
			yyerrok;
		}
;

datasets:
	error		{ fprintf(stderr, "dataset error\n"); }
	| dataset
	| datasets dataset
;

dataset:
	FIELD_START field FIELD_OK
		{
			if (hooked) {
				print_field(&$2);
				fdelim = ',';
			}
			free_field(&$2);
		}
	| FIELD_START field FIELD_KO	{ fprintf(stderr, "dataset invalid checksum\n"); free_field(&$2); }
	| FIELD_START error FIELD_OK	{ fprintf(stderr, "unrecognized dataset\n"); yyerrok; }
;

field: 	field_horodate
	| field_nodate
;

field_horodate:
	etiquette_str_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_SEP	{ make_field(&$$, F_STRING, $1, $3, NULL); }
	| etiquette_str_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_STRING, $1, $3, $5); }
	| etiquette_int_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_INT, $1, $3, $5); }
;

field_nodate:
	etiquette_str_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_STRING, $1, NULL, $3); }
	| etiquette_int_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_INT, $1, NULL, $3); }
	| etiquette_hex_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_HEX, $1, NULL, $3); }
;

etiquette_str_horodate:
	ET_DATE
	| ET_DPM1
	| ET_FPM1
	| ET_DPM2
	| ET_FPM2
	| ET_DPM3
	| ET_FPM3
;

etiquette_int_horodate:
	ET_SMAXSN
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
;

etiquette_str_nodate:
	ET_ADSC
	| ET_VTIC
	| ET_NGTF
	| ET_LTARF
	| ET_MSG1
	| ET_MSG2
	| ET_PRM
	| ET_PJOURFP1
	| ET_PPOINTE
;

etiquette_hex_nodate:
	ET_STGE
;

etiquette_int_nodate:
	ET_EAST
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
	| ET_RELAIS
	| ET_NTARF
	| ET_NJOURF
	| ET_NJOURFP1
;


%%

int main(int argc, char **argv)
{
	int ch;

	hooked = 0;
	fdelim = ' ';
	mask_allzeros = 0;

	while ((ch = getopt(argc, argv, "z")) != -1) {
		switch (ch) {
		case 'z':
			mask_allzeros = 1;
			break;
		}
	}
	argc -= optind;
	argv += optind;

	yyparse();
	printf("]\n");
	yylex_destroy();

	return 0;
}

void yyerror(const char * s)
{
}
