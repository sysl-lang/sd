# sd

A standalone Sysl SD-card driver for embedded firmware: no operating system,
allocator or floating point. ISC licensed.

Two backends answer one `sh.sysl.sd.Media` trait: SPI mode (`sh.sysl.sd.spi`)
and native SD hosts (`sh.sysl.sd.native`). Both handle SDSC (v1/v2), SDHC and
SDXC with 512-byte sectors, CSD capacity discovery, bounded polling, busy
handling and programming-status checks. SDIO functions, MMC/eMMC, SDUC and
high-speed switching are not implemented. Physical cards have not been validated.

```hocon
dependencies {
  sd { git = "github.com/sysl-lang/sd", version = "0.2.1", features = [fat] }
}
```

## Use

```sysl
import sh.sysl.sd.settings
import sh.sysl.sd.spi.card
import sh.sysl.fat.mount

var sd = card(my_spi_device,my_clock,settings(transfer_hz = 12000000))
val info = sd.initialize().unwrap()
var sector: [512]u8
var volume = mount(&sd,sector[..]).unwrap()
```

`card(device, clock, settings)` takes an `sh.sysl.spi.Device` and a separate
`sh.sysl.sd.Clock`: the clock is a board-wide service, not part of the SPI link.
`spi.device(bus, cs, config)` makes a `Device` from an MCU's `spi.Bus` and
`spi.ChipSelect`. The platform supplies a monotonic microsecond clock and
bounded hardware waits; SPI callbacks must return on hardware failure, since an
outer deadline cannot interrupt a callback that never returns. Poll-count limits
additionally bound a frozen clock.

`settings()` takes every field by name, with defaults: initialization at
400 kHz, transfer at 8 MHz, data CRC checking on. `Settings.validate()` is what
`initialize` checks first.

## Media

`initialize`, `information`, `read_sector`, `write_sector`, `read_sectors`,
`write_sectors` and `sync`. A multi-sector call takes a buffer of whole sectors.
Writes wait for programming completion and check the card's status; `sync()`
checks readiness and status again. A failed write may already have changed the
media and is never automatically retried. Read buffers must be discarded on
error. Reinitialize after removal or bus recovery; a failed initialization
forgets the previous card.

Errors are `sh.sysl.sd.Error`. A transport failure is `Bus` (SPI) or `Host`
(a native controller's `HostError`); an error the card reports keeps the format
its transport carries: `R1` and `R2` for SPI mode, `CardStatus` for native hosts.

## FAT

The optional `fat` feature implements `fat.BlockDevice` for both cards. The
adapter exposes the whole card and does not parse partition tables: mount an
unpartitioned FAT volume, or supply a partition-offset view. It keeps range and
buffer errors and maps every other failure to `DeviceError.Io(code)`, where
`code` is a fixed number per `Error` variant (a variant's payload is not
encoded; 0 is never used): `Bus` 1, `Host` 2, `NotInitialized` 3,
`InvalidSettings` 4, `BadLength` 5, `OutOfRange` 6, `WriteProtected` 7,
`Timeout` 8, `R1` 9, `R2` 10, `CardStatus` 11, `Voltage` 12, `Echo` 13,
`UnsupportedCsd` 14, `InvalidCsd` 15, `InvalidScr` 16, `Crc` 17, `ReadToken` 18,
`WriteRejected` 19. The card's own methods keep the full error. Mount only after initialization. The application
serializes a card and its shared bus for complete operations. These guarantees
do not make FAT operations atomic.

## Native SD hosts

`sh.sysl.sd.native.card(host, clock, settings)` drives an SD v2 memory card
through a controller adapter implementing the allocation-free `Host` trait:
configure the clock and `BusWidth`, send a command expecting a `Response`
(`Empty`, `R1`, `R2`, `R3`), and transfer command-associated data with a
bounded timeout. R2 words are most significant first. Data callbacks check both
R1 and controller transfer errors and report a controller failure as
`Error.Host`. Initialization sends CMD0/8, ACMD41, CMD2/3/9/7, reads the SCR and
negotiates a four-bit bus when the card has one. Host hardware checks command and
data CRCs; the `check_crc` setting is SPI's. The adapter owns DMA/cache policy
and arbitration.

`read_sectors` and `write_sectors` are bounded by `Host.max_blocks()`: single
sectors use CMD17/24, longer runs CMD18/25 followed by CMD12, including after a
data error. The FAT adapter uses them for bulk block I/O. On SPI the same calls
send one single-block command per sector.

Protocol references: [SD Association simplified specifications](https://www.sdcard.org/downloads/pls/),
[Physical Layer v6, sections 5 and 7 (public mirror)](https://academy.cba.mit.edu/classes/networking_communications/SD/SD.pdf),
[Analog Devices AN-1443](https://www.analog.com/en/resources/app-notes/an-1443.html).

## Validation

`./scripts/gate.sh` runs the tests without and with the FAT feature, then
builds instantiated archives with and without FAT for Cortex-M0+, Cortex-M4,
Cortex-M33, RV32 and AArch64 freestanding targets. The build probes use
unresolved board callbacks, so they exercise every driver path without an OS
or heap; they are compile and link-input checks, not execution on those
processors. Protocol tests run against an independent SPI-mode card peer with
its own CRC implementations, and against a fake native host.
