//
//  tic.y
//
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/*
 * Outputs as JSON a series of frames formatted as a list of fields.
 * Fields are { "label": "xxx", "desc": "xxx", "unit": "xxx", "data": "xxx", horodate: "xxx" }
 * with horodate optional, unit and data possibly empty and data being either quoted string or number.
 * Data errors can result in some/all fields being omitted in the output frame: the JSON list is then empty.
 * Output JSON is guaranteed to always be valid for each frame. By default only frames are separated with newlines.
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
static int optflags;
static unsigned int skipframes, framecount;

enum {
	OPT_MASKZEROES	= 0x01,
	OPT_CRFIELD	= 0x02,
};

static const char * tic_units[] = {
	[U_SANS]	= "",
	[U_WH]		= "Wh",
	[U_VARH]	= "VArh",
	[U_A]		= "A",
	[U_V]		= "V",
	[U_KVA]		= "kVA",
	[U_VA]		= "VA",
	[U_W]		= "W",
};

void make_field(struct tic_field *field, enum f_type type, const struct tic_etiquette *etiq, char *horodate, char *data)
{
	if (!field)
		return;

	field->type = type;
	field->horodate = horodate;
	memcpy(&field->etiq, etiq, sizeof(field->etiq));

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
	if (framecount)
		return;

	if ((optflags & OPT_MASKZEROES) && (F_INT == field->type) && (0 == field->data.i))
		return;

	printf("%c{ \"label\": \"%.8s\", \"desc\": \"%s\", \"unit\": \"%s\", \"data\": ", fdelim, field->etiq.label, field->etiq.desc, tic_units[field->etiq.unit]);
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
	if (optflags & OPT_CRFIELD)
		printf("\n");
}

void free_field(struct tic_field *field)
{
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
	const char *label;
	struct tic_etiquette etiq;
	struct tic_field field;
}

%verbose

%token TOK_STX TOK_ETX TOK_SEP
%token FIELD_START FIELD_OK FIELD_KO

%token <text> TOK_HDATE TOK_DATA

%token <label> ET_ADSC ET_VTIC ET_DATE ET_NGTF ET_LTARF
%token <label> ET_EAST ET_EASF01 ET_EASF02 ET_EASF03 ET_EASF04 ET_EASF05 ET_EASF06 ET_EASF07 ET_EASF08 ET_EASF09 ET_EASF10
%token <label> ET_EASD01 ET_EASD02 ET_EASD03 ET_EASD04 ET_EAIT ET_ERQ1 ET_ERQ2 ET_ERQ3 ET_ERQ4
%token <label> ET_IRMS1 ET_IRMS2 ET_IRMS3 ET_URMS1 ET_URMS2 ET_URMS3 ET_PREF ET_PCOUP
%token <label> ET_SINSTS ET_SINSTS1 ET_SINSTS2 ET_SINSTS3 ET_SMAXSN ET_SMAXSN1 ET_SMAXSN2 ET_SMAXSN3
%token <label> ET_SMAXSNM1 ET_SMAXSN1M1 ET_SMAXSN2M1 ET_SMAXSN3M1 ET_SINSTI ET_SMAXIN ET_SMAXINM1
%token <label> ET_CCASN ET_CCASNM1 ET_CCAIN ET_CCAINM1 ET_UMOY1 ET_UMOY2 ET_UMOY3 ET_STGE ET_DPM1 ET_FPM1 ET_DPM2 ET_FPM2 ET_DPM3 ET_FPM3
%token <label> ET_MSG1 ET_MSG2 ET_PRM ET_RELAIS ET_NTARF ET_NJOURF ET_NJOURFP1 ET_PJOURFP1 ET_PPOINTE

%type <etiq> etiquette_str_horodate etiquette_str_nodate etiquette_int_horodate etiquette_int_nodate etiquette_hex_nodate
%type <field> field_horodate field_nodate field

%destructor { free($$); } <text>
%destructor { free_field(&$$); } <field>
%destructor { } <> <*>

%%

frames:
	frame
	| frames frame
		{
			if (hooked && !framecount--) {
				framecount = skipframes;
				printf ("]\n[");
			}
			fdelim=' ';
		}
;

frame:
	TOK_STX datasets TOK_ETX	{ if (!hooked) { hooked=1; printf("["); } }
	| error TOK_ETX			{ fprintf(stderr, "frame error\n"); yyerrok; }
;

datasets:
	error				{ fprintf(stderr, "dataset error\n"); }
	| dataset
	| datasets dataset
;

dataset:
	FIELD_START field FIELD_OK	{ if (hooked) { print_field(&$2); fdelim = ','; } free_field(&$2); }
	| FIELD_START field FIELD_KO	{ fprintf(stderr, "dataset invalid checksum\n"); free_field(&$2); }
	| FIELD_START error FIELD_OK	{ fprintf(stderr, "unrecognized dataset\n"); yyerrok; }
;

field: 	field_horodate
	| field_nodate
;

field_horodate:
	etiquette_str_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_SEP		{ make_field(&$$, F_STRING, &$1, $3, NULL); }
	| etiquette_str_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_STRING, &$1, $3, $5); }
	| etiquette_int_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_INT, &$1, $3, $5); }
;

field_nodate:
	etiquette_str_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_STRING, &$1, NULL, $3); }
	| etiquette_int_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_INT, &$1, NULL, $3); }
	| etiquette_hex_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, F_HEX, &$1, NULL, $3); }
;

etiquette_str_horodate:
	ET_DATE		{ $$.unit=U_SANS; $$.label=$1; $$.desc="Date et heure courante"; }
	| ET_DPM1	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Début Pointe Mobile 1"; }
	| ET_FPM1	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Fin Pointe Mobile 1"; }
	| ET_DPM2	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Début Pointe Mobile 2"; }
	| ET_FPM2	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Fin Pointe Mobile 2"; }
	| ET_DPM3	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Début Pointe Mobile 3"; }
	| ET_FPM3	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Fin Pointe Mobile 3"; }
;

etiquette_int_horodate:
	ET_SMAXSN	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n"; }
	| ET_SMAXSN1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n phase 1"; }
	| ET_SMAXSN2	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n phase 2"; }
	| ET_SMAXSN3	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n phase 3"; }
	| ET_SMAXSNM1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1"; }
	| ET_SMAXSN1M1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1 phase 1"; }
	| ET_SMAXSN2M1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1 phase 2"; }
	| ET_SMAXSN3M1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1 phase 3"; }
	| ET_SMAXIN	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max injectée n"; }
	| ET_SMAXINM1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. max injectée n-1"; }
	| ET_CCASN	{ $$.unit=U_W; $$.label=$1; $$.desc="Point n de la courbe de charge active soutirée"; }
	| ET_CCASNM1	{ $$.unit=U_W; $$.label=$1; $$.desc="Point n-1 de la courbe de charge active soutirée"; }
	| ET_CCAIN	{ $$.unit=U_W; $$.label=$1; $$.desc="Point n de la courbe de charge active injectée"; }
	| ET_CCAINM1	{ $$.unit=U_W; $$.label=$1; $$.desc="Point n-1 de la courbe de charge active injectée"; }
	| ET_UMOY1	{ $$.unit=U_V; $$.label=$1; $$.desc="Tension moy. ph. 1"; }
	| ET_UMOY2	{ $$.unit=U_V; $$.label=$1; $$.desc="Tension moy. ph. 2"; }
	| ET_UMOY3	{ $$.unit=U_V; $$.label=$1; $$.desc="Tension moy. ph. 3"; }
;

etiquette_str_nodate:
	ET_ADSC		{ $$.unit=U_SANS; $$.label=$1; $$.desc="Adresse Secondaire du Compteur"; }
	| ET_VTIC	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Version de la TIC"; }
	| ET_NGTF	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Nom du calendrier tarifaire fournisseur"; }
	| ET_LTARF	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Libellé tarif fournisseur en cours"; }
	| ET_MSG1	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Message court"; }
	| ET_MSG2	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Message Ultra court"; }
	| ET_PRM	{ $$.unit=U_SANS; $$.label=$1; $$.desc="PRM"; }
	| ET_PJOURFP1	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Profil du prochain jour calendrier fournisseur"; }
	| ET_PPOINTE	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Profil du prochain jour de pointe"; }
;

etiquette_hex_nodate:
	ET_STGE		{ $$.unit=U_SANS; $$.label=$1; $$.desc="Registre de Statuts"; }
;

etiquette_int_nodate:
	ET_EAST		{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée totale"; }
	| ET_EASF01	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 01"; }
	| ET_EASF02	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 02"; }
	| ET_EASF03	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 03"; }
	| ET_EASF04	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 04"; }
	| ET_EASF05	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 05"; }
	| ET_EASF06	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 06"; }
	| ET_EASF07	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 07"; }
	| ET_EASF08	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 08"; }
	| ET_EASF09	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 09"; }
	| ET_EASF10	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 10"; }
	| ET_EASD01	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 01"; }
	| ET_EASD02	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 02"; }
	| ET_EASD03	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 03"; }
	| ET_EASD04	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 04"; }
	| ET_EAIT	{ $$.unit=U_WH; $$.label=$1; $$.desc="Energie active injectée totale"; }
	| ET_ERQ1	{ $$.unit=U_VARH; $$.label=$1; $$.desc="Energie réactive Q1 totale"; }
	| ET_ERQ2	{ $$.unit=U_VARH; $$.label=$1; $$.desc="Energie réactive Q2 totale"; }
	| ET_ERQ3	{ $$.unit=U_VARH; $$.label=$1; $$.desc="Energie réactive Q3 totale"; }
	| ET_ERQ4	{ $$.unit=U_VARH; $$.label=$1; $$.desc="Energie réactive Q4 totale"; }
	| ET_IRMS1	{ $$.unit=U_A; $$.label=$1; $$.desc="Courant efficace, phase 1"; }
	| ET_IRMS2	{ $$.unit=U_A; $$.label=$1; $$.desc="Courant efficace, phase 2"; }
	| ET_IRMS3	{ $$.unit=U_A; $$.label=$1; $$.desc="Courant efficace, phase 3"; }
	| ET_URMS1	{ $$.unit=U_V; $$.label=$1; $$.desc="Tension efficace, phase 1"; }
	| ET_URMS2	{ $$.unit=U_V; $$.label=$1; $$.desc="Tension efficace, phase 2"; }
	| ET_URMS3	{ $$.unit=U_V; $$.label=$1; $$.desc="Tension efficace, phase 3"; }
	| ET_PREF	{ $$.unit=U_KVA; $$.label=$1; $$.desc="Puissance app. de référence (PREF)"; }
	| ET_PCOUP	{ $$.unit=U_KVA; $$.label=$1; $$.desc="Puissance app. de coupure (PCOUP)"; }
	| ET_SINSTS	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée"; }
	| ET_SINSTS1	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée phase 1"; }
	| ET_SINSTS2	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée phase 2"; }
	| ET_SINSTS3	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée phase 3"; }
	| ET_SINSTI	{ $$.unit=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée injectée"; }
	| ET_RELAIS	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Relais"; }
	| ET_NTARF	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Numéro de l'index tarifaire en cours"; }
	| ET_NJOURF	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Numéro du jour en cours calendrier fournisseur"; }
	| ET_NJOURFP1	{ $$.unit=U_SANS; $$.label=$1; $$.desc="Numéro du prochain jour calendrier fournisseur"; }
;


%%

void usage(char *progname)
{
	printf("usage: %s [-hrz]\n"
		" -h\t\t"	"shows this help message\n"
		" -n\t\t"	"separates each field with a newline for readability\n"
		" -s <number>\t""prints every <number> frame\n"
		" -z\t\t"	"masks all-zero numeric values from the output\n",
		progname);
}

int main(int argc, char **argv)
{
	int ch;

	hooked = 0;
	fdelim = ' ';
	optflags = 0;
	skipframes = framecount = 0;

	while ((ch = getopt(argc, argv, "hns:z")) != -1) {
		switch (ch) {
		case 'h':
			usage(argv[0]);
			return 0;
		case 'n':
			optflags |= OPT_CRFIELD;
			break;
		case 's':
			skipframes = (unsigned int)strtol(optarg, NULL, 10);
			break;
		case 'z':
			optflags |= OPT_MASKZEROES;
			break;
		default:
			usage(argv[0]);
			exit(-1);
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
