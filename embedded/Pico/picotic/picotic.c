//
//  picotic.c
//  app stub for Raspberry Pi Pico
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Receives TIC on RX, outputs JSON on TX.
 */

#include <stdio.h>

#include "pico/stdio_uart.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define UART_TX_PIN PICO_DEFAULT_UART_TX_PIN
#define UART_RX_PIN PICO_DEFAULT_UART_RX_PIN

#ifndef TICBAUDRATE
 #define TICBAUDRATE 1200
#endif

void tic2json_main(FILE * yyin);

int main()
{
	stdio_uart_init_full(UART_ID, TICBAUDRATE, UART_TX_PIN, UART_RX_PIN);

	uart_set_hw_flow(UART_ID, false, false);
	uart_set_format(UART_ID, 7, 1, UART_PARITY_EVEN);

	while (1)
		tic2json_main(stdin);

	return 0;
}
