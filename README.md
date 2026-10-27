# sd

A standalone Sysl SD-card driver for embedded firmware. No Benchtop dependency,
operating system, allocator or floating point. ISC licensed.

The first backend is SPI mode: SDSC (v1/v2), SDHC and SDXC at 3.3 V, with
512-byte sector reads/writes, CSD capacity discovery, command/data CRCs, bounded
polling, busy handling and programming-status checks. A native SD v2 backend
now supports SDMMC host adapters with shared metadata and FAT integration. SDIO
functions, MMC/eMMC, SDUC and high-speed switching are not implemented yet.
This initial implementation is not validated on physical cards.

```hocon
dependencies {
  sd { git = "github.com/sysl-lang/sd", rev = "dev", features = [fat] }
}
```

Implement `sh.sysl.spi.Device` for your MCU connection (or wrap `spi.Bus` and
`spi.ChipSelect` with `spi.exclusive`), and implement `sh.sysl.sd.Clock` on the
transport for SD polling deadlines.
The platform supplies a monotonic microsecond clock and bounded hardware waits.
Default bulk read/write methods use byte exchanges; implementations may override
them with DMA. The driver owns the transport, uses caller buffers and keeps CS
asserted through complete command/data transactions.

```sysl
import sh.sysl.sd.spi.card
import sh.sysl.fat.mount

var sd = card(my_spi_transport)
val info = sd.initialize()?
var sector: [512]u8
var volume = mount(&sd,sector[..])?
```

Enable the optional `fat` feature to implement `fat.BlockDevice` for the card.
The core depends on the standalone `spi` interfaces, with no filesystem dependency.
The adapter exposes the whole card; it does not parse partition tables. Mount an
unpartitioned FAT volume, or supply a partition-offset block-device view for a
partitioned card. The adapter preserves range/buffer errors
and maps other driver failures to `DeviceError.Io`; direct sector APIs retain
full errors. Mount only after initialization. The application must serialize a
card and lock a shared SPI bus for complete operations, including setup/cleanup.

Default settings initialize at 400 kHz, transfer at 8 MHz and enable data CRC
checking. Supply and pin-mux setup, card detection and physical write-protect
switches belong to the board transport. CSD write protection is enforced. SPI
callbacks must return on hardware failure: an outer deadline cannot interrupt a
callback that never returns. Poll-count limits additionally bound a frozen clock.

Writes wait for programming completion and check CMD13 status; `sync()` checks
readiness/status again (the FAT adapter calls it from `flush`). A failed write may already have changed media and is
never automatically retried. Read buffers must be discarded on error. Reinitialize
after removal or bus recovery. These guarantees do not make FAT operations atomic.

Protocol references: [SD Association simplified specifications](https://www.sdcard.org/downloads/pls/),
[Physical Layer v6, sections 5 and 7 (public mirror)](https://academy.cba.mit.edu/classes/networking_communications/SD/SD.pdf),
[Analog Devices AN-1443](https://www.analog.com/en/resources/app-notes/an-1443.html).

## Validation

Run `./scripts/gate.sh`: core-only tests, tests with the optional FAT integration,
and instantiated archives both with and without FAT for Cortex-M0+, Cortex-M4,
Cortex-M33, RV32 and AArch64 freestanding targets. The build probes use unresolved
board callbacks so they exercise all driver paths without an OS or heap; they
are compile/link-input checks, not execution on those processors.

Protocol tests use an independent test peer, command golden vectors and a
separate CRC implementation. Benchtop card emulation and physical-card validation
are later steps. Development uses `dev`; no release tag is published yet.

Validation on October 27, 2026, using Sysl 0.7.0: 14 core-only tests and 15 tests
with FAT enabled passed. All ten freestanding archives built successfully (the
five targets above, each with and without FAT). This verifies protocol behavior
against the independent peer and compilation of the instantiated APIs; physical
cards, MCU transports and Benchtop integration have not yet been validated.

## Native SD hosts

`sh.sysl.sd.native` supports native SD v2 memory-card initialization and
single-sector and multiblock reads/writes, alongside the existing SPI driver. Implement its
allocation-free `Host` trait and `sh.sysl.sd.Clock` for a controller adapter:
configure the bus, send commands with none/short/long/no-CRC responses, and
transfer command-associated data with bounded timeouts. Data callbacks check
both R1 and controller transfer errors; sector and SCR transfers receive their
configured timeout explicitly. Native response words are MSW first.

`native.card(host)` exposes the same initialize/information/read_sector/
write_sector/sync API and optional `fat.BlockDevice` interface as SPI. It sends
CMD0/8, CMD55/ACMD41, CMD2/3/9/7, reads SCR and negotiates four-bit mode when
available. CSD parsing/capacity, settings, errors and the FAT block-device
contract are shared. Host hardware supplies command/data CRC checking; the SPI
`check_crc` setting does not disable native CRC. Writes wait for CMD13 readiness;
accepted writes are never automatically retried.

The initial native path targets SD v2 memory cards; legacy cards without CMD8,
MMC/eMMC, SDIO functions and high-speed switching are not
implemented. The host adapter owns DMA/cache policy and platform arbitration;
this package has no register addresses, filesystem or OS dependency. The
portability probes instantiate native and SPI transfers, with and without FAT,
for all five supported freestanding probe targets.

Native cards expose `read_sectors` and `write_sectors` for caller-owned buffers
whose lengths are multiples of 512 bytes. Requests are bounded by
`Host.max_blocks()`; single sectors retain CMD17/24, while larger chunks use
CMD18/25 followed by CMD12, including cleanup after data errors. The optional
FAT adapter overrides bulk block I/O to use these transfers. Failed writes may
have committed a prefix and are never automatically retried. SPI keeps its
existing single-sector implementation through FAT's default bulk methods.

Multiblock validation with Sysl 0.7.2: 20 core-only tests, 21 tests with FAT,
and all ten freestanding archives passed. Benchtop exercises the native host
through the real firmware; physical cards remain unvalidated.
