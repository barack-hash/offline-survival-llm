# Enclosure (Phase 7) — DRAFT v0.3, not print-ready

Parametric OpenSCAD model of a handheld enclosure: 4.2" e-ink screen on top,
CardKB keyboard below, Pi 5 + Geekworm X1202 UPS + 4× 18650 stacked behind
the screen only. Outer size ≈ 109 × 170 mm; **59 mm deep behind the screen,
11.4 mm at the keyboard**, joined by a sloped step on the back.

Confirmed from manufacturer specs: e-ink board 103.0 × 78.5, display area
84.8 × 63.6, panel 90.1 × 77.0 × 1.18 (Waveshare manual); CardKB v1.1
88.0 × 54.0 × 5.0 (M5Stack store); X1202 PCB 97.4 × 85 (Geekworm wiki).

**Do not send these STLs to a print service yet.** Several component sizes
come from datasheets and listings rather than the actual parts; each one is
marked `VERIFY` in `enclosure.scad`. When the parts arrive, measure them
with calipers, update the numbers, and re-render.

## Files
- `enclosure.scad` — the model; every dimension is a named parameter
- `stl/` — rendered parts: `tub`, `bezel`, `retainer` (printed) and
  `ghost_*` (stand-ins for the electronics, for the viewer only)
- `viewer.html` — 3D viewer (orbit, explode, show/hide parts)

## Re-render
```bash
for p in tub bezel retainer ghost_stack ghost_eink ghost_kb; do
  openscad -D "part=\"$p\"" --export-format binstl -o stl/$p.stl enclosure.scad
done
```
View: `python3 -m http.server 8765` in this folder, then open
http://localhost:8765/viewer.html (the STLs can't load from `file://`).

## Hardware for assembly
- 4× M3 heat-set inserts + 4× M3 button-head screws (bezel to tub)
- 6× M2 self-tapping screws (retainer to bezel posts)
- 4× 10 mm stick-on rubber feet
