# Plumbing = conduits: what runs through each pipe

The copper pipes on the enclosure are cable conduits (3/8" OD soft copper,
7.9 mm bore). Each line enters the case through a gland in the top face,
runs down the side, and ends at the junction box under the step, where the
external ports are. Model: `enclosure/enclosure.scad` (`plumbing` section).

## Left pipe — data line

| Wires | From (inside the case) | To | Purpose |
|---|---|---|---|
| USB 2.0 (4× 26 AWG: 5V, D−, D+, GND, twisted D± pair) | Pi 5 USB-A port via a solderable USB-A **plug** breakout | USB-A **socket** breakout in the junction box | Load new books/manuals from a USB stick; back up the corpus and logs |
| I2C accessory (4× 28 AWG: 3V3, GND, SDA, SCL) | Pi GPIO pins 1/6/3/5 (same bus as CardKB 0x5F and the X1202 fuel gauge) | Grove socket, "AUX I2C" | Plug-in modules without opening the case (e.g. BME280 barometer for weather, compass, GPS with I2C). Check each module's I2C address doesn't clash with 0x5F / the X1202 gauge. |
| Status LED (4× 28 AWG: R, G, B, common GND) | 3 Pi GPIOs through 3× 220 Ω resistors | 5 mm common-cathode RGB LED in the gauge housing (tee branch) | Battery level (green / amber / red from the X1202 fuel gauge) and a "thinking" pulse while an answer generates |

## Right pipe — power line

| Wires | From | To | Purpose |
|---|---|---|---|
| DC in (2× 18 AWG silicone) | 5.5×2.1 mm **plug** pigtail into the X1202's DC jack | 5.5×2.1 mm panel-mount jack, "SOLAR 6-18V" | Solar panel (via a 12 V regulator — never a raw panel, its open-circuit voltage exceeds 18 V) or car 12 V |
| Power button (2× 28 AWG) | Pi 5 J2 power-button header | 6×6 mm tactile switch in the valve body; the valve wheel is its cap | Power on / clean shutdown from outside the case |

The X1202's USB-C charge port stays directly on the right wall (it carries
5 V 5 A — no extension).

## Parts for the plumbing (per device)

- 3/8" OD soft copper tube, ~420 mm total (per side centreline lengths from
  the model: riser 8, top run 17.3, upper side 60.5, lower side 91, into box
  28.3 mm — subtract your fittings' socket depth)
- 6× 3/8" brass compression elbows, 2× 3/8" brass compression tees
  (or print `fittings`)
- Printed: glands/clamps (`fittings`), `manifold` + `manifold_lid`,
  `gauge_face` (white or clear filament), `valve_cap`
- USB-A plug + socket solderable breakouts, Grove socket, 5.5×2.1 panel jack
  + 5.5×2.1 plug pigtail, 5 mm RGB LED (common cathode) + 3× 220 Ω,
  6×6 mm tactile switch, silicone wire (18/26/28 AWG), heat-shrink
- Rubber grommet or heat-shrink collar at every tube end — copper edges cut
  insulation. Deburr each cut.

## Notes
- Wire through each pipe before fitting it: connectors don't fit the 7.9 mm
  bore, so the breakouts are soldered after the wires are pulled through.
- The tubes are not electrically connected to anything; keep it that way
  (insulated wires only, no bare conductors touching copper).
