//
//  tic2json.c
//  A tool to turn ENEDIS TIC data into pure JSON
//
//  (C) 2021-2023 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Outputs as JSON a series of frames formatted as a root list of fields or a dictionary.
 * - for list mode, fields are { "label": "xxx", "data": "xxx", horodate: "xxx", "desc": "xxx", "unit": "xxx" }
 * - for dict mode, the keys are the label, followed by { "data": "xxx", "horodate": "xxx", "desc": "xxx", "unit": "xxx" }
 * with horodate optional, unit and data optional and possibly empty and data being either quoted string or number.
 *
 * Data errors can result in some/all datasets being omitted in the output frame (e.g. invalid datasets or datasets
 * that did not pass checksum are not emitted): the JSON root object can then be empty but is still emitted.
 * In dictionary mode the parser will report the frame status as "_tvalide" ("trame valide") followed by either 1
 * for a valid frame or 0 for a frame containing errors (including dataset errors).
 *
 * Output JSON is guaranteed to always be valid for each frame. By default only frames are separated with newlines.
 *
 * @note: the program can only parse a single version of the TIC within one execution context.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef BAREBUILD
 #include <unistd.h>	// getopt
 #include <err.h>
#endif

#include "tic.h"
#ifdef TICV01
 #include "ticv01.tab.h"
 int ticv01yylex_destroy();
#endif
#ifdef TICV02
 #include "ticv02.tab.h"
 int ticv02yylex_destroy();
#endif
#ifdef TICV01pme
 #include "ticv01pme.tab.h"
 int ticv01pmeyylex_destroy();
#endif

#include "tic2json.h"

#define ticprintf(format, ...)	printf(format, ## __VA_ARGS__)

#ifdef BAREBUILD
 #warning BAREBUILD currently requires defining only one version of supported TIC and does not provide main()
 #ifdef PRINT2BUF
  static char * ticbuf;
  static size_t ticbufsize, ticbufavail;
  static tic2json_framecb_t ticframecb;

  #include <stdarg.h>
  #undef ticprintf
  int ticprintf(const char * restrict format, ...)
  {
	int ret;
	va_list args;

	va_start(args, format);
	ret = vsnprintf(ticbuf + (ticbufsize - ticbufavail), ticbufavail, format, args);
	va_end(args);

	if (ret >= ticbufavail) {
		fprintf(stderr, "ERROR: output buffer too small!\n");
		return ticbufavail;
	}
	else if (ret < 0)
		return ret;

	ticbufavail -= ret;

	return (ret);
  }
 #endif	/* PRINT2BUF */
#endif	/* BAREBUILD */

#define TIC2JSON_VER	"2.5"

extern bool filter_mode;
extern bool *etiq_en;

/** Global configuration details */
static struct {
	const char *idtag;
	char framedelims[2];
	char fdelim;
	int optflags;
	unsigned int skipframes, framecount;
	enum { V01, V02, V01PME, } version;
	bool ferr;
} tp;

/** TIC units representation strings */
static const char * tic_units[] = {
	[U_SANS]	= "",
	[U_VAH]		= "VAh",
	[U_KWH]		= "kWh",
	[U_WH]		= "Wh",
	[U_KVARH]	= "kVArh",
	[U_VARH]	= "VArh",
	[U_A]		= "A",
	[U_V]		= "V",
	[U_KVA]		= "kVA",
	[U_VA]		= "VA",
	[U_KW]		= "kW",
	[U_W]		= "W",
	[U_MIN]		= "mn",
	[U_DAL]		= "daL",
};

