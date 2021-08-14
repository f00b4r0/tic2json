//
//  tic.h
//  
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

#ifndef tic_h
#define tic_h

enum tic_unit {
	U_SANS,
	U_WH,
	U_VARH,
	U_A,
	U_V,
	U_KVA,
	U_VA,
	U_W,
};

struct tic_etiquette {
	enum tic_unit unit;
	const char *label;
	const char *desc;
};

enum f_type { F_STRING, F_INT, F_HEX };

struct tic_field {
	enum f_type type;
	const char *label;
	char *horodate;
	union {
		char *s;
		int i;
	} data;
};

#endif /* tic_h */
