# _esptic_

Implementation of tic2json for ESP8266/ESP32.
Gets TIC data on RX pin, outputs formatted JSON over UDP.

### Configure the project

`idf.py menuconfig`

* Under Component config -> esptic, set the following:
  * UART for receiving TIC frames and TIC baudrate
  * GPIO number for LED heartbeat and LED active state
  * WiFi SSID and password
  * Target UDP host and port
* Under Component config -> tic2json, set TIC version

### Build and Flash

Build the project and flash it to the board:

`idf.py flash`

See the Getting Started Guide for full steps to configure and use ESP-IDF to build projects.

Tested working on ESP8266 and ESP32.