#ifdef TICV02
static void print_stge_data(long data)
{
	const char sep = (tp.optflags & TIC2JSON_OPT_CRFIELD) ? '\n' : ' ';
	uint32_t d = (uint32_t)data;


	const char *const of[] = {
		"fermé",
		"ouvert",
	};

	const char *const coupure[] = {
		"fermé",
		"ouvert sur surpuissance",
		"ouvert sur surtension",
		"ouvert sur délestage",
		"ouvert sur ordre CPL ou Euridis",
		"ouvert sur une surchauffe avec une valeur de courant supérieure au courant de commutation maximal",
		"ouvert sur une surchauffe avec une valeur de courant inférieure au courant de commutation maximal",
		NULL,
	};

	const char *const euridis[] = {
		"désactivée",
		"activée sans sécurité",
		NULL,
		"activée avec sécurité",
	};

	const char *const cpl[] = {
		"New/Unlock",
		"New/Lock",
		"Registered",
		NULL,
	};

	const char *const tempo[] = {
		"Pas d'annonce",
		"Bleu",
		"Blanc",
		"Rouge",
	};

	const char *const pm[] = {
		"pas",
		"PM1",
		"PM2",
		"PM3",
	};

	ticprintf("{ "
		"\"Contact sec\": \"%s\",%c"
		"\"Organe de coupure\": \"%s\",%c"
		"\"État du cache-bornes distributeur\": \"%s\",%c"
		"\"Surtension sur une des phases\": \"%ssurtension\",%c"
		"\"Dépassement de la puissance de référence\": \"%s\",%c"
		"\"Fonctionnement producteur/consommateur\": \"%s\",%c"
		"\"Sens de l'énergie active\": \"énergie active %s\",%c"
		"\"Tarif en cours sur le contrat fourniture\": \"énergie ventilée sur Index %d\",%c"
		"\"Tarif en cours sur le contrat distributeur\": \"énergie ventilée sur Index %d\",%c"
		"\"Mode dégradé de l'horloge\": \"horloge %s\",%c"
		"\"État de la sortie télé-information\": \"mode %s\",%c"
		"\"État de la sortie communication Euridis\": \"%s\",%c"
		"\"Statut du CPL\": \"%s\",%c"
		"\"Synchronisation CPL\": \"compteur%s synchronisé\",%c"
		"\"Couleur du jour pour le contrat historique tempo\": \"%s\",%c"
		"\"Couleur du lendemain pour le contrat historique tempo\": \"%s\",%c"
		"\"Préavis pointes mobiles\": \"%s en cours\",%c"
		"\"Pointe mobile\": \"%s en cours\" }%c"
		,
		of[d & 0x01], sep,
		coupure[(d>>1) & 0x07], sep,
		of[(d>>4) & 0x01], sep,
		(d>>6) & 0x01 ? "" : "pas de ", sep,
		(d>>7) & 0x01 ? "dépassement en cours" : "pas de dépassement", sep,
		(d>>8) & 0x01 ? "producteur" : "consommateur", sep,
		(d>>9) & 0x01 ? "négative" : "positive", sep,
		((d>>10) & 0x0F) + 1, sep,
		((d>>14) & 0x07) + 1, sep,
		(d>>16) & 0x01 ? "en mode dégradée" : "correcte", sep,
		(d>>17) & 0x01 ? "standard" : "historique", sep,
		euridis[(d>>19) & 0x03], sep,
		cpl[(d>>21) & 0x03], sep,
		(d>>23) & 0x01 ? "" : " non", sep,
		tempo[(d>>24) & 0x03], sep,
		tempo[(d>>26) & 0x03], sep,
		pm[(d>>28) & 0x03], sep,
		pm[(d>>30) & 0x03], sep
		);
}

static void print_pjour_data(char *data)
{
	const char sep = (tp.optflags & TIC2JSON_OPT_CRFIELD) ? '\n' : ' ';
	char *d, **ap, *argv[12];
	char ldelim = ' ';

	// split the 11 blocks
	for (ap = argv; (*ap = strsep(&data, " ")) != NULL; )
		if (**ap != '\0')
			if (++ap >= &argv[11])
				break;
	*ap = NULL;

	// process and output them - blocks are in the form 'HHMMSSSS' or verbatim 'NONUTILE'
	ticprintf("[");
	for (ap = argv; *ap; ap++) {
		d = *ap;

		// first "NONUTILE" ends processing
		if ('N' == *d)
			break;

		// format action as JSON (decimal) integer for easier logging/processing
		ticprintf("%c{ \"start_time\": \"%.2s:%.2s\", \"action\": %hu }%c", ldelim, d, d+2, (uint16_t)strtol(d+4, NULL, 16), sep);
		ldelim = ',';
	}
	ticprintf("]");
}
#endif /* TICV02 */

