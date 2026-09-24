// enclosure.scad — handheld enclosure for the offline survival reference device
//
// Layout (device held upright, front face toward you):
//   top:    Waveshare 4.2" e-Paper Module V2 (400x300)
//   bottom: M5Stack CardKB v1.1 keyboard
//   behind the screen only: Raspberry Pi 5 + active cooler on a Geekworm
//           X1202 UPS board carrying 4x 18650 cells
//
// v0.3 profile: full depth only behind the screen, where the Pi/UPS stack
// lives; the keyboard section is ~11 mm thin; a sloped step joins the two.
//
// Printed parts:
//   tub      — rear shell: stack guides, vents, charge ports, keyboard rails
//   bezel    — flat front cap: screen window, keyboard opening
//   retainer — ring that clamps the screen against the bezel
//
// Render one part:  openscad -D 'part="tub"' -o tub.stl enclosure.scad
//
// Sizes marked VERIFY are not in any datasheet — measure the real parts with
// calipers before sending anything to a print service.

part = "assembly"; // tub | bezel | retainer | ghost_stack | ghost_eink | ghost_kb | assembly

$fn = 48;

// ---------------- components ----------------
// Waveshare 4.2inch e-Paper Module manual: driver board 103.0 x 78.5 mm,
// display area 84.8 x 63.6 mm, panel 90.1 x 77.0 x 1.18 mm.
eink_pcb   = [103.0, 78.5, 1.6];
eink_glass = [90.1, 77.0, 1.18];
eink_view  = [84.8, 63.6];
eink_view_off  = [0, 0];   // active-area centre relative to board centre — VERIFY
eink_back_clear = 3.2;     // connector + cable behind the board — VERIFY

// M5Stack store: CardKB v1.1 product size 88.0 x 54.0 x 5.0 mm.
kb     = [88.0, 54.0, 5.0];
kb_lip = 1.5;              // bezel overlap on each keyboard edge
kb_foam = 1.0;             // foam tape between rails and keyboard back

// Geekworm X1202: PCB 97.4 x 85 mm. Stack height (cells + X1202 + Pi 5 +
// active cooler) is not published; Geekworm's own case is 62.8 mm tall
// outside, so this is an estimate below that — VERIFY.
stack = [97.4, 85.0, 48.0];

// X1202 charge ports on the right-hand wall — positions VERIFY
usbc_y_off = 20;   // from stack centre, along height
dc_y_off   = -20;
port_z     = 6;    // port centre height above the tub floor

// ---------------- shell ----------------
wall      = 2.2;
floor_t   = 2.2;
bezel_t   = 2.0;
skirt     = 3.0;   // bezel side wall depth below the face
gap       = 0.8;
corner_r  = 7;
edge_ch   = 1.6;
margin_top = 10;   // top screw bosses sit above the stack
margin_bot = 12;   // engraved label
divider   = 9;     // bar between screen and keyboard
taper_len = 26;    // length of the sloped step on the back
kb_rail_h = 1.0;
retainer_t = 1.6;
boss_r    = 4.0;
mid_boss_r = 3.6;
insert_d  = 4.0;   // M3 heat-set insert (short, 4 mm)
screw_d   = 3.4;
head_d    = 6.2;
post_r    = 2.5;
post_hole = 1.8;   // M2 self-tapping
rivets    = true;
label     = "OFFLINE SURVIVAL REFERENCE";
back_text = [
    ["OFFLINE SURVIVAL REFERENCE", 4.4],
    ["CHARGE: USB-C 5V 5A  |  DC 6-18V", 3.0],
    ["", 3.0],
    ["REFERENCE AID - NOT A SOLE AUTHORITY", 2.8],
    ["FOR MEDICAL DOSING, STRUCTURAL", 2.8],
    ["OR ELECTRICAL DECISIONS", 2.8]];

// ---------------- derived ----------------
screen_layer = eink_glass[2] + eink_pcb[2] + eink_back_clear;
D_top = floor_t + stack[2] + 1 + screen_layer + bezel_t;          // behind the screen
D_bot = floor_t + kb_rail_h + kb_foam + kb[2] + bezel_t + 0.2;     // under the keyboard
bezel_depth = bezel_t + skirt;
split_z = D_top - bezel_depth;       // tub / bezel parting plane
face_z  = D_top - bezel_t;           // underside of the front face

inner_w = max(eink_pcb[0], stack[0], kb[0]) + 2*gap;
inner_h = margin_bot + kb[1] + divider + eink_pcb[1] + margin_top + 2*gap;
W = inner_w + 2*wall;
H = inner_h + 2*wall;

