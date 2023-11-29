//
//  tic.h
//  Interface for TIC parsers
//
//  (C) 2021-2022 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Interface for TIC parsers
 * Users of this interface must implement the functions declared at the bottom:
 *  - print_field()
 *  - frame_sep()
 *  - frame_err()
 */

#ifndef tic_h
#define tic_h

#include <stdio.h>
#include <inttypes.h>
#include <stdbool.h>

#ifdef BAREBUILD
 #define pr_err(format, ...)    /* nothing */
 #define pr_warn(format, ...)	/* noting */
#else
 #define pr_err(format, ...)    fprintf(stderr, "ERREUR: " format, ## __VA_ARGS__)
 #define pr_warn(format, ...)    fprintf(stderr, format, ## __VA_ARGS__)
#endif

/**
 * TIC units.
 * @warning The code assumes this fits on 4 bits (16 values)
 */
enum tic_unit {
	U_SANS = 0x00,
	U_VAH,
	U_KWH,
	U_WH,
	U_KVARH,
	U_VARH,
	U_A,
	U_V,
	U_KVA,
	U_VA,
	U_KW,
	U_W,
	U_MIN,
	U_DAL,
};

/**
 * TIC data types.
 * By default everything is an int.
 * @warning The code assumes this is packed in the upper 4 bits of a byte: must increment by 0x10.
 * @note bit 4 (value of T_STRING) is set for string types
 */
 enum data_type {
	T_STRING = 0x10,
	T_HEX = 0x20,
	T_PROFILE = 0x30,
	T_IGN = 0x40,
};

/** Internal parser representation of a TIC etiquette */
struct tic_etiquette {
	uint8_t tok;		///< bison token number
	uint8_t unittype;	///< combined unit and type (see @tic_unit @data_type)
	const char *label;	///< TIC "etiquette", as an ASCII string
	const char *desc;	///< corresponding TIC long description
};

/** Internal parser representation of a TIC field (i.e. body of a dataset) */
struct tic_field {
	struct tic_etiquette etiq;	///< the field "etiquette"
	union {
		char *s;
		long i;
	} data;				///< the field data, if any
	char *horodate;			///< the field horodate, if any
};

void make_field(struct tic_field *field, const struct tic_etiquette *etiq, char *horodate, char *data);
void free_field(struct tic_field *field);

// The following functions must be provided by the output interface

/**
 * Called for each valid dataset.
 * Used to print a TIC dataset in the desired output format.
 * @param field the dataset to print
 */
void print_field(const struct tic_field *field);

/**
 * Called after each frame, valid or not.
 * Used to print a frame separator in the desired output format.
 */
void frame_sep(void);

/**
 * Called whenever a frame error condition occurs.
 * When frames or datasets have errors.
 */
void frame_err(void);

#endif /* tic_h */
