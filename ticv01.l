/*
//  ticv01.l
//  A lexer for ENEDIS TIC version 01 protocol
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
*/

/**
 * @file
 * Complete lexer for ENEDIS' TIC protocol.
 * Supports version 01, a.k.a "historique" as found on ENEDIS' LINKY smart meter.
 * Ref doc: https://www.enedis.fr/media/2027/download
 *
 * "le champ « étiquette » ne contient aucun caractère ayant une valeur égale à celle
 * du caractère-séparateur utilisé pour la trame (caractère ASCII « espace » ou caractère
 * ASCII « tabulation horizontale » suivant le cas). Par contre, le champ « donnée »
 * contenant l’information fournie par le groupe peut, lui, contenir des caractères ayant
 * une valeur égale à celle du caractère-séparateur utilisé pour la trame."
 *
 * Mais NOI-CPT_54E indique toutefois:
 * "Note : le caractère séparateur des champs "Horizontal Tab" HT (0x09), en mode standard
 * est different du caractère séparateur "Space" SP (0x20) en mode historique.
 * Cette disposition permet d’utiliser le caractère “Space” pour les données."
 *
 * On serait donc fondé à penser qu'en mode historique, ni les étiquettes ni les données
 * ne contiennent 0x20. Du moins en sortie Linky "historique". Cette hypothèse est donc
 * retenue jusqu'à preuve du contraire.
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

/* batch means that we'll never use the generated lexer interactively. */
%option batch

/* we only process 7-bit input */
%option 7bit

/* Enables debug mode. To see the debug messages, one needs to also set
 yy_flex_debug to 1, then the debug messages will be printed on stderr. */
%option nodebug

%s FILTER

DATAC		[\x21-\x7e]
CHKSUM		[\x20-\x5f]
SEP		\x20

%{
	#include "tic.h"
	#include "ticv01.tab.h"

	extern bool filter_mode;
	static uint8_t checksum;

	static void crc_calc(void)
	{
		for (size_t i = 0; i<yyleng; i++)
			checksum += (uint8_t)yytext[i];
	}
%}

%%

	if (filter_mode)
		BEGIN(FILTER);

	/* only for filter */
<FILTER>"#"ticfilter\n	{ return TICFILTER; }
<FILTER>[ \t\n]+                /* ignore whitespace */

	/* balises */
<INITIAL>\x02		{ return TOK_STX; }
<INITIAL>\x03		{ return TOK_ETX; }
<INITIAL>\x04		{ return TOK_EOT; }
<INITIAL>\x0a		{ checksum=0; return FIELD_START; }
<INITIAL>{SEP}		{ checksum += (uint8_t)*yytext; return TOK_SEP; }
<INITIAL>{CHKSUM}\x0d	{
			checksum -= 0x20;	// we have one space too many in the checksum: last SEP
			checksum = (checksum & 0x3f) + 0x20;
			if (checksum == (uint8_t)yytext[0]) return FIELD_OK;
			else return FIELD_KO;
		}


	/* etiquettes - mode historique */
ADCO		{ crc_calc(); ticv01yylval.label = "ADCO"; return ET_ADCO; }
OPTARIF		{ crc_calc(); ticv01yylval.label = "OPTARIF"; return ET_OPTARIF; }
ISOUSC		{ crc_calc(); ticv01yylval.label = "ISOUSC"; return ET_ISOUSC; }
BASE		{ crc_calc(); ticv01yylval.label = "BASE"; return ET_BASE; }
HCHC		{ crc_calc(); ticv01yylval.label = "HCHC"; return ET_HCHC; }
HCHP		{ crc_calc(); ticv01yylval.label = "HCHP"; return ET_HCHP; }
EJPHN		{ crc_calc(); ticv01yylval.label = "EJPHN"; return ET_EJPHN; }
EJPHPM		{ crc_calc(); ticv01yylval.label = "EJPHPM"; return ET_EJPHPM; }
BBRHCJB		{ crc_calc(); ticv01yylval.label = "BBRHCJB"; return ET_BBRHCJB; }
BBRHPJB		{ crc_calc(); ticv01yylval.label = "BBRHPJB"; return ET_BBRHPJB; }
BBRHCJW		{ crc_calc(); ticv01yylval.label = "BBRHCJW"; return ET_BBRHCJW; }
BBRHPJW		{ crc_calc(); ticv01yylval.label = "BBRHPJW"; return ET_BBRHPJW; }
BBRHCJR		{ crc_calc(); ticv01yylval.label = "BBRHCJR"; return ET_BBRHCJR; }
BBRHPJR		{ crc_calc(); ticv01yylval.label = "BBRHPJR"; return ET_BBRHPJR; }
PEJP		{ crc_calc(); ticv01yylval.label = "PEJP"; return ET_PEJP; }
PTEC		{ crc_calc(); ticv01yylval.label = "PTEC"; return ET_PTEC; }
DEMAIN		{ crc_calc(); ticv01yylval.label = "DEMAIN"; return ET_DEMAIN; }
IINST		{ crc_calc(); ticv01yylval.label = "IINST"; return ET_IINST; }
IINST1		{ crc_calc(); ticv01yylval.label = "IINST1"; return ET_IINST1; }
IINST2		{ crc_calc(); ticv01yylval.label = "IINST2"; return ET_IINST2; }
IINST3		{ crc_calc(); ticv01yylval.label = "IINST3"; return ET_IINST3; }
ADPS		{ crc_calc(); ticv01yylval.label = "ADPS"; return ET_ADPS; }
IMAX		{ crc_calc(); ticv01yylval.label = "IMAX"; return ET_IMAX; }
IMAX1		{ crc_calc(); ticv01yylval.label = "IMAX1"; return ET_IMAX1; }
IMAX2		{ crc_calc(); ticv01yylval.label = "IMAX2"; return ET_IMAX2; }
IMAX3		{ crc_calc(); ticv01yylval.label = "IMAX3"; return ET_IMAX3; }
PMAX		{ crc_calc(); ticv01yylval.label = "PMAX"; return ET_PMAX; }
PAPP		{ crc_calc(); ticv01yylval.label = "PAPP"; return ET_PAPP; }
HHPHC		{ crc_calc(); ticv01yylval.label = "HHPHC"; return ET_HHPHC; }
MOTDETAT	{ crc_calc(); ticv01yylval.label = "MOTDETAT"; return ET_MOTDETAT; }
PPOT		{ crc_calc(); ticv01yylval.label = "PPOT"; return ET_PPOT; }
ADIR1		{ crc_calc(); ticv01yylval.label = "ADIR1"; return ET_ADIR1; }
ADIR2		{ crc_calc(); ticv01yylval.label = "ADIR2"; return ET_ADIR2; }
ADIR3		{ crc_calc(); ticv01yylval.label = "ADIR3"; return ET_ADIR3; }
GAZ		{ crc_calc(); ticv01yylval.label = "GAZ"; return ET_GAZ; }
AUTRE		{ crc_calc(); ticv01yylval.label = "AUTRE"; return ET_AUTRE; }


<INITIAL>{DATAC}+	{ crc_calc(); ticv01yylval.text = strdup(yytext); return TOK_DATA; }

.		{ pr_err("spurious character 0x%02hhx\n", *yytext); return *yytext; }

<<EOF>>		{ yyterminate(); }
%%
