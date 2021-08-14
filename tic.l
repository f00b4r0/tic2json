/*
//  tic.l
//
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
*/

/* noyywrap disables automatic rewinding for the next file to parse. Since we
 always parse only a single string, there's no need to do any wraps. And
 using yywrap requires linking with -lfl, which provides the default yywrap
 implementation that always returns 1 anyway. */
%option noyywrap

/* nounput simplifies the lexer, by removing support for putting a character
 back into the input stream. We never use such capability anyway. */
%option nounput

/* batch means that we'll never use the generated lexer interactively. */
%option batch

/* Enables debug mode. To see the debug messages, one needs to also set
 yy_flex_debug to 1, then the debug messages will be printed on stderr. */
%option nodebug

HORODATE	[ EeHh][0-9]{12}
DATAC		[\x20-\x7e]
CHKSUM		[\x20-\x5f]
/* séparateur de champ. \x20 en mode historique: DATAC ne contient alors pas 0x20 */
SEP		\x09

%{
	#include "tic.h"
	#include "tic.tab.h"

	static uint8_t checksum;

	static void crc_calc(void)
	{
		for (size_t i = 0; i<yyleng; i++)
			checksum += (uint8_t)yytext[i];
	}
%}

%%

	/* balises */
\x02		{ return TOK_STX; }
\x03		{ return TOK_ETX; }
\x0a		{ checksum=0; return FIELD_START; }
{SEP}		{ checksum += (uint8_t)*yytext; return TOK_SEP; }
{CHKSUM}\x0d	{
			checksum = (checksum & 0x3f) + 0x20;
			if (checksum == (uint8_t)yytext[0]) return FIELD_OK;
			else return FIELD_KO;
		}


	/* etiquettes - mode historique mono - non supporté */
	/*
ADCO
OPTARIF
ISOUSC
BASE
HCHC
HCHP
EJPHN
EJPHPM
BBRHCJB
BBRHPJB
BBRHCJW
BBRHPJW
BBRHCJR
BBRHPJR
PEJP
PTEC
DEMAIN
IINST
ADPS
IMAX
PAPP
HHPHC
MOTDETAT
	 */

	/* etiquettes - mode standard */
