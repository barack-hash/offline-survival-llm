#!/usr/bin/env bash
# Re-render every part to stl/ and refresh the viewer's layout.json.
set -e
cd "$(dirname "$0")"
mkdir -p stl
for p in tub bezel retainer trim pipes ghost_stack ghost_eink ghost_kb; do
  openscad -D "part=\"$p\"" --export-format binstl -o "stl/$p.stl" enclosure.scad 2> "stl/.$p.log"
  grep -iE "warning|error" "stl/.$p.log" | grep -v "Status:" || true
done
grep -o 'LAYOUT {.*}' stl/.tub.log | head -1 | sed 's/^LAYOUT //' > stl/layout.json
grep -o 'Outer W.*mm feet)' stl/.tub.log | head -1
rm -f stl/.*.log
