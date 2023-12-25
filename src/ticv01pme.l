/*
//  ticv01pme.l
//  A lexer for ENEDIS TIC version 01 protocol - PME-PMI variant
//
//  (C) 2022 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//
//  Development of this file was sponsored by Wiztivi - www.wiztivi.com
*/

/**
 * @file
 * Complete lexer for ENEDIS' TIC protocol version 01 - PME-PMI variant.
 * Supports version 01, a.k.a "historique" as found on ENEDIS' PME-PMI meters.
 * Ref doc: https://www.enedis.fr/media/2027/download
 *
 * "le champ « étiquette » ne contient aucun caractère ayant une valeur égale à celle
 * du caractère-séparateur utilisé pour la trame (caractère ASCII « espace » ou caractère
 * ASCII « tabulation horizontale » suivant le cas). Par contre, le champ « donnée »
 * contenant l’information fournie par le groupe peut, lui, contenir des caractères ayant
 * une valeur égale à celle du caractère-séparateur utilisé pour la trame."
 *
 * Certaines étiquettes ne sont actuellement pas supportées par ce code: elles sont ignorées,
 * mais la somme de contrôle est quand même calculée (pour établir l'intégrité de la trame transmise).
 * Il s'agit des étiquettes relatives à la tarification dynamique et aux mesures de tangente phi.
 * Me contacter pour implémentation:
 *  - ETATDYN1 PREAVIS1 TDYN1CD TDYN1CF TDYN1FD TDYN1FF
 *  - ETATDYN2 PREAVIS2 TDYN2CD TDYN2CF TDYN2FD TDYN2FF
 *  - TGPHI_s TGPHI_i
 */

/* noyywrap disables automatic rewinding for the next file to parse. Since we
 always parse only a single string, there's no need to do any wraps. And
 using yywrap requires linking with -lfl, which provides the default yywrap
 implementation that always returns 1 anyway. */
%option noyywrap

/* nounput simplifies the lexer, by removing support for putting a character
 back into the input stream. We never use such capability anyway. */
%option nounput

/* we never directly read input */
%option noinput

/* we don't need the default rule */
%option nodefault

/* nounistd suppresses inclusion of the non-ANSI header file unistd.h.
 This option is meant to target environments in which unistd.h does not exist.
 Be aware that certain options may cause flex to generate code that relies on
 functions normally found in unistd.h, (e.g. isatty(), read().)
 If you wish to use these functions, you will have to inform your compiler where
 to find them. See option-always-interactive. See option-read. */
%option nounistd

/* batch means that we'll never use the generated lexer interactively. */
%option batch

/* we only process 7-bit input */
%option 7bit

/* Enables debug mode. To see the debug messages, one needs to also set
 yy_flex_debug to 1, then the debug messages will be printed on stderr. */
%option nodebug

%s FILTER
%x DATA

DATAC		[\x20-\x7e]
CHKSUM		[\x20-\x5f]
SEP		\x20
HORODATE	[0-9]{2}"/"[0-9]{2}"/"[0-9]{2}" "[0-9]{2}":"[0-9]{2}":"[0-9]{2}
CTRLTRAIL	{SEP}{CHKSUM}\x0d

%{
	#include "tic.h"
	#include "ticv01pme.tab.h"

	extern bool filter_mode;
	static uint8_t checksum;

	static void crc_calc(void)
	{
		for (size_t i = 0; i<yyleng; i++)
			checksum += (uint8_t)yytext[i];
	}

	/* Note: because the parser doesn't build a tree and immediately processes each frame,
	 * we can hack through global variables to simplify the processing of common labels */
	static char datepax[] = "DATEPAX";
	static char pax[] = "PAX_x";
%}

%%

	if (filter_mode)
		BEGIN(FILTER);

	/* only for filter */
<FILTER>"#"ticfilter\n	{ return TICFILTER; }
<FILTER>[ \t\n]+	/* ignore whitespace */

	/* balises */
