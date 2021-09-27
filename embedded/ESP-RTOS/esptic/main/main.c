//
//  main.c
//  app stub for ESP8266/ESP32
//
//  (C) 2021 Thibaut VARENE
//  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
//

/**
 * @file
 * @note: Memory usage detailed below has been tested on ESP8266 in "Release" (-Os) build:
 * Receives TIC on RX, outputs JSON via UDP.
 *  - TICV01: max stack 5400, max heap: 3764+80
 *  - TICV02: max stack 5816, max heap: 3764+80
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_vfs_dev.h"
#include "esp_log.h"
#include "driver/uart.h"

#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "lwip/netdb.h"

#define XSTR(s) STR(s)
#define STR(s) #s

#define UDPBUFSIZE	1432	// avoid fragmentation

static const char * TAG = "esptic";
static struct sockaddr Gai_addr;
static socklen_t Gai_addrlen;
static int Gsockfd;

typedef void (*tic2json_framecb_t)(char * buf, size_t size);
void tic2json_main(FILE * yyin, char * buf, size_t size, tic2json_framecb_t cb);
void wifista_main(void);

static int udp_setup(void)
{
	struct addrinfo hints, *result, *rp;
	int ret;

	// obtain address(es) matching host/port
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_protocol = IPPROTO_UDP;

	ret = getaddrinfo(CONFIG_ESPTIC_UDP_HOST, CONFIG_ESPTIC_UDP_PORT, &hints, &result);
	if (ret) {
		ESP_LOGE(TAG, "getaddrinfo: %d", ret);
		return ESP_FAIL;
	}

	// try each address until one succeeds
	for (rp = result; rp; rp = rp->ai_next) {
		Gsockfd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
		if (-1 != Gsockfd)
			break;	// success
	}

	if (!rp) {
		ESP_LOGE(TAG, "Could not reach server");
		ret = ESP_FAIL;
		goto cleanup;
	}

	memcpy(&Gai_addr, rp->ai_addr, sizeof(Gai_addr));
	Gai_addrlen = rp->ai_addrlen;

	ret = ESP_OK;

cleanup:
	freeaddrinfo(result);
	return (ret);

}

static void ticframecb(char * buf, size_t size)
{
	sendto(Gsockfd, buf, size, 0, &Gai_addr, Gai_addrlen);
}

void app_main(void)
{
	FILE *yyin;
	static char buf[UDPBUFSIZE];

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

	/* start wifi */
	wifista_main();
	
	/* setup UDP client */
	ESP_ERROR_CHECK(udp_setup());

	yyin = fopen("/dev/uart/" XSTR(CONFIG_ESPTIC_UART_NUM), "r");
	if (!yyin) {
		ESP_LOGE(TAG, "Cannot open UART");
		abort();
	}

	ESP_LOGI(TAG, "Rock'n'roll");

	while (1)
		tic2json_main(yyin, buf, UDPBUFSIZE, ticframecb);
}
