# _picotic_

Quick & dirty implementation of tic2json for Raspberry Pi Pico.
Gets TIC data on RX pin, outputs formatted JSON on UART TX.

### Configure the project

* Set environnment variable `PICO_SDK_PATH`
* Run CMake and set **either** of the top CMakeLists.txt options (`TICVERSION_01` or `TICVERSION_02`):

`cmake -B build . -DTICVERSION_02=ON`

### Build and Flash

Build the project and flash it to the board:

`make -C build`

See the Getting Started Guide for full steps to configure and use the Pico SDK to build projects.
