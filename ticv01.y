//
//  ticv01.y
//  A parser for ENEDIS TIC version 01 protocol
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * This parser implements a complete grammar that supports TIC version 01
 * as specified in Enedis-NOI-CPT_02E.pdf version 6.
 *
 * This parser does not allocate memory, except if a filter configuration is used in
 * which case the etiq_en array will be allocated (it's a few hundred bytes).
 * A left-recursion grammar has been implemented to keep the memory usage to the bare
 * minimum as well. As a tradeoff, valid datasets are always emitted regardless of the
 * overall status of the containing frame.
 */

%{
#include <stdlib.h>
#include "tic2json.h"

int ticv01yylex();
int ticv01yylex_destroy();
extern FILE *ticv01yyin;
static void yyerror(const char *);

extern int filter_mode;
extern uint8_t *etiq_en;

%}

%union {
	char *text;
	const char *label;
	struct tic_etiquette etiq;
	struct tic_field field;
}

%verbose

%token TOK_STX TOK_ETX TOK_EOT TOK_SEP
%token FIELD_START FIELD_OK FIELD_KO
%token TICFILTER

%token <text> TOK_DATA

%token <label> ET_ADCO ET_OPTARIF ET_ISOUSC ET_BASE ET_HCHC ET_HCHP ET_EJPHN ET_EJPHPM
%token <label> ET_BBRHCJB ET_BBRHPJB ET_BBRHCJW ET_BBRHPJW ET_BBRHCJR ET_BBRHPJR
%token <label> ET_PEJP ET_PTEC ET_DEMAIN ET_IINST ET_IINST1 ET_IINST2 ET_IINST3 ET_ADPS ET_IMAX ET_IMAX1 ET_IMAX2 ET_IMAX3
%token <label> ET_PMAX ET_PAPP ET_HHPHC ET_MOTDETAT ET_PPOT ET_ADIR1 ET_ADIR2 ET_ADIR3

%type <etiq> etiquette
%type <field> field

%destructor { free($$); } <text>
%destructor { free_field(&$$); } <field>
%destructor { } <> <*>

%%

start:	filter | frames

/* filter config only */
filter:
	TICFILTER etiquettes
;

etiquettes:
	etiquette		{ etiq_en[$1.tok]=1; }
	| etiquettes etiquette	{ etiq_en[$2.tok]=1; }
	| error			{ YYABORT; }
;

/* stream processing */
frames:
	frame
	| frames frame
;

frame:
	TOK_STX datasets TOK_ETX	{ frame_sep(); }
	| TOK_STX datasets TOK_EOT	{ /*mark error but don't print*/ frame_err(); frame_sep(); }
	| error TOK_ETX			{ frame_err(); frame_sep(); pr_err("frame error\n"); yyerrok; }
;

datasets:
	error				{ frame_err(); pr_err("dataset error\n"); }
	| dataset
	| datasets dataset
;

dataset:
	FIELD_START field FIELD_OK	{ print_field(&$2); free_field(&$2); }
	| FIELD_START field FIELD_KO	{ frame_err(); pr_err("dataset invalid checksum\n"); free_field(&$2); }
	| FIELD_START error FIELD_OK	{ /*not a frame error*/ pr_err("unrecognized dataset\n"); yyerrok; }
;

field:
	etiquette TOK_SEP TOK_DATA TOK_SEP		{ make_field(&$$, &$1, NULL, $3); }
;

etiquette:
	ET_ADCO		{ $$.tok=yytranslate[ET_ADCO]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Adresse du compteur"; }
	| ET_OPTARIF	{ $$.tok=yytranslate[ET_OPTARIF]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Option tarifaire choisie"; }
	| ET_ISOUSC	{ $$.tok=yytranslate[ET_ISOUSC]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité souscrite"; }
	| ET_BASE	{ $$.tok=yytranslate[ET_BASE]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Base"; }
	| ET_HCHC	{ $$.tok=yytranslate[ET_HCHC]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Heures Creuses: Heures Creuses"; }
	| ET_HCHP	{ $$.tok=yytranslate[ET_HCHP]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Heures Creuses: Heures Pleines"; }
	| ET_EJPHN	{ $$.tok=yytranslate[ET_EJPHN]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option EJP: Heures Normales"; }
	| ET_EJPHPM	{ $$.tok=yytranslate[ET_EJPHPM]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option EJP: Heures de Pointe Mobile"; }
	| ET_BBRHCJB	{ $$.tok=yytranslate[ET_BBRHCJB]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Tempo: Heures Creuses Jours Bleus"; }
	| ET_BBRHPJB	{ $$.tok=yytranslate[ET_BBRHPJB]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Tempo: Heures Pleines Jours Bleus"; }
	| ET_BBRHCJW	{ $$.tok=yytranslate[ET_BBRHCJW]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Tempo: Heures Creuses Jours Blancs"; }
	| ET_BBRHPJW	{ $$.tok=yytranslate[ET_BBRHPJW]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Tempo: Heures Pleines Jours Blancs"; }
	| ET_BBRHCJR	{ $$.tok=yytranslate[ET_BBRHCJR]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Tempo: Heures Creuses Jours Rouges"; }
	| ET_BBRHPJR	{ $$.tok=yytranslate[ET_BBRHPJR]; $$.unittype=U_WH; $$.label=$1; $$.desc="Index option Tempo: Heures Pleines Jours Rouges"; }
	| ET_PEJP	{ $$.tok=yytranslate[ET_PEJP]; $$.unittype=U_MIN; $$.label=$1; $$.desc="Préavis Début EJP (30 min)"; }
	| ET_PTEC	{ $$.tok=yytranslate[ET_PTEC]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Période Tarifaire en cours"; }
	| ET_DEMAIN	{ $$.tok=yytranslate[ET_DEMAIN]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Couleur du lendemain"; }
	| ET_IINST	{ $$.tok=yytranslate[ET_IINST]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité Instantanée"; }
	| ET_IINST1	{ $$.tok=yytranslate[ET_IINST1]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité Instantanée phase 1"; }
	| ET_IINST2	{ $$.tok=yytranslate[ET_IINST2]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité Instantanée phase 2"; }
	| ET_IINST3	{ $$.tok=yytranslate[ET_IINST3]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité Instantanée phase 3"; }
	| ET_ADPS	{ $$.tok=yytranslate[ET_ADPS]; $$.unittype=U_A; $$.label=$1; $$.desc="Avertissement de Dépassement De Puissance Souscrite"; }
	| ET_IMAX	{ $$.tok=yytranslate[ET_IMAX]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité maximale"; }
	| ET_IMAX1	{ $$.tok=yytranslate[ET_IMAX1]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité maximale phase 1"; }
	| ET_IMAX2	{ $$.tok=yytranslate[ET_IMAX2]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité maximale phase 2"; }
	| ET_IMAX3	{ $$.tok=yytranslate[ET_IMAX3]; $$.unittype=U_A; $$.label=$1; $$.desc="Intensité maximale phase 3"; }
	| ET_PMAX	{ $$.tok=yytranslate[ET_PMAX]; $$.unittype=U_W; $$.label=$1; $$.desc="Puissance maximale atteinte"; }
	| ET_PAPP	{ $$.tok=yytranslate[ET_PAPP]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance apparente soutirée"; }
	| ET_HHPHC	{ $$.tok=yytranslate[ET_HHPHC]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Horaire Heures Pleines Heures Creuses"; }
	| ET_MOTDETAT	{ $$.tok=yytranslate[ET_MOTDETAT]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Mot d'état du compteur"; }
	| ET_PPOT	{ $$.tok=yytranslate[ET_PPOT]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Présence des potentiels"; }
	| ET_ADIR1	{ $$.tok=yytranslate[ET_ADIR1]; $$.unittype=U_A; $$.label=$1; $$.desc="Avertissemetn de Dépassement d'intensité de réglage phase 1"; }
	| ET_ADIR2	{ $$.tok=yytranslate[ET_ADIR2]; $$.unittype=U_A; $$.label=$1; $$.desc="Avertissemetn de Dépassement d'intensité de réglage phase 2"; }
	| ET_ADIR3	{ $$.tok=yytranslate[ET_ADIR3]; $$.unittype=U_A; $$.label=$1; $$.desc="Avertissemetn de Dépassement d'intensité de réglage phase 3"; }
;

%%

#ifndef BAREBUILD
void parse_config_v01(const char *filename)
{
	if (!(ticv01yyin = fopen(filename, "r"))) {
		perror(filename);
		exit(-1);
	}

	etiq_en = calloc(YYNTOKENS, sizeof(*etiq_en));
	if (!etiq_en)
		abort();	// OOM

	filter_mode = 1;
	if (ticv01yyparse()) {
		pr_err("%s: filter config error!\n", filename);
		exit(-1);
	}

	fclose(ticv01yyin);
	ticv01yylex_destroy();
	ticv01yyin = stdin;
	filter_mode = 0;
}
#endif /* !BAREBUILD */

static void yyerror(const char * s)
{
}
