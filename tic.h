//
//  tic.h
//  Interface for TIC parsers
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

#ifndef tic_h
#define tic_h

#include <stdio.h>
#include <inttypes.h>
#include <stdbool.h>

#ifdef BAREBUILD
 #define pr_err(format, ...)    /* nothing */
#else
 #define pr_err(format, ...)    fprintf(stderr, "ERREUR: " format, ## __VA_ARGS__)
#endif

// The code assumes this fits on 4 bits
enum tic_unit {
	U_SANS = 0x00,
	U_WH,
	U_VARH,
	U_A,
	U_V,
	U_KVA,
	U_VA,
	U_W,
	U_MIN,
};

// this is to be packed in the upper 4 bits of a byte: must increment by 0x10
// by default everything is an int
enum data_type {
	T_STRING = 0x10,
	T_HEX = 0x20,
};

struct tic_etiquette {
	uint8_t tok;
	uint8_t unittype;
	const char *label;
	const char *desc;
};

struct tic_field {
	struct tic_etiquette etiq;
	union {
		char *s;
		int i;
	} data;
	char *horodate;
};

void make_field(struct tic_field *field, const struct tic_etiquette *etiq, char *horodate, char *data);
void free_field(struct tic_field *field);

void print_field(struct tic_field *field);
// The following functions must be provided by the output interface
void frame_sep(void);
void frame_err(void);

#endif /* tic_h */