kb_cy   = wall + gap + margin_bot + kb[1]/2;
kb_top  = wall + gap + margin_bot + kb[1];
div_cy  = kb_top + divider/2;
ek_cy   = kb_top + divider + eink_pcb[1]/2;
top_cy  = H - wall - gap - margin_top/2;

st_y1 = H - wall - gap - margin_top + 1 - stack[1];   // stack sits under the top boss band
st_cy = st_y1 + stack[1]/2;
ys = st_y1 - 1;              // inner cavity is full depth from here up
ye = ys - taper_len;         // and keyboard-thin from here down

bosses     = [[wall+5, H-wall-4.5], [W-wall-5, H-wall-4.5]];
side_free  = (inner_w - kb[0]) / 2;
mid_bosses = [[wall+side_free/2+0.4, kb_top - 8], [W-wall-side_free/2-0.4, kb_top - 8]];
all_bosses = concat(bosses, mid_bosses);
posts = [[W/2-35, top_cy], [W/2+35, top_cy], [W/2-35, div_cy], [W/2+35, div_cy]];

echo(str("Outer W x H = ", W, " x ", H, " mm; depth ", D_top, " mm behind screen, ",
         D_bot, " mm at keyboard"));

// ---------------- helpers ----------------
module rbox(s, r) {
    r2 = max(min(r, s[0]/2 - 0.01, s[1]/2 - 0.01), 0.01);
    hull() for (x = [r2, s[0]-r2], y = [r2, s[1]-r2])
        translate([x, y, 0]) cylinder(r = r2, h = s[2]);
}
module crbox(s, r, ct = 0, cb = 0) {
    hull() {
        translate([cb, cb, 0]) rbox([s[0] - 2*cb, s[1] - 2*cb, 0.01], r - cb);
        translate([0, 0, cb]) rbox([s[0], s[1], s[2] - cb - ct], r);
        translate([ct, ct, s[2] - 0.01]) rbox([s[0] - 2*ct, s[1] - 2*ct, 0.01], r - ct);
    }
}
module crect(c, s, h, r = 1) {
    translate([c[0]-s[0]/2, c[1]-s[1]/2, 0]) rbox([s[0], s[1], h], r);
}
module slot(len, w, h) {
    hull() for (y = [-len/2 + w/2, len/2 - w/2]) translate([0, y, 0]) cylinder(d = w, h = h);
}

// Body = side profile (Y-Z) extruded across the width, intersected with the
// rounded plan outline. The profile is concave (thin keyboard section, then
// a sloped step up to the full-depth screen section), which hull() can't do.
module profile2d(zf) {   // 2D coords: x = device height (Y), y = depth (Z)
    polygon([[0, D_top - D_bot], [ye, D_top - D_bot], [ys, 0], [H, 0], [H, zf], [0, zf]]);
}
module across_width(w) { multmatrix([[0,0,1,0],[1,0,0,0],[0,1,0,0]]) linear_extrude(w) children(); }
module body_outer() {
    intersection() {
        across_width(W) profile2d(D_top);
        crbox([W, H, D_top], corner_r, ct = edge_ch);
    }
}
module body_inner() {
    intersection() {
        translate([-1, 0, 0]) across_width(W + 2) offset(delta = -floor_t) profile2d(D_top + 20);
        translate([wall, wall, -1]) rbox([W - 2*wall, H - 2*wall, D_top + 30], corner_r - wall);
    }
}

// ---------------- tub ----------------
module vent_band(y0) { for (i = [0:5]) translate([0, y0 + i*4.5, 0]) children(); }

