//
//  ticv02.y
//  A parser for ENEDIS TIC version 02 protocol
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * This parser implements a complete grammar that supports TIC version 02
 * as specified in Enedis-NOI-CPT_54E.pdf version 3.
 *
 * This parser does not allocate memory, except if a filter configuration is used in
 * which case the etiq_en array will be allocated (it's a few hundred bytes).
 * A left-recursion grammar has been implemented to keep the memory usage to the bare
 * minimum as well. As a tradeoff, valid datasets are always emitted regardless of the
 * overall status of the containing frame.
 */

%{
#include <stdlib.h>
#include "tic.h"

int ticv02yylex();
int ticv02yylex_destroy();
extern FILE *ticv02yyin;
static void yyerror(const char *);

extern bool filter_mode;
extern uint8_t *etiq_en;

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
%token TICFILTER

%token <text> TOK_HDATE TOK_DATA

%token <label> ET_ADSC ET_VTIC ET_DATE ET_NGTF ET_LTARF
%token <label> ET_EAST ET_EASF01 ET_EASF02 ET_EASF03 ET_EASF04 ET_EASF05 ET_EASF06 ET_EASF07 ET_EASF08 ET_EASF09 ET_EASF10
%token <label> ET_EASD01 ET_EASD02 ET_EASD03 ET_EASD04 ET_EAIT ET_ERQ1 ET_ERQ2 ET_ERQ3 ET_ERQ4
%token <label> ET_IRMS1 ET_IRMS2 ET_IRMS3 ET_URMS1 ET_URMS2 ET_URMS3 ET_PREF ET_PCOUP
%token <label> ET_SINSTS ET_SINSTS1 ET_SINSTS2 ET_SINSTS3 ET_SMAXSN ET_SMAXSN1 ET_SMAXSN2 ET_SMAXSN3
%token <label> ET_SMAXSNM1 ET_SMAXSN1M1 ET_SMAXSN2M1 ET_SMAXSN3M1 ET_SINSTI ET_SMAXIN ET_SMAXINM1
%token <label> ET_CCASN ET_CCASNM1 ET_CCAIN ET_CCAINM1 ET_UMOY1 ET_UMOY2 ET_UMOY3 ET_STGE ET_DPM1 ET_FPM1 ET_DPM2 ET_FPM2 ET_DPM3 ET_FPM3
%token <label> ET_MSG1 ET_MSG2 ET_PRM ET_RELAIS ET_NTARF ET_NJOURF ET_NJOURFP1 ET_PJOURFP1 ET_PPOINTE

%type <etiq> etiquette etiquette_horodate etiquette_nodate
%type <field> field field_horodate field_nodate

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

etiquette:
	etiquette_horodate
	| etiquette_nodate
;

/* stream processing */
frames:
	frame
	| frames frame
;

frame:
	TOK_STX datasets TOK_ETX	{ frame_sep(); }
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

field: 	field_horodate
	| field_nodate
;

field_horodate:
	etiquette_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_SEP		{ make_field(&$$, &$1, $3, NULL); }
	| etiquette_horodate TOK_SEP TOK_HDATE TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, &$1, $3, $5); }
;

field_nodate:
	etiquette_nodate TOK_SEP TOK_DATA TOK_SEP	{ make_field(&$$, &$1, NULL, $3); }
;