ADSC		{ crc_calc(); yylval.text = strdup(yytext); return ET_ADSC; }
VTIC		{ crc_calc(); yylval.text = strdup(yytext); return ET_VTIC; }
DATE		{ crc_calc(); yylval.text = strdup(yytext); return ET_DATE; }
NGTF		{ crc_calc(); yylval.text = strdup(yytext); return ET_NGTF; }
LTARF		{ crc_calc(); yylval.text = strdup(yytext); return ET_LTARF; }
EAST		{ crc_calc(); yylval.text = strdup(yytext); return ET_EAST; }
EASF01		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF01; }
EASF02		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF02; }
EASF03		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF03; }
EASF04		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF04; }
EASF05		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF05; }
EASF06		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF06; }
EASF07		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF07; }
EASF08		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF08; }
EASF09		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF09; }
EASF10		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASF10; }
EASD01		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASD01; }
EASD02		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASD02; }
EASD03		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASD03; }
EASD04		{ crc_calc(); yylval.text = strdup(yytext); return ET_EASD04; }
EAIT		{ crc_calc(); yylval.text = strdup(yytext); return ET_EAIT; }
ERQ1		{ crc_calc(); yylval.text = strdup(yytext); return ET_ERQ1; }
ERQ2		{ crc_calc(); yylval.text = strdup(yytext); return ET_ERQ2; }
ERQ3		{ crc_calc(); yylval.text = strdup(yytext); return ET_ERQ3; }
ERQ4		{ crc_calc(); yylval.text = strdup(yytext); return ET_ERQ4; }
IRMS1		{ crc_calc(); yylval.text = strdup(yytext); return ET_IRMS1; }
IRMS2		{ crc_calc(); yylval.text = strdup(yytext); return ET_IRMS2; }
IRMS3		{ crc_calc(); yylval.text = strdup(yytext); return ET_IRMS3; }
URMS1		{ crc_calc(); yylval.text = strdup(yytext); return ET_URMS1; }
URMS2		{ crc_calc(); yylval.text = strdup(yytext); return ET_URMS2; }
URMS3		{ crc_calc(); yylval.text = strdup(yytext); return ET_URMS3; }
PREF		{ crc_calc(); yylval.text = strdup(yytext); return ET_PREF; }
PCOUP		{ crc_calc(); yylval.text = strdup(yytext); return ET_PCOUP; }
SINSTS		{ crc_calc(); yylval.text = strdup(yytext); return ET_SINSTS; }
SINSTS1		{ crc_calc(); yylval.text = strdup(yytext); return ET_SINSTS1; }
SINSTS2		{ crc_calc(); yylval.text = strdup(yytext); return ET_SINSTS2; }
SINSTS3		{ crc_calc(); yylval.text = strdup(yytext); return ET_SINSTS3; }
SMAXSN		{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN; }
SMAXSN1		{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN1; }
SMAXSN2		{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN2; }
SMAXSN3		{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN3; }
SMAXSN-1	{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSNM1; }
SMAXSN1-1	{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN1M1; }
SMAXSN2-1	{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN2M1; }
SMAXSN3-1	{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXSN3M1; }
SINSTI		{ crc_calc(); yylval.text = strdup(yytext); return ET_SINSTI; }
SMAXIN		{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXIN; }
SMAXIN-1	{ crc_calc(); yylval.text = strdup(yytext); return ET_SMAXINM1; }
CCASN		{ crc_calc(); yylval.text = strdup(yytext); return ET_CCASN; }
CCASN-1		{ crc_calc(); yylval.text = strdup(yytext); return ET_CCASNM1; }
CCAIN		{ crc_calc(); yylval.text = strdup(yytext); return ET_CCAIN; }
CCAIN-1		{ crc_calc(); yylval.text = strdup(yytext); return ET_CCAINM1; }
UMOY1		{ crc_calc(); yylval.text = strdup(yytext); return ET_UMOY1; }
UMOY2		{ crc_calc(); yylval.text = strdup(yytext); return ET_UMOY2; }
UMOY3		{ crc_calc(); yylval.text = strdup(yytext); return ET_UMOY3; }
STGE		{ crc_calc(); yylval.text = strdup(yytext); return ET_STGE; }
DPM1		{ crc_calc(); yylval.text = strdup(yytext); return ET_DPM1; }
FPM1		{ crc_calc(); yylval.text = strdup(yytext); return ET_FPM1; }
DPM2		{ crc_calc(); yylval.text = strdup(yytext); return ET_DPM2; }
FPM2		{ crc_calc(); yylval.text = strdup(yytext); return ET_FPM2; }
DPM3		{ crc_calc(); yylval.text = strdup(yytext); return ET_DPM3; }
FPM3		{ crc_calc(); yylval.text = strdup(yytext); return ET_FPM3; }
MSG1		{ crc_calc(); yylval.text = strdup(yytext); return ET_MSG1; }
MSG2		{ crc_calc(); yylval.text = strdup(yytext); return ET_MSG2; }
PRM		{ crc_calc(); yylval.text = strdup(yytext); return ET_PRM; }
RELAIS		{ crc_calc(); yylval.text = strdup(yytext); return ET_RELAIS; }
NTARF		{ crc_calc(); yylval.text = strdup(yytext); return ET_NTARF; }
NJOURF		{ crc_calc(); yylval.text = strdup(yytext); return ET_NJOURF; }
NJOURF\+1	{ crc_calc(); yylval.text = strdup(yytext); return ET_NJOURFP1; }
PJOURF\+1	{ crc_calc(); yylval.text = strdup(yytext); return ET_PJOURFP1; }
PPOINTE		{ crc_calc(); yylval.text = strdup(yytext); return ET_PPOINTE; }

{HORODATE}	{ crc_calc(); yylval.text = strdup(yytext); return TOK_HDATE; }
{DATAC}+	{ crc_calc(); yylval.text = strdup(yytext); return TOK_DATA; }

.		{ fprintf(stderr, "spurious character 0x%02hhx\n", *yytext); /* ignore */ }

<<EOF>>		{ yyterminate(); }
%%
