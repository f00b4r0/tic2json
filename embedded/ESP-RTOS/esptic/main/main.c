//
//  main.c
//  app stub for ESP8266/ESP32
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * Receives TIC on RX, outputs JSON on TX.
 * @note: Memory usage detailed below has been tested on ESP8266 in "Release" (-Os) build:
 *  - TICV01: max stack 5400, max heap: 3764+80
 *  - TICV02: max stack 5816, max heap: 3764+80
 */

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_vfs_dev.h"
#include "driver/uart.h"

void tic2json_main(void);

void app_main(void)
{
	uart_config_t uart_config = {
		.baud_rate = CONFIG_ESPTIC_BAUDRATE,
		.data_bits = UART_DATA_7_BITS,
		.parity    = UART_PARITY_EVEN,
		.stop_bits = UART_STOP_BITS_1,
	};
	ESP_ERROR_CHECK(uart_param_config(CONFIG_ESPTIC_UART_NUM, &uart_config));

	/* Install UART driver for interrupt-driven reads and writes */
	ESP_ERROR_CHECK(uart_driver_install(CONFIG_ESPTIC_UART_NUM,
		UART_FIFO_LEN*2, 0, 0, NULL, 0));

	/* Tell VFS to use UART driver */
	esp_vfs_dev_uart_use_driver(CONFIG_ESPTIC_UART_NUM);

	while (1)
		tic2json_main();
}
