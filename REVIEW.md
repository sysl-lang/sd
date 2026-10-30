# Review findings

The 2026-10-28 review of `sd` (against dev 713d402). Findings 1, 7, 8 and 9 are about `sysl-lang/spi`
and are recorded there.

| # | Finding | Status | Where |
|---|---|---|---|
| 2 | `Card[B: Device + Clock]` puts the clock on the transport | Fixed: `Card[D: Device, K: Clock]`, `card(device, clock, settings)` | ca43599 (0.1.0) |
| 3 | Cleanup idiom hand-copied ~15 times | Fixed: one `finish(outcome, cleanup)` in the root module. spi's `transaction` does not fit sd, because its operation must fail with `spi.Error` and SD's release also clocks an idle byte after deselect | c97b3d9 (0.2.0) |
| 4 | Native backend duplicates the SPI skeleton | Fixed: `Media` trait, `Settings.validate`, `argument`/`span`, `NO_INFO` and the FAT error mapping are shared. Each backend keeps a seven-line `BlockDevice` impl of one-line forwards, because an `impl[M: Media] BlockDevice for M` is refused by design ("'M' is a type parameter of this 'impl', so it stands for every type at once") | c97b3d9 (0.2.0) |
| 5 | Native `Host` reuses `sd.Error` with no transport variant | Fixed: `Error.Host(HostError)` with `Io`, `Timeout`, `CommandCrc`, `DataCrc`, `Overrun`, `Underrun`. The portable probe reports `HostError.Io` | c97b3d9 (0.2.0) |
| 6 | Magic command numbers and register masks | Fixed: named command indices, OCR, IF_COND, card-status and R6 constants. No production `512` beside `SECTOR_SIZE` | c97b3d9 (0.2.0) |
| 10 | README is a changelog, pins `rev = "dev"`, stale ROADMAP | Fixed: present tense, pins a version, ROADMAP current | c97b3d9 (0.2.0), be5b035 |
| 11 | Overlapping `Error` card-status variants; `Phase` reuses `Response` | Fixed: `R1(u8)`, `R2(u16)`, `CardStatus(u32)`, named by format; `Error.Response` is gone | c97b3d9 (0.2.0) |
| 12 | Long positional constructors in `Settings` and both fakes | Fixed: `settings(...)` takes named arguments with defaults, and both fakes are built by name | c97b3d9 (0.2.0) |
| 13 | Mode-indexed tests | Fixed: one test per fault | c97b3d9 (0.2.0) |
| 14 | Too much of the root module is public | Fixed: helpers, CRCs and `check_status` are `private[sd]`/`private[native]`. `card_status_error` and `CARD_STATUS_ERRORS` are public on purpose, for hosts. `Settings` is fixed at construction | c97b3d9 (0.2.0), 8aa7baf |
| 15 | `information(self)` and fat's `sectors(self)` copy the `Card` | Fixed: `information(*self)`. `sectors(self)` only reads, and from sysl 0.8.5 a read-only `(self)` method is lent by address rather than copied (sysl bca895b1) | c97b3d9 (0.2.0); sysl 0.8.5 |
| 16 | Native `initialize` keeps stale `info` and publishes before `sync` | Fixed: `initialize` resets `info`, polls readiness through a private helper and publishes only on success | c97b3d9 (0.2.0) |
| 17 | Idiom nits | Fixed in sd: `for _ in`, `BusWidth` enum, a comment on the power-up delay, the probe's externs renamed `port_*`. `Mode.Mode0` is spi's | c97b3d9 (0.2.0) |
| 18 | `Response.NoCrc` mixes two axes | Fixed: `Response.{Empty, R1, R2, R3}` | c97b3d9 (0.2.0) |
| — | Host data callbacks ignored the data command's R1 | Fixed: `read_data`/`write_data` return the R1 and the card checks it on every data path. A run refused in its R1 gets no CMD12 | be5b035 (0.3.0) |
| — | SPI test `FakeClock` held in module vars | Fixed: each test owns its `Time`, and `FakeClock` holds a `*Time` | be04465 (0.1.1) |
