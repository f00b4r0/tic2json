# tic2json

An ENEDIS TIC (_Télé-Information Client_) protocol parser and converter

More info (in French): http://hacks.slashdirt.org/sw/tic2json/

Example Grafana dashboard:
![screenshot](http://hacks.slashdirt.org/sw/tic2json/grafana-small.png)

## License

GPLv2-only - http://www.gnu.org/licenses/gpl-2.0.html

Copyright: (C) 2021-2023 Thibaut VARÈNE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License version 2,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See LICENSE.md for details

## Dependencies

 - A **C compiler** supporting the C standard library for the target system (e.g. **gcc**)
 - **make**, **flex** and **bison** on the build host
 
## Building

To build, run `cd src; make`

**Note:** the build can be adjusted through the top Makefile variables.
In particular, it is possible to build support for only specific version(s) of the TIC.

For integration with embedded applications, defining `BAREBUILD` and/or `PRINT2BUF` provides
access to an API that may be more suitable. See examples in the `embedded` folder.

## Usage

The current implementation supports TIC versions **01** and **02** (a.k.a *historique* and *standard* modes).
It also provides a near complete support for the TIC output of *PME-PMI* meters.

The tool emits one root JSON object per TIC frame. Each root object is followed by a new line.
Usage help is available by executing the software with the `-h` parameter.

A tty interfaced to the meter TIC output (using e.g. [TIC2UART](http://hacks.slashdirt.org/hw/tic2uart/))
can be set using the following `stty` settings:

```sh
stty -F <serial_tty> <speed> raw evenp
````

Where `<serial_tty>` is the target tty (e.g. `/dev/ttyS0`) and `<speed>` is either 1200 or 9600.

TIC output from electronic meters is either:
 - **7E1@1200bps** for "historique" mode
 - **7E1@9600bps** for "standard" mode
 
For *PME-PMI* meters, the output is **7E1** at a speed set by Enedis (1200 (default), 2400, 4800, 9600 or 19200bps).

## Notes

Implementing other types of outputs (XML, etc) should be trivial given the implementation.

### Using output with Telegraf

For reference, the output of this tool is suitable for feeding a Telegraf 'socket_listener' configured as follows:

```toml
[[inputs.socket_listener]]
  service_address = "udp://:8094"
  data_format = "json"
  json_strict = true
  json_name_key = "label"
  tag_keys = ["id"]
````

The following command line can be used to send adequate data (works for either TIC 01 or TIC 02):

```sh
stdbuf -oL ./tic2json -1 < /dev/ttyS0 | while read line; do echo "$line" | nc -q 0 -u telegraf_host 8094; done
```

Alternatively, using dictionnary output and JSON_v2 parser for TIC "standard" processing:

```toml
[[inputs.socket_listener]]
  service_address = "udp://:8094"
  data_format = "json_v2"
  [[inputs.socket_listener.json_v2]]
    measurement_name = "ticv2"
    timestamp_path = "DATE.horodate"
    timestamp_format = "rfc3339"
    [[inputs.socket_listener.json_v2.object]]
      path = "@this"
      included_keys = [ "PRM_data", "EAST_data", "IRMS1_data", "URMS1_data", "SINSTS_data", "SMAXSN_data", "UMOY1_data" ]
      tags = [ "PRM_data" ]
      [inputs.socket_listener.json_v2.object.renames]
        PRM_data = "PRM"
```

Fed with:

```sh
stdbuf -oL ./tic2json -2 -dr < /dev/ttyS0 | while read line; do echo "$line" | nc -q 0 -u telegraf_host 8094; done
```

Will only log `EAST`, `IRMS1`, `URMS1`, `SINSTS`, `SMAXSN` and `UMOY1`, tagged with `PRM` (the meter's ID), at the timestamp provided by the meter.

Note: the 'xpath_json' format parser may be an even better choice than `json_v2`. Setup is left as an exercise for the reader.

Note: 'socket_listener' expects _exactly_ 1 JSON object per UDP packet (decoding of data is done on a per-packet basis),
hence the need to send each line individually with `nc`. Another alternative is to use the script provided in `tools/ticprocess.py`.

#### PME-PMI specifics

The PME-PMI meter uses a variant of TIC 01 that does not provide enough date/time information to infer the current DST and adjust the UTC offset in the converted (-r) date output.

In that case, the converted horodate will ommit this offset in the output. The resulting string is still valid ISO 8601 but no longer valid RFC3339.

The following configuration can be used with telegraf's JSON_v2 parser to correctly handle this:

```toml
    timestamp_path = "DATE.horodate"
    timestamp_format = "2006-01-02T15:04:05"
    timestamp_timezone = "Local"
```

The timestamps will be logged following the telegraf server timezone which is assumed to be the same as that of the meter (adjust as necessary).

Note: if using Telegraf to ingest the data, the 'xpath_json' format parser may actually be more suitable as it makes handling underscores in labels easier.

## Embedded applications

The following embedded applications are based on this tool

- [esptic2udp](http://vcs.slashdirt.org/git/sw/ESP/esptic2udp.git) - Espressif ESP8266/ESP32 Enedis TIC data to JSON converter and UDP sender

Stub applications are provided in the `embedded` folder for the following platforms:

- Raspberry Pi Pico (basic demonstration stub): **picotic** gets TIC data on RX pin, outputs formatted JSON on UART TX

These are very simple stubs that (ab)use the stdio interface provided by these platforms, as a starting point example.
