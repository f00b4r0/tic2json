//
//  tic.h
//  
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

#ifndef tic_h
#define tic_h

#include <inttypes.h>

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

#endif /* tic_h */