etiquette_horodate:
	ET_DATE		{ $$.tok=yytranslate[ET_DATE]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Date et heure courante"; }
	| ET_SMAXSN	{ $$.tok=yytranslate[ET_SMAXSN]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n"; }
	| ET_SMAXSN1	{ $$.tok=yytranslate[ET_SMAXSN1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n phase 1"; }
	| ET_SMAXSN2	{ $$.tok=yytranslate[ET_SMAXSN2]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n phase 2"; }
	| ET_SMAXSN3	{ $$.tok=yytranslate[ET_SMAXSN3]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n phase 3"; }
	| ET_SMAXSNM1	{ $$.tok=yytranslate[ET_SMAXSNM1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1"; }
	| ET_SMAXSN1M1	{ $$.tok=yytranslate[ET_SMAXSN1M1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1 phase 1"; }
	| ET_SMAXSN2M1	{ $$.tok=yytranslate[ET_SMAXSN2M1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1 phase 2"; }
	| ET_SMAXSN3M1	{ $$.tok=yytranslate[ET_SMAXSN3M1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max soutirée n-1 phase 3"; }
	| ET_SMAXIN	{ $$.tok=yytranslate[ET_SMAXIN]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max injectée n"; }
	| ET_SMAXINM1	{ $$.tok=yytranslate[ET_SMAXINM1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. max injectée n-1"; }
	| ET_CCASN	{ $$.tok=yytranslate[ET_CCASN]; $$.unittype=U_W; $$.label=$1; $$.desc="Point n de la courbe de charge active soutirée"; }
	| ET_CCASNM1	{ $$.tok=yytranslate[ET_CCASNM1]; $$.unittype=U_W; $$.label=$1; $$.desc="Point n-1 de la courbe de charge active soutirée"; }
	| ET_CCAIN	{ $$.tok=yytranslate[ET_CCAIN]; $$.unittype=U_W; $$.label=$1; $$.desc="Point n de la courbe de charge active injectée"; }
	| ET_CCAINM1	{ $$.tok=yytranslate[ET_CCAINM1]; $$.unittype=U_W; $$.label=$1; $$.desc="Point n-1 de la courbe de charge active injectée"; }
	| ET_UMOY1	{ $$.tok=yytranslate[ET_UMOY1]; $$.unittype=U_V; $$.label=$1; $$.desc="Tension moy. ph. 1"; }
	| ET_UMOY2	{ $$.tok=yytranslate[ET_UMOY2]; $$.unittype=U_V; $$.label=$1; $$.desc="Tension moy. ph. 2"; }
	| ET_UMOY3	{ $$.tok=yytranslate[ET_UMOY3]; $$.unittype=U_V; $$.label=$1; $$.desc="Tension moy. ph. 3"; }
	| ET_DPM1	{ $$.tok=yytranslate[ET_DPM1]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Début Pointe Mobile 1"; }
	| ET_FPM1	{ $$.tok=yytranslate[ET_FPM1]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Fin Pointe Mobile 1"; }
	| ET_DPM2	{ $$.tok=yytranslate[ET_DPM2]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Début Pointe Mobile 2"; }
	| ET_FPM2	{ $$.tok=yytranslate[ET_FPM2]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Fin Pointe Mobile 2"; }
	| ET_DPM3	{ $$.tok=yytranslate[ET_DPM3]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Début Pointe Mobile 3"; }
	| ET_FPM3	{ $$.tok=yytranslate[ET_FPM3]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Fin Pointe Mobile 3"; }
;

etiquette_nodate:
	ET_ADSC		{ $$.tok=yytranslate[ET_ADSC]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Adresse Secondaire du Compteur"; }
	| ET_VTIC	{ $$.tok=yytranslate[ET_VTIC]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Version de la TIC"; }
	| ET_NGTF	{ $$.tok=yytranslate[ET_NGTF]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Nom du calendrier tarifaire fournisseur"; }
	| ET_LTARF	{ $$.tok=yytranslate[ET_LTARF]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Libellé tarif fournisseur en cours"; }
	| ET_EAST	{ $$.tok=yytranslate[ET_EAST]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée totale"; }
	| ET_EASF01	{ $$.tok=yytranslate[ET_EASF01]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 01"; }
	| ET_EASF02	{ $$.tok=yytranslate[ET_EASF02]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 02"; }
	| ET_EASF03	{ $$.tok=yytranslate[ET_EASF03]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 03"; }
	| ET_EASF04	{ $$.tok=yytranslate[ET_EASF04]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 04"; }
	| ET_EASF05	{ $$.tok=yytranslate[ET_EASF05]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 05"; }
	| ET_EASF06	{ $$.tok=yytranslate[ET_EASF06]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 06"; }
	| ET_EASF07	{ $$.tok=yytranslate[ET_EASF07]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 07"; }
	| ET_EASF08	{ $$.tok=yytranslate[ET_EASF08]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 08"; }
	| ET_EASF09	{ $$.tok=yytranslate[ET_EASF09]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 09"; }
	| ET_EASF10	{ $$.tok=yytranslate[ET_EASF10]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Fournisseur, index 10"; }
	| ET_EASD01	{ $$.tok=yytranslate[ET_EASD01]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 01"; }
	| ET_EASD02	{ $$.tok=yytranslate[ET_EASD02]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 02"; }
	| ET_EASD03	{ $$.tok=yytranslate[ET_EASD03]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 03"; }
	| ET_EASD04	{ $$.tok=yytranslate[ET_EASD04]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée Distributeur, index 04"; }
	| ET_EAIT	{ $$.tok=yytranslate[ET_EAIT]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active injectée totale"; }
	| ET_ERQ1	{ $$.tok=yytranslate[ET_ERQ1]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive Q1 totale"; }
	| ET_ERQ2	{ $$.tok=yytranslate[ET_ERQ2]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive Q2 totale"; }
	| ET_ERQ3	{ $$.tok=yytranslate[ET_ERQ3]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive Q3 totale"; }
	| ET_ERQ4	{ $$.tok=yytranslate[ET_ERQ4]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive Q4 totale"; }
	| ET_IRMS1	{ $$.tok=yytranslate[ET_IRMS1]; $$.unittype=U_A; $$.label=$1; $$.desc="Courant efficace, phase 1"; }
	| ET_IRMS2	{ $$.tok=yytranslate[ET_IRMS2]; $$.unittype=U_A; $$.label=$1; $$.desc="Courant efficace, phase 2"; }
	| ET_IRMS3	{ $$.tok=yytranslate[ET_IRMS3]; $$.unittype=U_A; $$.label=$1; $$.desc="Courant efficace, phase 3"; }
	| ET_URMS1	{ $$.tok=yytranslate[ET_URMS1]; $$.unittype=U_V; $$.label=$1; $$.desc="Tension efficace, phase 1"; }
	| ET_URMS2	{ $$.tok=yytranslate[ET_URMS2]; $$.unittype=U_V; $$.label=$1; $$.desc="Tension efficace, phase 2"; }
	| ET_URMS3	{ $$.tok=yytranslate[ET_URMS3]; $$.unittype=U_V; $$.label=$1; $$.desc="Tension efficace, phase 3"; }
	| ET_PREF	{ $$.tok=yytranslate[ET_PREF]; $$.unittype=U_KVA; $$.label=$1; $$.desc="Puissance app. de référence (PREF)"; }
	| ET_PCOUP	{ $$.tok=yytranslate[ET_PCOUP]; $$.unittype=U_KVA; $$.label=$1; $$.desc="Puissance app. de coupure (PCOUP)"; }
	| ET_SINSTS	{ $$.tok=yytranslate[ET_SINSTS]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée"; }
	| ET_SINSTS1	{ $$.tok=yytranslate[ET_SINSTS1]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée phase 1"; }
	| ET_SINSTS2	{ $$.tok=yytranslate[ET_SINSTS2]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée phase 2"; }
	| ET_SINSTS3	{ $$.tok=yytranslate[ET_SINSTS3]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée soutirée phase 3"; }
	| ET_SINSTI	{ $$.tok=yytranslate[ET_SINSTI]; $$.unittype=U_VA; $$.label=$1; $$.desc="Puissance app. Instantannée injectée"; }
	| ET_STGE	{ $$.tok=yytranslate[ET_STGE]; $$.unittype=U_SANS|T_HEX; $$.label=$1; $$.desc="Registre de Statuts"; }
	| ET_MSG1	{ $$.tok=yytranslate[ET_MSG1]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Message court"; }
	| ET_MSG2	{ $$.tok=yytranslate[ET_MSG2]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Message Ultra court"; }
	| ET_PRM	{ $$.tok=yytranslate[ET_PRM]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="PRM"; }
	| ET_RELAIS	{ $$.tok=yytranslate[ET_RELAIS]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Relais"; }
	| ET_NTARF	{ $$.tok=yytranslate[ET_NTARF]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Numéro de l'index tarifaire en cours"; }
	| ET_NJOURF	{ $$.tok=yytranslate[ET_NJOURF]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Numéro du jour en cours calendrier fournisseur"; }
	| ET_NJOURFP1	{ $$.tok=yytranslate[ET_NJOURFP1]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Numéro du prochain jour calendrier fournisseur"; }
	| ET_PJOURFP1	{ $$.tok=yytranslate[ET_PJOURFP1]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Profil du prochain jour calendrier fournisseur"; }
	| ET_PPOINTE	{ $$.tok=yytranslate[ET_PPOINTE]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Profil du prochain jour de pointe"; }
;


%%

#ifndef BAREBUILD
void parse_config_v02(const char *filename)
{
	if (!(ticv02yyin = fopen(filename, "r"))) {
		perror(filename);
		exit(-1);
	}

	etiq_en = calloc(YYNTOKENS, sizeof(*etiq_en));
	if (!etiq_en)
		abort();	// OOM

	filter_mode = true;
	if (ticv02yyparse()) {
		pr_err("%s: filter config error!\n", filename);
		exit(-1);
	}

	fclose(ticv02yyin);
	ticv02yylex_destroy();
	ticv02yyin = stdin;
	filter_mode = false;
}
#endif /* !BAREBUILD */

static void yyerror(const char * s)
{
}
