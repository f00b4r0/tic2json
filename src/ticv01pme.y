//
//  ticv01pme.y
//  A parser for ENEDIS TIC version 01 protocol
//
//  (C) 2022 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//
//  Development of this file was sponsored by Wiztivi - www.wiztivi.com

/**
 * @file
 * This parser implements a complete grammar that supports TIC version 01 - PME-PMI variant
 * as specified in Enedis-NOI-CPT_02E.pdf version 6.
 *
 * This parser does not allocate memory, except if a filter configuration is used in
 * which case the etiq_en array will be allocated (it's a few hundred bytes).
 * A left-recursion grammar has been implemented to keep the memory usage to the bare
 * minimum as well. As a tradeoff, valid datasets are always emitted regardless of the
 * overall status of the containing frame.
 *
 * Compteurs supportés:
 *  - PME-PMI (tous paliers)
 *
 * Certains champs ne sont actuellement pas supportés par ce code: ils ne sont pas émis.
 * Il s'agit des champs relatifs à la tarification dynamique et aux mesures de tangente phi.
 * Me contacter pour implémentation:
 *  - ETATDYN1 PREAVIS1 TDYN1CD TDYN1CF TDYN1FD TDYN1FF
 *  - ETATDYN2 PREAVIS2 TDYN2CD TDYN2CF TDYN2FD TDYN2FF
 *  - TGPHI_s TGPHI_i
 */

