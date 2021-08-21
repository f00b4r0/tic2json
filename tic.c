//
//  tic.c
//  Common routines for TIC parsers
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

#include <stdlib.h>
#include <string.h>

#include "tic.h"

bool filter_mode;
uint8_t *etiq_en;	// type: < 255 tokens. This could be made a bit field if memory is a concern

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
