# tic2json

An ENEDIS TIC (_Télé-Information Client_) protocol parser and converter

More info (in French): http://hacks.slashdirt.org/sw/tic2json/

Example Grafana dashboard:
![screenshot](http://hacks.slashdirt.org/sw/tic2json/grafana-small.png)

See a live snapshot [here](https://snapshot.raintank.io/dashboard/snapshot/a1IBs3c0q9mrOLpFwFnlHhgERy9ryQkM?orgId=2&from=1630921569846&to=1630943217317)

## License

GPLv2-only - http://www.gnu.org/licenses/gpl-2.0.html

Copyright: (C) 2021 Thibaut VARÈNE

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

## Usage

The current implementation supports TIC versions **01** and **02** (a.k.a *historique* and *standard* modes).

A tty interfaced to the meter TIC output (using e.g. [TIC2UART](http://hacks.slashdirt.org/hw/tic2uart/))
can be set using the following `stty` settings:

```sh
stty -F <serial_tty> <speed> raw evenp
````

Where `<serial_tty>` is the target tty (e.g. `/dev/ttyS0`) and `<speed>` is either 1200 or 9600.

TIC output from electronic meters is either:
 - **7E1@1200bps** for "historique" mode
 - **7E1@9600bps** for "standard" mode

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
    timestamp_timezone = "Local"
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

## Embedded applications

Embedded application are provided in the `embedded` folder for the following platforms:

- Espressif ESP8266 and ESP32 (send TIC JSON data over UDP)
- Raspberry Pi Pico (basic demonstration stub)
- ARM Mbed (not functional)

Only the Espressif variant is a fully fledged application, capable of logging to a remote UDP host.

The others are very simple stubs that (ab)use the stdio interface provided by these platforms, as a starting point example.
