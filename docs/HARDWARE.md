# Hardware & Tools Register

| Item | Model/Details | Source | Cost | Used for | First used |
|---|---|---|---|---|---|
| Raspberry Pi 5 | Model B Rev 1.1, 8GB RAM, 128GB microSD (117G usable), Debian 13 trixie, kernel 6.18.50+rpt-rpi-2712 | (fill in) | (fill in) | Main compute | 2026-09-15 |
| Active cooler (fan+heatsink) | 4-pin FAN header, ~1150 RPM idle / ~3600 RPM load | (fill in) | (fill in) | Pi 5 cooling — required to avoid thermal throttling during inference | 2026-09-15 |
| Arduino starter kit | LAFVIN Super Starter Kit for UNO R3 | (fill in) | (fill in) | Physical input + interim display | 2026-09-16 (identified from kit box photo) |
| Arduino UNO R3 (from kit) | LAFVIN clone, ATmega328P | kit | — | Input controller: IR decode, multi-tap, LCD driving, serial link to Pi | 2026-09-18 |
| LCD1602 w/ I2C backpack (from kit) | 16x2 chars, I2C addr 0x27, contrast trim on backpack | kit | — | Interim answer display until e-ink (5b) | 2026-09-18 |
| IR remote + receiver (from kit) | NEC protocol, 17 buttons (arrows/OK/0-9/*/#); receiver module pins G/R/Y | kit | — | Text input via multi-tap — replaced the defective keypad | 2026-09-18 |
| 4x4 membrane keypad (from kit) | **DEFECTIVE** — internal shorts, ribbon lines 1-8 and 4-6 permanently closed (stuck 'A'/'0') | kit | — | Unusable; kept as spare parts. Replacement optional (issue #5) | 2026-09-18 |
