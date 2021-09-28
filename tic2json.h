//
//  tic2json.h
//
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * exports for tic2json, mainly useful for embedded applications using tic2json_main().
 */

#ifndef tic2json_h
#define tic2json_h

/** enum for optflags bitfield */
enum {
	TIC2JSON_OPT_MASKZEROES	= 0x01,
	TIC2JSON_OPT_CRFIELD	= 0x02,
	TIC2JSON_OPT_DESCFORM	= 0x04,
	TIC2JSON_OPT_DICTOUT	= 0x08,
	TIC2JSON_OPT_LONGDATE	= 0x10,
	TIC2JSON_OPT_PARSESTGE	= 0x20,
};

typedef void (*tic2json_framecb_t)(char * buf, size_t size);

#endif /* tic2json_h */