void print_field(const struct tic_field *field)
{
	const char fdictout[] = "%c \"%.8s\": { \"data\": ";
	const char flistout[] = "%c{ \"label\": \"%.8s\", \"data\": ";
	const char *format;
	uint8_t type;

	// filters
	if (tp.framecount ||
		(T_IGN == (field->etiq.unittype & 0xF0)) ||
		((tp.optflags & TIC2JSON_OPT_MASKZEROES) && (!(field->etiq.unittype & T_STRING)) && (0 == field->data.i)) ||
		(etiq_en && !etiq_en[field->etiq.tok]))
		return;

	format = (tp.optflags & TIC2JSON_OPT_DICTOUT) ? fdictout : flistout;

	ticprintf(format, tp.fdelim, field->etiq.label);
	switch (field->etiq.unittype & 0x0F) {
		case U_SANS:
			type = field->etiq.unittype & 0xF0;
			if (T_STRING == type) {
string:
				ticprintf("\"%s\"", field->data.s ? field->data.s : "");
				break;
			}
#ifdef TICV02
			else if (T_PROFILE == type) {
				if (tp.optflags & TIC2JSON_OPT_FORMATPJ)
					print_pjour_data(field->data.s);
				else
					goto string;
				break;
			}
			else if ((T_HEX == type) && (tp.optflags & TIC2JSON_OPT_PARSESTGE)) {
				// XXX abuse the fact that STGE is the only U_SANS|T_HEX field
				print_stge_data(field->data.i);
				break;
			}
#endif /* TICV02 */
			// fallthrough
		default:
			ticprintf("%ld", field->data.i);
			break;
	}

#if defined(TICV02) || defined(TICV01pme)
	if (field->horodate) {
		if (tp.optflags & TIC2JSON_OPT_LONGDATE) {
			const char *o, *d = field->horodate;
			switch (d[0]) {
				default:
				case ' ':
					o = "";	// this is not RFC3339-compliant but still valid ISO8601. Does not happen for "DATE" which is normally the timestamp.
					break;
				case 'E':
				case 'e':
					o = "+02:00";
					break;
				case 'H':
				case 'h':
					o = "+01:00";
					break;
			}
			switch (tp.version) {
				case V02:
#ifdef TICV02
					// ticv02 horodate: SAAMMJJhhmmss
					ticprintf(", \"horodate\": \"20%.2s-%.2s-%.2sT%.2s:%.2s:%.2s%s\"", d+1, d+3, d+5, d+7, d+9, d+11, o);
					break;
#endif /* TICV02 */
				case V01PME:
#ifdef TICV01pme
					// ticv01pme horodate: JJ/MM/AA HH:MM:SS - output is valid ISO8601; cannot be RFC339 due to lack of DST info
					ticprintf(", \"horodate\": \"20%.2s-%.2s-%.2sT%.2s:%.2s:%.2s\"", d+6, d+3, d, d+9, d+12, d+15);
					break;
#endif /* TICV01pme */
				case V01:
					// no horodate in V01
				default:
					break;
			}
		}
		else
			ticprintf(", \"horodate\": \"%s\"", field->horodate);
	}
#endif /* TICV02/TICV01pme */

	if (tp.optflags & TIC2JSON_OPT_DESCFORM)
		ticprintf(", \"desc\": \"%s\", \"unit\": \"%s\"", field->etiq.desc, tic_units[(field->etiq.unittype & 0x0F)]);

	if (tp.idtag)
		ticprintf(", \"id\": \"%s\"", tp.idtag);

	ticprintf(" }%c", (tp.optflags & TIC2JSON_OPT_CRFIELD) ? '\n': ' ');

	tp.fdelim = ',';
}

