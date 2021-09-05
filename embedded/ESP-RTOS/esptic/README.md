# _esptic_

Quick & dirty implementation of tic2json for ESP8266/ESP32.
Gets TIC data on RX pin, outputs formatted JSON on UART TX.

### Configure the project

`idf.py menuconfig`

* Set TIC baudrate and UART under Component config -> esptic
* Set TIC version under Component config -> tic2json

### Build and Flash

Build the project and flash it to the board:

`idf.py flash`

See the Getting Started Guide for full steps to configure and use ESP-IDF to build projects.
