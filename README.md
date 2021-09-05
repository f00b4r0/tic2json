# tic2json

An ENEDIS TIC (_Télé-Information Client_) protocol parser and converter

More info (in French): http://hacks.slashdirt.org/sw/tic2json/

## License

GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
Copyright: (C) 2021 Thibaut VARÈNE

See LICENSE.md for details

## Dependencies

 - A **C compiler** supporting the C standard library for the target system (e.g. **gcc**)
 - **make**, **flex** and **bison** on the build host
 
## Building

To build, run `make`

**Note:** the build can be adjusted through the top Makefile variables.
In particular, it is possible to build support for only specific version(s) of the TIC.

## Usage

The current implementation supports TIC versions **01** and **02** (a.k.a *historique* and *standard* modes).

A tty interfaced to the meter TIC output can be set using the following `stty`
settings:

```sh
stty -F <serial_tty> <speed> raw evenp
````

Where `<serial_tty>` is the target tty (e.g. `/dev/ttyS0`) and `<speed>` is either 1200 or 9600.

TIC output from electronic meters is either:
 - 7E1@1200bps for "historique" mode
 - 7E1@9600bps for "standard" mode

## Notes

Implementing other types of outputs (XML, etc) should be trivial given the implementation.

For reference, the output of this tool is suitable for feeding a Telegraf 'socket_listener' configured as follows:

```
[[inputs.socket_listener]]
  service_address = "udp://:8094"
  data_format = "json"
  json_strict = true
  json_name_key = "label"
  tag_keys = ["id"]
````

The following command line can be used to send adequate data:

```sh
stdbuf -oL ./tic2json -2 < /dev/ttyS0 2>/dev/null | while read line; do echo "$line" | nc -q 0 -u telegraf_host 8094; done
```