void frame_sep(void)
{
	if (!tp.framecount--) {
		tp.framecount = tp.skipframes;
		if (tp.optflags & TIC2JSON_OPT_DICTOUT)
			ticprintf("%c \"_tvalide\": %d", tp.fdelim, !tp.ferr);
#ifdef PRINT2BUF
		ticprintf("%c\n", tp.framedelims[1]);
		if (ticframecb)
			ticframecb(ticbuf, ticbufsize-ticbufavail, !tp.ferr);
		ticbufavail = ticbufsize;	// reset buffer
		ticprintf("%c", tp.framedelims[0]);
#else
		ticprintf("%c\n%c", tp.framedelims[1], tp.framedelims[0]);
#endif
	}
	tp.fdelim = ' ';
	tp.ferr = 0;
}

void frame_err(void)
{
	tp.ferr = 1;
}

static inline void ticinit(void)
{
	filter_mode = false;
	etiq_en = NULL;

	memset(&tp, 0, sizeof(tp));
	tp.framedelims[0] = '['; tp.framedelims[1] = ']';
	tp.fdelim = ' ';
}

#ifndef BAREBUILD
static void usage(void)
{
	printf(	"usage: " BINNAME " {-1|-2|-P} [-dhlnpruVz] [-e fichier] [-i id] [-s N]\n"	// FIXME -1|-2 always shown
#ifdef TICV01
	        " -1\t\t"	"Analyse les trames TIC version 01 \"historique\"\n"
#endif
#ifdef TICV02
	        " -2\t\t"	"Analyse les trames TIC version 02 \"standard\"\n"
#endif
#ifdef TICV01pme
		" -P\t\t"	"Analyse les trames TIC du compteur PME-PMI\n"
#endif
		"\n"
		" -d\t\t"	"Émet les trames sous forme de dictionaire plutôt que de liste\n"
		" -e fichier\t"	"Utilise <fichier> pour configurer le filtre d'étiquettes\n"
		" -h\t\t"	"Montre ce message d'aide et quitte\n"
		" -i id\t\t"	"Ajoute une balise \"id\" avec la valeur <id> à chaque groupe\n"
		" -l\t\t"	"Ajoute les descriptions longues et les unitées de chaque groupe\n"
		" -n\t\t"	"Insère une nouvelle ligne après chaque groupe\n"
		" -p\t\t"	"Formate les trames de profils de prochain jour (TIC v02)\n"
		" -r\t\t"	"Interprète les horodates en format RFC3339 (TIC v02) ou ISO8601\n"
		" -s N\t\t"	"Émet une trame toutes les <N> reçues\n"
		" -u\t\t"	"Décode le registre de statut sous forme de dictionnaire (TIC v02)\n"
		" -V\t\t"	"Montre la version et quitte\n"
		" -z\t\t"	"Masque les groupes numériques à zéro\n"
		"\n"
		"Note: le fichier de configuration du filtre d'étiquettes doit commencer par une ligne comportant\n"
		"uniquement la séquence de caractères suivante: `#ticfilter` (sans les apostrophes), suivie à partir de\n"
		"la ligne suivante d'un nombre quelconque d'étiquettes TIC séparées par du blanc (espace, nouvelle ligne, etc).\n"
		"Seuls les groupes dont les étiquettes sont ainsi listées seront alors émis par le programme.\n"
		);
}

#ifdef TICV01
void parse_config_v01(const char *filename);
#endif

#ifdef TICV02
void parse_config_v02(const char *filename);
#endif

#ifdef TICV01pme
void parse_config_v01pme(const char *filename);
#endif

