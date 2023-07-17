//
//  tic.c
//  Common routines for TIC parsers
//
//  (C) 2021-2022 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Common routines used by the TIC parsers.
 * The code making use of the parsers must provide extra functions as mentioned in the header.
 */

#include <stdlib.h>
#include <string.h>

#include "tic.h"

bool filter_mode;	///< if true, switch lexers to configuration parsing
bool *etiq_en;		///< when non-NULL, a token-indexed array, where the related token is emitted if the value is true. @note This could be made a bit field if memory is a concern

void make_field(struct tic_field *field, const struct tic_etiquette *etiq, char *horodate, char *data)
{
	// args come from the bison stack
	int base;
	char *rem;

	field->horodate = horodate;
	memcpy(&field->etiq, etiq, sizeof(field->etiq));

	switch ((etiq->unittype & 0xF0)) {
		case T_IGN:
			return;
		case T_STRING:
		case T_PROFILE:
			field->data.s = data;
			return;
		case T_HEX:
			base = 16;
			break;
		default:
			base = 10;
			break;
	}
	field->data.i = (int)strtol(data, &rem, base);

#ifdef TICV01pme
	if (U_SANS == etiq->unittype && *data != '\0' && *rem != '\0') {
		// int sans unit but with a suffix: either kVA or kW - try to disambiguate
		switch (rem[strlen(rem)-1]) {
			case 'A':
				field->etiq.unittype = U_KVA;
				break;
			case 'W':
				field->etiq.unittype = U_KW;
				break;
			default:
				break;
		}
	}
#endif

	free(data);
}

void free_field(struct tic_field *field)
{
	free(field->horodate);
	switch ((field->etiq.unittype & 0xF0)) {
		case T_STRING:
		case T_PROFILE:
			free(field->data.s);
			break;
		default:
			break;
	}
}
