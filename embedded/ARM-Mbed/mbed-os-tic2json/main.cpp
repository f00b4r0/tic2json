//
//  main.cpp
//  app stub for ARM Mbed OS
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Receives TIC on RX, outputs JSON on TX.
 */

#include "mbed.h"

#define TIC_TX	CONSOLE_TX
#define TIC_RX	CONSOLE_RX
#define TICBAUDRATE 9600	// 1200 for V01, 9600 for V02s

//https://forums.mbed.com/t/hitchhikers-guide-to-printf-in-mbed-6/12492
namespace mbed
{
	FileHandle *mbed_override_console(int fd)
	{
	    static BufferedSerial console(TIC_TX, TIC_RX, TICBAUDRATE);
		console.set_format(7, BufferedSerial::Even, 1);
		return &console;
	}
}

extern "C" {
	void tic2json_main(void);
}


// main() runs in its own thread in the OS
int main()
{
	while (true)
		tic2json_main();

	return 0;
}