int main(int argc, char **argv)
{
	void (*parse_config)(const char *);
	int (*yyparse)(void) = NULL;
	int (*yylex_destroy)(void) = NULL;

	const char *fconfig = NULL;
	int ch;

	ticinit();

	while ((ch = getopt(argc, argv, "12Pde:hi:lnprs:uVz")) != -1) {
		switch (ch) {
#ifdef TICV01
		case '1':
			if (yyparse)
				errx(-1, "ERREUR: Une seule version de TIC peut être analysée à la fois");
			parse_config = parse_config_v01;
			yyparse = ticv01yyparse;
			yylex_destroy = ticv01yylex_destroy;
			tp.version = V01;
			break;
#endif
#ifdef TICV02
		case '2':
			if (yyparse)
				errx(-1, "ERREUR: Une seule version de TIC peut être analysée à la fois");
			parse_config = parse_config_v02;
			yyparse = ticv02yyparse;
			yylex_destroy = ticv02yylex_destroy;
			tp.version = V02;
			break;
#endif
#ifdef TICV01pme
		case 'P':
			if (yyparse)
				errx(-1, "ERREUR: Une seule version de TIC peut être analysée à la fois");
			parse_config = parse_config_v01pme;
			yyparse = ticv01pmeyyparse;
			yylex_destroy = ticv01pmeyylex_destroy;
			tp.version = V01PME;
			break;
#endif
		case 'd':
			tp.optflags |= TIC2JSON_OPT_DICTOUT;
			tp.framedelims[0] = '{'; tp.framedelims[1] = '}';
			break;
		case 'e':
			fconfig = optarg;
			break;
		case 'h':
			usage();
			return 0;
		case 'i':
			tp.idtag = optarg;
			break;
		case 'l':
			tp.optflags |= TIC2JSON_OPT_DESCFORM;
			break;
		case 'n':
			tp.optflags |= TIC2JSON_OPT_CRFIELD;
			break;
		case 'p':
			tp.optflags |= TIC2JSON_OPT_FORMATPJ;
			break;
		case 'r':
			tp.optflags |= TIC2JSON_OPT_LONGDATE;
			break;
		case 's':
			tp.skipframes = (unsigned int)strtol(optarg, NULL, 10);
			break;
		case 'u':
			tp.optflags |= TIC2JSON_OPT_PARSESTGE;
			break;
		case 'V':
			printf(	BINNAME " version " TIC2JSON_VER "\n"
				"License GPLv2: GNU GPL version 2 <https://gnu.org/licenses/gpl-2.0.html>.\n"
				"Copyright (C) 2021-2022 Thibaut Varène.\n");
			return 0;
		case 'z':
			tp.optflags |= TIC2JSON_OPT_MASKZEROES;
			break;
		default:
			usage();
			exit(-1);
		}
	}
	argc -= optind;
	argv += optind;

	if (!yyparse)
		errx(-1, "ERREUR: version TIC non spécifiée");

	if (fconfig)
		parse_config(fconfig);

	putchar(tp.framedelims[0]);
	yyparse();
	printf("%c\n", tp.framedelims[1]);
	yylex_destroy();

	free(etiq_en);
	return 0;
}

#else /* BAREBUILD */

extern FILE *ticv01yyin;
extern FILE *ticv02yyin;

#ifdef PRINT2BUF
/**
 * tic2json_main(), print to buffer variant.
 * @param yyin the FILE to read TIC frames from
 * @param optflags bitfield for tuning parser behavior
 * @param buf an allocated buffer to write JSON data to
 * @param size the size of the buffer
 * @param an optional callback to call after each printed frame, before the buffer content is overwritten.
 */
void tic2json_main(FILE * yyin, int optflags, char * buf, size_t size, tic2json_framecb_t cb)
#else
void tic2json_main(FILE * yyin, int optflags)
#endif
{
	ticinit();
	tp.optflags = optflags;

	if (tp.optflags & TIC2JSON_OPT_DICTOUT) {
		tp.framedelims[0] = '{';
		tp.framedelims[1] = '}';
	}

#ifdef PRINT2BUF
	ticbuf = buf;
	ticbufavail = ticbufsize = size;
	ticframecb = cb;
#endif

	ticprintf("%c", tp.framedelims[0]);

#if defined(TICV01)
	ticv01yyin = yyin;
	ticv01yyparse();
	ticv01yylex_destroy();
#elif defined(TICV02)
	ticv02yyin = yyin;
	ticv02yyparse();
	ticv02yylex_destroy();
#elif defined(TICV01pme)
	ticv01pmeyyin = yyin;
	ticv01pmeparse();
	ticv01pmeyylex_destroy();
#else
	fprintf(stderr, "NO TIC VERSION DEFINED!\n");	// avoid utf-8
#endif

	ticprintf("%c\n", tp.framedelims[1]);
}

#endif /* !BAREBUILD */
