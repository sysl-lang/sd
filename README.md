# sd

A standalone Sysl SD-card driver for embedded firmware. No Benchtop dependency,
operating system, allocator or floating point. ISC licensed.

The first backend is SPI mode: SDSC (v1/v2), SDHC and SDXC at 3.3 V, with
512-byte sector reads/writes, CSD capacity discovery, command/data CRCs, bounded
polling, busy handling and programming-status checks. Native SDMMC/SDIO,
SDUC, high-speed switching and multi-block transfers are not implemented yet.
This initial implementation is not validated on physical cards.

```hocon
dependencies {
  sd { git = "github.com/sysl-lang/sd", branch = "dev", features = [fat] }
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