<*>\x02		{ BEGIN(INITIAL); return TOK_STX; }
<*>\x03		{ BEGIN(INITIAL); return TOK_ETX; }
<*>\x04		{ BEGIN(INITIAL); return TOK_EOT; }
<*>\x0a		{ BEGIN(INITIAL); checksum=0; return FIELD_START; }
<*>{CTRLTRAIL}	{
			checksum = (checksum & 0x3f) + 0x20;
			if (checksum == (uint8_t)yytext[1]) return FIELD_OK;
			else return FIELD_KO;
		}
{SEP}		{ checksum += (uint8_t)*yytext; BEGIN(DATA); return TOK_SEP; }


	/* etiquettes - mode historique */
TRAME		{ crc_calc(); ticv01pmeyylval.label = "TRAME"; return ET_TRAME; }
ADS		{ crc_calc(); ticv01pmeyylval.label = "ADS"; return ET_ADS; }
MESURES1	{ crc_calc(); ticv01pmeyylval.label = "MESURES1"; return ET_MESURES; }
DATE		{ crc_calc(); ticv01pmeyylval.label = "DATE"; return ET_DATE; }
EA_s		{ crc_calc(); ticv01pmeyylval.label = "EA_s"; return ET_EA_s; }
ER\+_s		{ crc_calc(); ticv01pmeyylval.label = "ER+_s"; return ET_ERP_s; }
ER-_s		{ crc_calc(); ticv01pmeyylval.label = "ER-_s"; return ET_ERM_s; }
EAPP_s		{ crc_calc(); ticv01pmeyylval.label = "EAPP_s"; return ET_EAPP_s; }
EA_i		{ crc_calc(); ticv01pmeyylval.label = "EA_i"; return ET_EA_i; }
ER\+_i		{ crc_calc(); ticv01pmeyylval.label = "ER+_i"; return ET_ERP_i; }
ER-_i		{ crc_calc(); ticv01pmeyylval.label = "ER-_i"; return ET_ERM_i; }
EAPP_i		{ crc_calc(); ticv01pmeyylval.label = "EAPP_i"; return ET_EAPP_i; }

PTCOUR1		{ crc_calc(); ticv01pmeyylval.label = "PTCOUR1"; return ET_PTCOUR; }
TARIFDYN	{ crc_calc(); ticv01pmeyylval.label = "TARIFDYN"; return ET_TARIFDYN; }
ETATDYN1	|
PREAVIS1	|
TDYN1CD		|
TDYN1CF		|
TDYN1FD		|
TDYN1FF		{ crc_calc(); return ET_IGNORED; }

MODE		{ crc_calc(); ticv01pmeyylval.label = "MODE"; return ET_MODE; }
CONFIG		{ crc_calc(); ticv01pmeyylval.label = "CONFIG"; return ET_CONFIG; }
DATEPA[1-6]	{
			if (filter_mode)
				pr_warn("Note: including all DATEPAX\n");
			crc_calc();
			datepax[6] = yytext[6];
			ticv01pmeyylval.label = datepax;
			return ET_DATEPAX;
		}
PA[1-6]_[is]	{
			if (filter_mode)
				pr_warn("Note: including all PAX_%c\n", yytext[4]);
			crc_calc();
			pax[2] = yytext[2];
			pax[4] = yytext[4];
			ticv01pmeyylval.label = pax;
			if ('i' == pax[4])
				return ET_PAX_i;
			else
				return ET_PAX_s;
		}
