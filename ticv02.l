/*
//  ticv02.l
//  A lexer for ENEDIS TIC version 02 protocol
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
*/

/*
 * Complete lexer for ENEDIS' TIC protocol.
 * Supports version 02, a.k.a "standard" as found on ENEDIS' LINKY smart meter.
 * Ref doc: https://www.enedis.fr/media/2035/download
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

HORODATE	[ EeHh][0-9]{12}
DATAC		[\x20-\x7e]
CHKSUM		[\x20-\x5f]
SEP		\x09

%{
	#include "tic2json.h"
	#include "ticv02.tab.h"

	extern int filter_mode;
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
<INITIAL>\x0a		{ checksum=0; return FIELD_START; }
<INITIAL>{SEP}		{ checksum += (uint8_t)*yytext; return TOK_SEP; }
<INITIAL>{CHKSUM}\x0d	{
			checksum = (checksum & 0x3f) + 0x20;
			if (checksum == (uint8_t)yytext[0]) return FIELD_OK;
			else return FIELD_KO;
		}


	/* etiquettes - mode standard */
ADSC		{ crc_calc(); ticv02yylval.label = "ADSC"; return ET_ADSC; }
VTIC		{ crc_calc(); ticv02yylval.label = "VTIC"; return ET_VTIC; }
DATE		{ crc_calc(); ticv02yylval.label = "DATE"; return ET_DATE; }
NGTF		{ crc_calc(); ticv02yylval.label = "NGTF"; return ET_NGTF; }
LTARF		{ crc_calc(); ticv02yylval.label = "LTARF"; return ET_LTARF; }
EAST		{ crc_calc(); ticv02yylval.label = "EAST"; return ET_EAST; }
EASF01		{ crc_calc(); ticv02yylval.label = "EASF01"; return ET_EASF01; }
EASF02		{ crc_calc(); ticv02yylval.label = "EASF02"; return ET_EASF02; }
EASF03		{ crc_calc(); ticv02yylval.label = "EASF03"; return ET_EASF03; }
EASF04		{ crc_calc(); ticv02yylval.label = "EASF04"; return ET_EASF04; }
EASF05		{ crc_calc(); ticv02yylval.label = "EASF05"; return ET_EASF05; }
EASF06		{ crc_calc(); ticv02yylval.label = "EASF06"; return ET_EASF06; }
EASF07		{ crc_calc(); ticv02yylval.label = "EASF07"; return ET_EASF07; }
EASF08		{ crc_calc(); ticv02yylval.label = "EASF08"; return ET_EASF08; }
EASF09		{ crc_calc(); ticv02yylval.label = "EASF09"; return ET_EASF09; }
EASF10		{ crc_calc(); ticv02yylval.label = "EASF10"; return ET_EASF10; }
EASD01		{ crc_calc(); ticv02yylval.label = "EASD01"; return ET_EASD01; }
EASD02		{ crc_calc(); ticv02yylval.label = "EASD02"; return ET_EASD02; }
EASD03		{ crc_calc(); ticv02yylval.label = "EASD03"; return ET_EASD03; }
EASD04		{ crc_calc(); ticv02yylval.label = "EASD04"; return ET_EASD04; }
EAIT		{ crc_calc(); ticv02yylval.label = "EAIT"; return ET_EAIT; }
ERQ1		{ crc_calc(); ticv02yylval.label = "ERQ1"; return ET_ERQ1; }
ERQ2		{ crc_calc(); ticv02yylval.label = "ERQ2"; return ET_ERQ2; }
ERQ3		{ crc_calc(); ticv02yylval.label = "ERQ3"; return ET_ERQ3; }
ERQ4		{ crc_calc(); ticv02yylval.label = "ERQ4"; return ET_ERQ4; }
IRMS1		{ crc_calc(); ticv02yylval.label = "IRMS1"; return ET_IRMS1; }
IRMS2		{ crc_calc(); ticv02yylval.label = "IRMS2"; return ET_IRMS2; }
IRMS3		{ crc_calc(); ticv02yylval.label = "IRMS3"; return ET_IRMS3; }
URMS1		{ crc_calc(); ticv02yylval.label = "URMS1"; return ET_URMS1; }
URMS2		{ crc_calc(); ticv02yylval.label = "URMS2"; return ET_URMS2; }
URMS3		{ crc_calc(); ticv02yylval.label = "URMS3"; return ET_URMS3; }
PREF		{ crc_calc(); ticv02yylval.label = "PREF"; return ET_PREF; }
PCOUP		{ crc_calc(); ticv02yylval.label = "PCOUP"; return ET_PCOUP; }
SINSTS		{ crc_calc(); ticv02yylval.label = "SINSTS"; return ET_SINSTS; }
SINSTS1		{ crc_calc(); ticv02yylval.label = "SINSTS1"; return ET_SINSTS1; }
SINSTS2		{ crc_calc(); ticv02yylval.label = "SINSTS2"; return ET_SINSTS2; }
SINSTS3		{ crc_calc(); ticv02yylval.label = "SINSTS3"; return ET_SINSTS3; }
SMAXSN		{ crc_calc(); ticv02yylval.label = "SMAXSN"; return ET_SMAXSN; }
SMAXSN1		{ crc_calc(); ticv02yylval.label = "SMAXSN1"; return ET_SMAXSN1; }
SMAXSN2		{ crc_calc(); ticv02yylval.label = "SMAXSN2"; return ET_SMAXSN2; }
SMAXSN3		{ crc_calc(); ticv02yylval.label = "SMAXSN3"; return ET_SMAXSN3; }
SMAXSN-1	{ crc_calc(); ticv02yylval.label = "SMAXSN-1"; return ET_SMAXSNM1; }
SMAXSN1-1	{ crc_calc(); ticv02yylval.label = "SMAXSN1-1"; return ET_SMAXSN1M1; }
SMAXSN2-1	{ crc_calc(); ticv02yylval.label = "SMAXSN2-1"; return ET_SMAXSN2M1; }
SMAXSN3-1	{ crc_calc(); ticv02yylval.label = "SMAXSN3-1"; return ET_SMAXSN3M1; }
SINSTI		{ crc_calc(); ticv02yylval.label = "SINSTI"; return ET_SINSTI; }
SMAXIN		{ crc_calc(); ticv02yylval.label = "SMAXIN"; return ET_SMAXIN; }
SMAXIN-1	{ crc_calc(); ticv02yylval.label = "SMAXIN-1"; return ET_SMAXINM1; }
CCASN		{ crc_calc(); ticv02yylval.label = "CCASN"; return ET_CCASN; }
CCASN-1		{ crc_calc(); ticv02yylval.label = "CCASN-1"; return ET_CCASNM1; }
CCAIN		{ crc_calc(); ticv02yylval.label = "CCAIN"; return ET_CCAIN; }
CCAIN-1		{ crc_calc(); ticv02yylval.label = "CCAIN-1"; return ET_CCAINM1; }
UMOY1		{ crc_calc(); ticv02yylval.label = "UMOY1"; return ET_UMOY1; }
UMOY2		{ crc_calc(); ticv02yylval.label = "UMOY2"; return ET_UMOY2; }
UMOY3		{ crc_calc(); ticv02yylval.label = "UMOY3"; return ET_UMOY3; }
STGE		{ crc_calc(); ticv02yylval.label = "STGE"; return ET_STGE; }
DPM1		{ crc_calc(); ticv02yylval.label = "DPM1"; return ET_DPM1; }
FPM1		{ crc_calc(); ticv02yylval.label = "FPM1"; return ET_FPM1; }
DPM2		{ crc_calc(); ticv02yylval.label = "DPM2"; return ET_DPM2; }
FPM2		{ crc_calc(); ticv02yylval.label = "FPM2"; return ET_FPM2; }
DPM3		{ crc_calc(); ticv02yylval.label = "DPM3"; return ET_DPM3; }
FPM3		{ crc_calc(); ticv02yylval.label = "FPM3"; return ET_FPM3; }
MSG1		{ crc_calc(); ticv02yylval.label = "MSG1"; return ET_MSG1; }
MSG2		{ crc_calc(); ticv02yylval.label = "MSG2"; return ET_MSG2; }
PRM		{ crc_calc(); ticv02yylval.label = "PRM"; return ET_PRM; }
RELAIS		{ crc_calc(); ticv02yylval.label = "RELAIS"; return ET_RELAIS; }
NTARF		{ crc_calc(); ticv02yylval.label = "NTARF"; return ET_NTARF; }
NJOURF		{ crc_calc(); ticv02yylval.label = "NJOURF"; return ET_NJOURF; }
NJOURF\+1	{ crc_calc(); ticv02yylval.label = "NJOURF+1"; return ET_NJOURFP1; }
PJOURF\+1	{ crc_calc(); ticv02yylval.label = "PJOURF+1"; return ET_PJOURFP1; }
PPOINTE		{ crc_calc(); ticv02yylval.label = "PPOINTE"; return ET_PPOINTE; }

<INITIAL>{HORODATE}	{ crc_calc(); ticv02yylval.text = strdup(yytext); return TOK_HDATE; }
<INITIAL>{DATAC}+	{ crc_calc(); ticv02yylval.text = strdup(yytext); return TOK_DATA; }

.		{ pr_err("spurious character 0x%02hhx\n", *yytext); return *yytext; }

<<EOF>>		{ yyterminate(); }
%%
