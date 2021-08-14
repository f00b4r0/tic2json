//
//  tic.h
//  
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

#ifndef tic_h
#define tic_h

enum f_type { F_STRING, F_INT, F_HEX };

struct tic_field {
	enum f_type type;
	char *label;
	char *horodate;
	union {
		char *s;
		int i;
	} data;
};

#endif /* tic_h */