%{
#include <stdlib.h>
#include "tic.h"

int ticv01pmeyylex();
int ticv01pmeyylex_destroy();
extern FILE *ticv01pmeyyin;
static void yyerror(const char *);

extern bool filter_mode;
extern bool *etiq_en;
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
%token ET_IGNORED

%token <text> TOK_DATA TOK_HDATE

%token <label> ET_TRAME ET_ADS ET_MESURES ET_DATE ET_MODE ET_CONFIG ET_PTCOUR ET_TARIFDYN
%token <label> ET_EA_s ET_ERP_s ET_ERM_s ET_EAPP_s ET_EA_i ET_ERP_i ET_ERM_i ET_EAPP_i
%token <label> ET_DATEPAX ET_PAX_i ET_PAX_s ET_DEBP ET_EAP_s ET_EAP_i
%token <label> ET_ERPP_s ET_ERMP_s ET_ERPP_i ET_ERMP_i ET_DEBPM1 ET_FINPM1 ET_EAPM1_s ET_EAPM1_i
%token <label> ET_ERPPM1_s ET_ERMPM1_s ET_ERPPM1_i ET_ERMPM1_i ET_PS ET_PREAVIS ET_PA1MN ET_PMAX_s ET_PMAX_i

%type <etiq> etiquette etiquette_horodate etiquette_nodate etiquette_ignored
%type <field> field field_horodate field_nodate field_ignored

%destructor { free($$); } <text>
%destructor { free_field(&$$); } <field>
%destructor { } <> <*>

%%

start:	filter | frames ;

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
	| etiquette_ignored
;

/* stream processing */
frames:
	frame
	| frames frame
;

frame:
	TOK_STX datasets TOK_ETX	{ frame_sep(); }
	| TOK_STX datasets TOK_EOT	{ /*mark error but don't print*/ frame_err(); frame_sep(); }
	| error TOK_EOT			{ frame_err(); frame_sep(); pr_err("transmission interrupted\n"); yyerrok; }
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
	| field_ignored
;

field_horodate:
	etiquette_horodate TOK_SEP TOK_HDATE			{ make_field(&$$, &$1, $3, NULL); }
;

field_nodate:
	etiquette_nodate TOK_SEP TOK_DATA			{ make_field(&$$, &$1, NULL, $3); }
;

/* special-case ignored fields: token data must be explicitely freed */
field_ignored:
	etiquette_ignored TOK_SEP TOK_DATA			{ make_field(&$$, &$1, NULL, NULL); free($3); }
	| etiquette_ignored TOK_SEP TOK_HDATE			{ make_field(&$$, &$1, NULL, NULL); free($3); }
	| etiquette_ignored TOK_SEP TOK_HDATE TOK_DATA		{ make_field(&$$, &$1, NULL, NULL); free($3); free($4); }
;

etiquette_horodate:
	ET_DATE		{ $$.tok=yytranslate[ET_DATE]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Date et heure courante"; }
	| ET_DATEPAX	{ $$.tok=yytranslate[ET_DATEPAX]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Date de la puissance active moyenne Tc min d’étiquette PAX (X = 1 à 6)"; }
	| ET_DEBP	{ $$.tok=yytranslate[ET_DEBP]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Date et heure de début de la période P"; }
	| ET_DEBPM1	{ $$.tok=yytranslate[ET_DEBPM1]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Date et heure de début de la période P-1"; }
	| ET_FINPM1	{ $$.tok=yytranslate[ET_FINPM1]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Date et heure de fin de la période P"; }
;

etiquette_nodate:
	ET_TRAME	{ $$.tok=yytranslate[ET_TRAME]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="TEST"; }
	| ET_ADS	{ $$.tok=yytranslate[ET_ADS]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Identifiant du compteur"; }
	| ET_MESURES	{ $$.tok=yytranslate[ET_MESURES]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Nom du traitement tarifaire"; }
	| ET_EA_s	{ $$.tok=yytranslate[ET_EA_s]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active soutirée (au primaire) depuis dernier top Td"; }
	| ET_ERP_s	{ $$.tok=yytranslate[ET_ERP_s]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive positive (au primaire) depuis dernier top Td en période de soutirage d'énergie active"; }
	| ET_ERM_s	{ $$.tok=yytranslate[ET_ERM_s]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive négative (au primaire) depuis dernier top Td en période de soutirage d'énergie active"; }
	| ET_EAPP_s	{ $$.tok=yytranslate[ET_EAPP_s]; $$.unittype=U_VAH; $$.label=$1; $$.desc="Energie apparente soutirée (au primaire) depuis dernier top Td"; }
	| ET_EA_i	{ $$.tok=yytranslate[ET_EA_i]; $$.unittype=U_WH; $$.label=$1; $$.desc="Energie active injectée (au primaire) depuis dernier top Td"; }
	| ET_ERP_i	{ $$.tok=yytranslate[ET_ERP_i]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive positive (au primaire) depuis dernier top Td en période d'injection d'énergie active"; }
	| ET_ERM_i	{ $$.tok=yytranslate[ET_ERM_i]; $$.unittype=U_VARH; $$.label=$1; $$.desc="Energie réactive négative (au primaire) depuis dernier top Td en période d'injection d'énergie active"; }
	| ET_EAPP_i	{ $$.tok=yytranslate[ET_EAPP_i]; $$.unittype=U_VAH; $$.label=$1; $$.desc="Energie apparente injectée (au primaire) depuis dernier top Td"; }
	| ET_PTCOUR	{ $$.tok=yytranslate[ET_PTCOUR]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Période tarifaire courante"; }
	| ET_TARIFDYN	{ $$.tok=yytranslate[ET_TARIFDYN]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Chaîne de caractères indiquant la présence du signal tarifaire externe"; }
	| ET_MODE	{ $$.tok=yytranslate[ET_MODE]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Prend la valeur « CONTROLE » si le compteur est dans ce mode"; }
	| ET_CONFIG	{ $$.tok=yytranslate[ET_CONFIG]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Prend la valeur « CONSO » ou « PROD »"; }
	| ET_PAX_s	{ $$.tok=yytranslate[ET_PAX_s]; $$.unittype=U_KW; $$.label=$1; $$.desc="Puissance active moyenne Tc min (X = 1 à 6) en soutirage"; }
	| ET_PAX_i	{ $$.tok=yytranslate[ET_PAX_i]; $$.unittype=U_KW; $$.label=$1; $$.desc="Puissance active moyenne Tc min (X = 1 à 6) en injection"; }
	| ET_EAP_s	{ $$.tok=yytranslate[ET_EAP_s]; $$.unittype=U_KWH; $$.label=$1; $$.desc="Energie active soutirée de la période P pour la période tarifaire en cours"; }
	| ET_EAP_i	{ $$.tok=yytranslate[ET_EAP_i]; $$.unittype=U_KWH; $$.label=$1; $$.desc="Energie active injectée de la période P pour la période tarifaire en cours"; }
	| ET_ERPP_s	{ $$.tok=yytranslate[ET_ERPP_s]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive positive de la période P pour la période tarifaire en cours en période de soutirage d'énergie active"; }
	| ET_ERMP_s	{ $$.tok=yytranslate[ET_ERMP_s]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive négative de la période P pour la période tarifaire en cours en période de soutirage d'énergie active"; }
	| ET_ERPP_i	{ $$.tok=yytranslate[ET_ERPP_i]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive positive de la période P pour la période tarifaire en cours en période d'injection d'énergie active"; }
	| ET_ERMP_i	{ $$.tok=yytranslate[ET_ERMP_i]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive négative de la période P pour la période tarifaire en cours en période d'injection d'énergie active"; }
	| ET_EAPM1_s	{ $$.tok=yytranslate[ET_EAPM1_s]; $$.unittype=U_KWH; $$.label=$1; $$.desc="Energie active soutirée de la période P-1 pour la période tarifaire en cours"; }
	| ET_EAPM1_i	{ $$.tok=yytranslate[ET_EAPM1_i]; $$.unittype=U_KWH; $$.label=$1; $$.desc="Energie active injectée de la période P-1 pour la période tarifaire en cours"; }
	| ET_ERPPM1_s	{ $$.tok=yytranslate[ET_ERPPM1_s]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive positive de la période P-1 pour la période tarifaire en cours en période de soutirage d'énergie active"; }
	| ET_ERMPM1_s	{ $$.tok=yytranslate[ET_ERMPM1_s]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive négative de la période P-1 pour la période tarifaire en cours en période de soutirage d'énergie active"; }
	| ET_ERPPM1_i	{ $$.tok=yytranslate[ET_ERPPM1_i]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive positive de la période P-1 pour la période tarifaire en cours en période d'injection d'énergie active"; }
	| ET_ERMPM1_i	{ $$.tok=yytranslate[ET_ERMPM1_i]; $$.unittype=U_KVARH; $$.label=$1; $$.desc="Energie réactive négative de la période P-1 pour la période tarifaire en cours en période d'injection d'énergie active"; }

	| ET_PS		{ $$.tok=yytranslate[ET_PS]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Puissance souscrite de la période tarifaire en cours"; }

	| ET_PREAVIS	{ $$.tok=yytranslate[ET_PREAVIS]; $$.unittype=U_SANS|T_STRING; $$.label=$1; $$.desc="Chaîne « DEP »"; }
	| ET_PA1MN	{ $$.tok=yytranslate[ET_PA1MN]; $$.unittype=U_KW; $$.label=$1; $$.desc="Puissance active 1 minute"; }

	| ET_PMAX_s	{ $$.tok=yytranslate[ET_PMAX_s]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Puissance maximale atteinte en période de soutirage d’énergie active pour la période tarifaire en cours"; }
	| ET_PMAX_i	{ $$.tok=yytranslate[ET_PMAX_i]; $$.unittype=U_SANS; $$.label=$1; $$.desc="Puissance maximale atteinte en période d’injection d’énergie active pour la période tarifaire en cours"; }
;

etiquette_ignored:
	ET_IGNORED	{ $$.tok=yytranslate[ET_IGNORED]; $$.unittype=T_IGN; }
;

%%

#ifndef BAREBUILD
void parse_config_v01pme(const char *filename)
{
	if (!(ticv01pmeyyin = fopen(filename, "r"))) {
		perror(filename);
		exit(-1);
	}

	etiq_en = calloc(YYNTOKENS, sizeof(*etiq_en));
	if (!etiq_en)
		abort();	// OOM

	filter_mode = true;
	if (ticv01pmeyyparse()) {
		pr_err("%s: filter config error!\n", filename);
		exit(-1);
	}

	fclose(ticv01pmeyyin);
	ticv01pmeyylex_destroy();
	ticv01pmeyyin = stdin;
	filter_mode = false;
}
#endif /* !BAREBUILD */

static void yyerror(const char * s)
{
}
