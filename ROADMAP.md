# Roadmap

- [x] SPI initialization, 512-byte reads/writes, CRC, capacity and timeout handling.
- [x] Optional fat.BlockDevice integration, protocol regressions and freestanding builds.
- [x] Native SD v2 host backend with multiblock transfers.
- [x] One `Media` trait for both backends.
- [ ] Physical SPI card/board validation.
- [ ] SPI multiblock commands (CMD18/25); SPI `read_sectors`/`write_sectors` send one command per sector.
- [ ] Legacy cards without CMD8 on native hosts, MMC/eMMC, SDIO, SDUC, high-speed switching.