DebP		{ crc_calc(); ticv01pmeyylval.label = "DebP"; return ET_DEBP; }
EAP_s		{ crc_calc(); ticv01pmeyylval.label = "EAP_s"; return ET_EAP_s; }
EAP_i		{ crc_calc(); ticv01pmeyylval.label = "EAP_i"; return ET_EAP_i; }
ER\+P_s		{ crc_calc(); ticv01pmeyylval.label = "ER+P_s"; return ET_ERPP_s; }
ER-P_s		{ crc_calc(); ticv01pmeyylval.label = "ER-P_s"; return ET_ERMP_s; }
ER\+P_i		{ crc_calc(); ticv01pmeyylval.label = "ER+P_i"; return ET_ERPP_i; }
ER-P_i		{ crc_calc(); ticv01pmeyylval.label = "ER-P_i"; return ET_ERMP_i; }
DebP-1		{ crc_calc(); ticv01pmeyylval.label = "DebP-1"; return ET_DEBPM1; }
FinP-1		{ crc_calc(); ticv01pmeyylval.label = "FinP-1"; return ET_FINPM1; }
EaP-1_s		{ crc_calc(); ticv01pmeyylval.label = "EaP-1_s"; return ET_EAPM1_s; }
EaP-1_i		{ crc_calc(); ticv01pmeyylval.label = "EaP-1_i"; return ET_EAPM1_i; }
ER\+P-1_s	{ crc_calc(); ticv01pmeyylval.label = "ER+P-1_s"; return ET_ERPPM1_s; }
ER-P-1_s	{ crc_calc(); ticv01pmeyylval.label = "ER-P-1_s"; return ET_ERMPM1_s; }
ER\+P-1_i	{ crc_calc(); ticv01pmeyylval.label = "ER+P-1_i"; return ET_ERPPM1_i; }
ER-P-1_i	{ crc_calc(); ticv01pmeyylval.label = "ER-P-1_i"; return ET_ERMPM1_i; }
PS		{ crc_calc(); ticv01pmeyylval.label = "PS"; return ET_PS; }
PREAVIS		{ crc_calc(); ticv01pmeyylval.label = "PREAVIS"; return ET_PREAVIS; }
PA1MN		{ crc_calc(); ticv01pmeyylval.label = "PA1MN"; return ET_PA1MN; }
PMAX_s		{ crc_calc(); ticv01pmeyylval.label = "PMAX_s"; return ET_PMAX_s; }
PMAX_i		{ crc_calc(); ticv01pmeyylval.label = "PMAX_i"; return ET_PMAX_i; }
TGPHI_s		{ crc_calc(); ticv01pmeyylval.label = "TGPHI_s"; return ET_TGPHI_s; }
TGPHI_i		{ crc_calc(); return ET_IGNORED; }

MESURES2	{ crc_calc(); ticv01pmeyylval.label = "MESURES2"; return ET_MESURES; }
PTCOUR2		{ crc_calc(); ticv01pmeyylval.label = "PTCOUR2"; return ET_PTCOUR; }
ETATDYN2	|
PREAVIS2	|
TDYN2CD		|
TDYN2CF		|
TDYN2FD		|
TDYN2FF		{ crc_calc(); return ET_IGNORED; }

DebP_2		{ crc_calc(); ticv01pmeyylval.label = "DebP_2"; return ET_DEBP; }
EaP_s2		{ crc_calc(); ticv01pmeyylval.label = "EaP_s2"; return ET_EAP_s; }
DebP-1_2	{ crc_calc(); ticv01pmeyylval.label = "DebP-1_2"; return ET_DEBPM1; }
FinP-1_2	{ crc_calc(); ticv01pmeyylval.label = "FinP-1_2"; return ET_FINPM1; }
EaP-1_s2	{ crc_calc(); ticv01pmeyylval.label = "EaP-1_s2"; return ET_EAPM1_s; }

<DATA>{HORODATE}/.*		{ crc_calc(); ticv01pmeyylval.text = strdup(yytext); return TOK_HDATE; }
<DATA>{DATAC}+/{CTRLTRAIL}	{ crc_calc(); ticv01pmeyylval.text = strdup(yytext); return TOK_DATA; }

<*>.		{ if (yy_flex_debug) pr_err("spurious character 0x%02hhx\n", *yytext); return *yytext; }

<<EOF>>		{ yyterminate(); }
%%
