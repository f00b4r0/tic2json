# _mbed-os-tic2json_

Non-functional implementation of tic2json for ARM Mbed.
Gets TIC data on RX pin, outputs formatted JSON on UART TX.

**Note:** it seems using stdio on this platform does not produce the expected
results so this implementation will probably need more work. TBC.

### Configure the project

* Edit `tic2json/mbed_lib.json`: in `macros` adjust for `TICV01` or `TICV02`
* Edit `main.cpp`, adjust defines at the top
* Copy or link `mbed-os`

### Build and Flash

Before build, run `make -C tic2json/src csources`

Build the project and flash it to the board, using Mbed Studio or `mbed`.

Note: ARMC6 does not seem to correctly build this, use GCC_ARM instead.