module tub() {
    difference() {
        intersection() {
            union() {
                difference() { body_outer(); body_inner(); }
                for (b = bosses)
                    translate([b[0], b[1], 0]) cylinder(r = boss_r, h = split_z);
                for (b = mid_bosses)
                    translate([b[0], b[1], 0]) cylinder(r = mid_boss_r, h = split_z);
                // corner guides for the Pi/UPS stack
                for (sx = [0, 1], sy = [0, 1])
                    translate([W/2 + (sx ? 1 : -1)*(stack[0]/2 + gap),
                               st_cy + (sy ? 1 : -1)*(stack[1]/2 + gap), floor_t])
                        mirror([sx, 0, 0]) mirror([0, sy, 0])
                            translate([-1.6, -1.6, 0]) difference() {
                                cube([10, 10, 8]);
                                translate([1.6, 1.6, -1]) cube([10, 10, 10]);
                            }
                // rails that hold the keyboard up against the bezel (with foam tape)
                // (split in the middle so the CardKB cable can pass up to the Pi)
                for (dy = [-kb[1]/2 + 4, kb[1]/2 - 4], sx = [-1, 1])
                    translate([W/2 + (sx < 0 ? -kb[0]/2 + 6 : 9), kb_cy + dy - 1.5, 0])
                        cube([kb[0]/2 - 15, 3, D_top - D_bot + floor_t + kb_rail_h]);
            }
            body_outer();
        }
        body_outer_clip_top();
        for (b = all_bosses) translate([b[0], b[1], split_z - 6]) cylinder(d = insert_d, h = 7);
        // side vents at the stack: intake low, exhaust high
        for (x = [-1, W - wall - 1]) for (band = [st_y1 + 4, st_y1 + stack[1] - 30])
            vent_band(band) translate([x, 0, floor_t + 22])
                rotate([0, 90, 0]) translate([-14, 0, 0]) cube([28, 2.2, wall + 2]);
        // top-edge exhaust
        for (i = [-5:5]) translate([W/2 + i*5, H - wall - 1, floor_t + 24])
            rotate([-90, 0, 0]) slot(28, 2.2, wall + 2);
        // X1202 charge ports, right wall
        translate([W - wall - 1, st_cy + usbc_y_off, floor_t + port_z])
            rotate([0, 90, 0]) hull() for (dy = [-3.1, 3.1])
                translate([0, dy, 0]) cylinder(d = 3.8, h = wall + 2);
        translate([W - wall - 1, st_cy + dc_y_off, floor_t + port_z])
            rotate([0, 90, 0]) cylinder(d = 9, h = wall + 2);
        // snap windows for the bezel's bottom tongues
        for (sx = [-1, 1]) translate([W/2 + sx*25 - 5, -1, split_z - 2.4]) cube([10, wall + 2, 1.4]);
        // rear engraving on the flat back behind the screen, read from behind
        for (i = [0 : len(back_text) - 1])
            translate([W/2, (ys + H)/2 + 18 - i*7.5, -0.01]) mirror([1, 0, 0])
                linear_extrude(0.7) text(back_text[i][0], size = back_text[i][1],
                    halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        for (fx = [16, W - 16], fy = [ys + 12, H - 14])
            translate([fx, fy, -0.01]) cylinder(d = 10.4, h = 1.0);
    }
    lanyard_tab();
}
module body_outer_clip_top() { translate([-50, -50, split_z]) cube([W + 100, H + 100, 100]); }
module lanyard_tab() {
    difference() {
        translate([W - 32, -7, D_top - D_bot]) rbox([16, 7 + corner_r, D_bot - bezel_depth], 3);
        translate([W - 34, -3.5, D_top - D_bot + (D_bot - bezel_depth)/2])
            rotate([0, 90, 0]) cylinder(d = 3.6, h = 20);
    }
}

// ---------------- bezel ----------------
module bezel() {
    difference() {
        union() {
            intersection() {
                union() {
                    difference() {
                        translate([0, 0, split_z]) crbox([W, H, bezel_depth], corner_r, ct = edge_ch);
                        translate([wall, wall, split_z - 1])
                            rbox([W-2*wall, H-2*wall, skirt + 1], corner_r - wall);
                    }
                    for (b = all_bosses) translate([b[0], b[1], split_z]) cylinder(r = boss_r, h = bezel_depth);
                    for (p = posts) translate([p[0], p[1], face_z - eink_glass[2] - eink_pcb[2]])
                        cylinder(r = post_r, h = eink_glass[2] + eink_pcb[2] + 0.01);
                }
                body_outer();
            }
            // alignment lip into the tub
            difference() {
                translate([wall + 0.3, wall + 0.3, split_z - 3])
                    rbox([W-2*wall-0.6, H-2*wall-0.6, 3], corner_r - wall);
                translate([wall + 1.5, wall + 1.5, split_z - 4])
                    rbox([W-2*wall-3, H-2*wall-3, 5], corner_r - wall - 1.2);
                for (b = all_bosses) translate([b[0], b[1], split_z - 4]) cylinder(r = boss_r + 0.5, h = 5);
            }
            // bottom tongues with snap bumps (bezel hooks in at the bottom, screws at the top)
            for (sx = [-1, 1]) translate([W/2 + sx*25 - 5, wall + 0.3, split_z - 3]) {
                cube([10, 1.4, 3]);
                translate([0, -0.6, 0.6]) cube([10, 0.6, 1.2]);
            }
            if (rivets) rivet_ring();
        }
        for (b = all_bosses) {
            translate([b[0], b[1], split_z - 5]) cylinder(d = screw_d, h = bezel_depth + 10);
            translate([b[0], b[1], D_top - 2]) cylinder(d = head_d, h = 3);
        }
        for (p = posts) translate([p[0], p[1], face_z - 6]) cylinder(d = post_hole, h = 6);
        // screen window, chamfered toward the viewer
        translate([W/2 + eink_view_off[0], ek_cy + eink_view_off[1], face_z - 0.01]) hull() {
            crect([0, 0], [eink_view[0] + 1, eink_view[1] + 1], 0.01, 1);
            translate([0, 0, bezel_t]) crect([0, 0], [eink_view[0] + 1 + 2*bezel_t, eink_view[1] + 1 + 2*bezel_t], 0.02, 2);
        }
        // keyboard opening + shallow front recess so the keys sit near flush
        translate([0, 0, face_z - 1]) crect([W/2, kb_cy], [kb[0] - 2*kb_lip, kb[1] - 2*kb_lip], bezel_t + 2, 2);
        translate([0, 0, D_top - 1.0]) crect([W/2, kb_cy], [kb[0] + 3, kb[1] + 3], 2, 3);
        // engraved label
        translate([W/2, wall + margin_bot/2 + 0.5, D_top - 0.8])
            linear_extrude(1) text(label, size = 3.8, halign = "center", valign = "center",
                                   font = "Liberation Sans:style=Bold");
    }
}
module rivet_ring() {
    inset = 3.4; n_x = 7; n_y = 11;
    pts = concat(
        [for (i = [0:n_x-1]) [inset + corner_r + i*(W - 2*inset - 2*corner_r)/(n_x-1), inset]],
        [for (i = [0:n_x-1]) [inset + corner_r + i*(W - 2*inset - 2*corner_r)/(n_x-1), H - inset]],
        [for (i = [0:n_y-1]) [inset, inset + corner_r + i*(H - 2*inset - 2*corner_r)/(n_y-1)]],
        [for (i = [0:n_y-1]) [W - inset, inset + corner_r + i*(H - 2*inset - 2*corner_r)/(n_y-1)]]);
    for (p = pts)
        if (min([for (b = all_bosses) norm(p - b)]) > 7)
            translate([p[0], p[1], D_top]) scale([1, 1, 0.6]) sphere(r = 1.2);
}

// ---------------- retainer (screen) ----------------
module retainer() {
    z0 = face_z - eink_glass[2] - eink_pcb[2] - retainer_t;
    translate([0, 0, z0]) difference() {
        union() {
            crect([W/2, ek_cy], [eink_pcb[0] - 0.6, eink_pcb[1] - 0.6], retainer_t, 2);
            for (p = posts) hull() {
                translate([p[0], p[1], 0]) cylinder(r = post_r + 1.5, h = retainer_t);
                translate([p[0], ek_cy + (p[1] > ek_cy ? 1 : -1) * (eink_pcb[1]/2 - 4), 0])
                    cylinder(r = post_r + 1.5, h = retainer_t);
            }
        }
        translate([0, 0, -1]) crect([W/2, ek_cy], [eink_pcb[0] - 8, eink_pcb[1] - 8], retainer_t + 2, 2);
        for (p = posts) translate([p[0], p[1], -1]) cylinder(d = 2.4, h = retainer_t + 2);
    }
}

// ---------------- ghost components (viewer only) ----------------
module ghost_stack() {
    translate([W/2 - stack[0]/2, st_y1, floor_t]) {
        for (i = [0:3]) translate([10 + i*21, 10, 9.5])                  // 4x 18650 under the X1202
            rotate([-90, 0, 0]) cylinder(d = 18.5, h = 65.3);
        translate([0, 0, 20]) cube([stack[0], stack[1], 1.6]);             // X1202 PCB
        translate([(stack[0] - 85)/2, (stack[1] - 56)/2, 30]) {
            cube([85, 56, 1.6]);                                           // Pi 5
            translate([85/2 - 20, 56/2 - 20, 1.6]) cube([40, 40, stack[2] - 32 - 1.6]);  // cooler
        }
    }
}
module ghost_eink() {
    translate([W/2 - eink_pcb[0]/2, ek_cy - eink_pcb[1]/2, face_z - eink_glass[2] - eink_pcb[2]]) {
        cube(eink_pcb);
        translate([(eink_pcb[0] - eink_glass[0])/2, (eink_pcb[1] - eink_glass[1])/2, eink_pcb[2]])
            cube(eink_glass);
    }
}
module ghost_kb() {
    translate([W/2 - kb[0]/2, kb_cy - kb[1]/2, face_z - kb[2]]) cube(kb);
}

// ---------------- dispatch ----------------
if (part == "tub") tub();
else if (part == "bezel") bezel();
else if (part == "retainer") retainer();
else if (part == "ghost_stack") ghost_stack();
else if (part == "ghost_eink") ghost_eink();
else if (part == "ghost_kb") ghost_kb();
else {
    color("#3b3b3b") tub();
    color("#b08d57") bezel();
    color("#666") retainer();
    color("#4a7", 0.6) ghost_stack();
    color("#eee") ghost_eink();
    color("#333") ghost_kb();
}
