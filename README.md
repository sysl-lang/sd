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

Implement `sh.sysl.sd.spi.Spi` for your MCU's SPI controller and chip-select pin.
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
The core has no filesystem dependency. The adapter preserves range/buffer errors
and maps other driver failures to `DeviceError.Io`; direct sector APIs retain
full errors. Mount only after initialization. The application must serialize a
card and lock a shared SPI bus for complete operations, including setup/cleanup.

Default settings initialize at 400 kHz, transfer at 8 MHz and enable data CRC
checking. Supply and pin-mux setup, card detection and physical write-protect
switches belong to the board transport. CSD write protection is enforced. SPI
callbacks must return on hardware failure: an outer deadline cannot interrupt a
callback that never returns. Poll-count limits additionally bound a frozen clock.

Writes wait for programming completion and check CMD13 status; `flush` checks
readiness/status again. A failed write may already have changed media and is
never automatically retried. Read buffers must be discarded on error. Reinitialize
after removal or bus recovery. These guarantees do not make FAT operations atomic.

Protocol references: [SD Association simplified specifications](https://www.sdcard.org/downloads/pls/),
[Physical Layer v6, sections 5 and 7 (public mirror)](https://academy.cba.mit.edu/classes/networking_communications/SD/SD.pdf),
[Analog Devices AN-1443](https://www.analog.com/en/resources/app-notes/an-1443.html).
