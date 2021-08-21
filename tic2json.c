//
//  tic2json.c
//  A tool to turn ENEDIS TIC data into pure JSON
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Outputs as JSON a series of frames formatted as a list of fields or a dictionary.
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
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "tic2json.h"
#include "ticv02.tab.h"

int filter_mode;
uint8_t *etiq_en;	// type: < 255 tokens. This could be made a bit field if memory is a concern

static struct {
	const char *idtag;
	char framedelims[2];
	char fdelim;
	int optflags;
	unsigned int skipframes, framecount;
	char ferr;
} tp;

enum {
	OPT_MASKZEROES	= 0x01,
	OPT_CRFIELD	= 0x02,
	OPT_DESCFORM	= 0x04,
	OPT_DICTOUT	= 0x08,
	OPT_LONGDATE	= 0x10,
	OPT_PARSESTGE	= 0x20,
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

int ticv02yylex_destroy();

void make_field(struct tic_field *field, const struct tic_etiquette *etiq, char *horodate, char *data)
{
	// args come from the bison stack
	int base;

	field->horodate = horodate;
	memcpy(&field->etiq, etiq, sizeof(field->etiq));

	switch ((etiq->unittype & 0xF0)) {
		case T_STRING:
			field->data.s = data;
			return;
		case T_HEX:
			base = 16;
			break;
		default:
			base = 10;
			break;
	}
	field->data.i = (int)strtol(data, NULL, base);
	free(data);
}

static void print_stge_data(int data)
{
	const char sep = (tp.optflags & OPT_CRFIELD) ? '\n' : ' ';
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

	printf("{ "
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

void print_field(struct tic_field *field)
{
	const char fdictout[] = "%c \"%.8s\": { \"data\": ";
	const char flistout[] = "%c{ \"label\": \"%.8s\", \"data\": ";
	const char *format;
	uint8_t type;

	// filters
	if (tp.framecount ||
		((tp.optflags & OPT_MASKZEROES) && (T_STRING != (field->etiq.unittype & 0xF0)) && (0 == field->data.i)) ||
		(etiq_en && !etiq_en[field->etiq.tok]))
		return;

	format = (tp.optflags & OPT_DICTOUT) ? fdictout : flistout;

	printf(format, tp.fdelim, field->etiq.label);
	switch (field->etiq.unittype & 0x0F) {
		case U_SANS:
			type = field->etiq.unittype & 0xF0;
			if (T_STRING == type) {
				printf("\"%s\"", field->data.s ? field->data.s : "");
				break;
			}
			else if ((T_HEX == type) && (tp.optflags & OPT_PARSESTGE)) {
				// XXX abuse the fact that STGE is the only U_SANS|T_HEX field
				print_stge_data(field->data.i);
				break;
			}
			// fallthrough
		default:
			printf("%d", field->data.i);
			break;
	}

	if (field->horodate) {
		if (tp.optflags & OPT_LONGDATE) {
			const char *o, *d = field->horodate;
			switch (d[0]) {
			default:
			case ' ':
				o = "";
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
			printf(", \"horodate\": \"20%.2s-%.2s-%.2sT%.2s:%.2s:%.2s%s\"", d+1, d+3, d+5, d+7, d+9, d+11, o);
		}
		else
			printf(", \"horodate\": \"%s\"", field->horodate);
	}

	if (tp.optflags & OPT_DESCFORM)
		printf(", \"desc\": \"%s\", \"unit\": \"%s\"", field->etiq.desc, tic_units[(field->etiq.unittype & 0x0F)]);

	if (tp.idtag)
		printf(", \"id\": \"%s\"", tp.idtag);

	putchar('}');
	if (tp.optflags & OPT_CRFIELD)
		putchar('\n');

	tp.fdelim = ',';
}

void free_field(struct tic_field *field)
{
	free(field->horodate);
	switch ((field->etiq.unittype & 0xF0)) {
		case T_STRING:
			free(field->data.s);
			break;
		default:
			break;
	}
}

void frame_sep(void)
{
	if (!tp.framecount--) {
		tp.framecount = tp.skipframes;
		if (tp.optflags & OPT_DICTOUT)
			printf("%c \"_tvalide\": %d", tp.fdelim, !tp.ferr);
		printf ("%c\n%c", tp.framedelims[1], tp.framedelims[0]);
	}
	tp.fdelim = ' ';
	tp.ferr = 0;
}

void frame_err(void)
{
	tp.ferr = 1;
}

#ifndef BAREBUILD
static void usage(void)
{
	printf(	BINNAME " version " TIC2JSON_VER "\n"
		"usage: " BINNAME " [-dhlnruz] [-e fichier] [-i id] [-s N]\n"
		" -d\t\t"	"Émet les trames sous forme de dictionaire plutôt que de liste\n"
		" -e fichier\t"	"Utilise <fichier> pour configurer le filtre d'étiquettes\n"
		" -h\t\t"	"Montre ce message d'aide\n"
		" -i id\t\t"	"Ajoute une balise \"id\" avec la valeur <id> à chaque groupe\n"
		" -l\t\t"	"Ajoute les descriptions longues et les unitées de chaque groupe\n"
		" -n\t\t"	"Insère une nouvelle ligne après chaque groupe\n"
		" -r\t\t"	"Interprète les horodates en format RFC3339\n"
		" -s N\t\t"	"Émet une trame toutes les <N> reçues\n"
		" -u\t\t"	"Décode le registre de statut sous forme de dictionnaire\n"
		" -z\t\t"	"Masque les groupes numériques à zéro\n"
		"\n"
		"Note: le fichier de configuration du filtre d'étiquettes doit commencer par une ligne comportant\n"
		"uniquement la séquence de caractères suivante: `#ticfilter` (sans les apostrophes), suivi à partir de\n"
		"la ligne suivante d'un nombre quelconque d'étiquettes TIC séparées par du blanc (espace, nouvelle ligne, etc).\n"
		"Seuls les groupes dont les étiquettes sont ainsi listées seront alors émis par le programme.\n"
		);
}

void parse_config(const char *filename);
#endif /* !BAREBUILD */

int main(int argc, char **argv)
{
	int ch;

	filter_mode = 0;
	etiq_en = NULL;
	memset(&tp, 0, sizeof(tp));

	tp.framedelims[0] = '['; tp.framedelims[1] = ']';
	tp.fdelim = ' ';

#ifndef BAREBUILD
	while ((ch = getopt(argc, argv, "de:hi:lnrs:uz")) != -1) {
		switch (ch) {
		case 'd':
			tp.optflags |= OPT_DICTOUT;
			tp.framedelims[0] = '{'; tp.framedelims[1] = '}';
			break;
		case 'e':
			parse_config(optarg);
			break;
		case 'h':
			usage();
			return 0;
		case 'i':
			tp.idtag = optarg;
			break;
		case 'l':
			tp.optflags |= OPT_DESCFORM;
			break;
		case 'n':
			tp.optflags |= OPT_CRFIELD;
			break;
		case 'r':
			tp.optflags |= OPT_LONGDATE;
			break;
		case 's':
			tp.skipframes = (unsigned int)strtol(optarg, NULL, 10);
			break;
		case 'u':
			tp.optflags |= OPT_PARSESTGE;
			break;
		case 'z':
			tp.optflags |= OPT_MASKZEROES;
			break;
		default:
			usage();
			exit(-1);
		}
	}
	argc -= optind;
	argv += optind;
#endif /* !BAREBUILD */

	putchar(tp.framedelims[0]);
	ticv02yyparse();
	printf("%c\n", tp.framedelims[1]);
	ticv02yylex_destroy();

	free(etiq_en);
	return 0;
}
