// enclosure.scad — handheld enclosure for the offline survival reference device
//
// Layout (device held upright, front face toward you):
//   top:    Waveshare 4.2" e-Paper Module V2 (400x300)
//   bottom: M5Stack CardKB v1.1 keyboard
//   behind the screen only: Geekworm X1202 UPS + 4x 18650 (toward the
//           screen) with the Raspberry Pi 5 + active cooler on top of it,
//           facing the BACK wall
//
// v0.4 airflow: the Pi faces the back so its cooler fan (which draws air in
// through its top) breathes through a porthole grille in the back wall.
// The battery pack sits between the Pi and the e-paper panel as a heat
// shield. Cool air enters the porthole and the low side vents; hot air
// rises out of the upper side louvers and the top-edge vents. Standoff feet
// keep the porthole clear when the device lies on its back.
//
// Printed parts:
//   tub      — rear shell: stack guides, porthole intake, vents, charge ports
//   bezel    — front cap: screen window, keyboard opening, nameplates
//   retainer — ring that clamps the screen against the bezel
//   trim     — brass gear ring for the porthole (print in brass-colour, glue on)
//   pipes    — copper pipe runs for both sides, flat-backed (print in copper, glue on)
//
// Render one part:  openscad -D 'part="tub"' -o tub.stl enclosure.scad
//
// Sizes marked VERIFY are not in any datasheet — measure the real parts with
// calipers before sending anything to a print service.

part = "assembly"; // tub | bezel | retainer | trim | pipes | ghost_stack | ghost_eink | ghost_kb | assembly

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
kb_lip = 1.5;
kb_foam = 1.0;

// Geekworm X1202: PCB 97.4 x 85 mm. Stack height (cells + X1202 + Pi 5 +
// active cooler) is not published; Geekworm's own case is 62.8 mm tall
// outside, so this is an estimate below that — VERIFY.
stack = [97.4, 85.0, 48.0];
fan_gap    = 2.0;          // air gap between the cooler's fan and the back wall
cooler_off = [0, 0];       // fan centre relative to stack centre (seen from behind) — VERIFY
grille_d   = 36;           // porthole intake diameter (Pi 5 active cooler fan ≈ 30 mm)

// X1202 charge ports on the right-hand wall. The X1202 is now the front
// board of the stack, so its edge ports sit ~27-31 mm above the floor — VERIFY
usbc_y_off = 20;
dc_y_off   = -20;
port_z     = 29;

// ---------------- shell ----------------
wall      = 2.2;
floor_t   = 2.2;
bezel_t   = 2.0;
skirt     = 3.0;
gap       = 0.8;
corner_r  = 7;
edge_ch   = 1.6;
margin_top = 10;
margin_bot = 12;
divider   = 9;
taper_len = 26;
kb_rail_h = 1.0;
retainer_t = 1.6;
boss_r    = 4.0;
mid_boss_r = 3.6;
insert_d  = 4.0;   // M3 heat-set insert (short, 4 mm)
screw_d   = 3.4;
head_d    = 6.2;
post_r    = 2.5;
post_hole = 1.8;   // M2 self-tapping
feet_h    = 4.0;   // standoff feet on the back keep the porthole breathing
deco_h    = 0.8;   // height of raised bead frames / nameplates
pipe_r    = 2.6;   // decorative copper pipes on the sides
pipe_z_hi = 40;    // pipe height (depth) along the thick section, clear of vents and ports
rivets    = true;
label     = "OFFLINE SURVIVAL REFERENCE";
top_label = "FIELD REFERENCE  MK I";
back_top  = [["OFFLINE SURVIVAL REFERENCE", 4.2],
             ["CHARGE: USB-C 5V 5A  |  DC 6-18V", 2.9]];
back_bot  = [["REFERENCE AID - NOT A SOLE AUTHORITY", 2.7],
             ["FOR MEDICAL DOSING, STRUCTURAL", 2.7],
             ["OR ELECTRICAL DECISIONS", 2.7]];

// ---------------- derived ----------------
screen_layer = eink_glass[2] + eink_pcb[2] + eink_back_clear;
D_top = floor_t + fan_gap + stack[2] + 1 + screen_layer + bezel_t;
D_bot = floor_t + kb_rail_h + kb_foam + kb[2] + bezel_t + 0.2;
bezel_depth = bezel_t + skirt;
split_z = D_top - bezel_depth;
face_z  = D_top - bezel_t;

inner_w = max(eink_pcb[0], stack[0], kb[0]) + 2*gap;
inner_h = margin_bot + kb[1] + divider + eink_pcb[1] + margin_top + 2*gap;
W = inner_w + 2*wall;
H = inner_h + 2*wall;

kb_cy   = wall + gap + margin_bot + kb[1]/2;
kb_top  = wall + gap + margin_bot + kb[1];
div_cy  = kb_top + divider/2;
ek_cy   = kb_top + divider + eink_pcb[1]/2;
top_cy  = H - wall - gap - margin_top/2;
label_cy = wall + margin_bot/2 - 0.2;

st_y1 = H - wall - gap - margin_top + 1 - stack[1];
st_cy = st_y1 + stack[1]/2;
ys = st_y1 - 1;
ye = ys - taper_len;
fan_c = [W/2 - cooler_off[0], st_cy + cooler_off[1]];   // seen from behind, X is mirrored

bosses     = [[wall+5, H-wall-4.5], [W-wall-5, H-wall-4.5]];
side_free  = (inner_w - kb[0]) / 2;
mid_bosses = [[wall+side_free/2+0.4, kb_top - 8], [W-wall-side_free/2-0.4, kb_top - 8]];
all_bosses = concat(bosses, mid_bosses);
posts = [[W/2-35, top_cy], [W/2+35, top_cy], [W/2-35, div_cy], [W/2+35, div_cy]];

win_outer = [eink_view[0] + 1 + 2*bezel_t, eink_view[1] + 1 + 2*bezel_t];
plate     = [76, 7.6];     // bottom nameplate
top_plate = [58, 6.6];

// pipe path in side view (y, z): down the thick section, 45° elbow down the
// step, then along the thin keyboard section
pipe_z_lo = D_top - D_bot + 3.4;
pipe_path = [[H - 12, pipe_z_hi], [ys - 9.5, pipe_z_hi],
             [ys - 9.5 - (pipe_z_lo - pipe_z_hi), pipe_z_lo], [8, pipe_z_lo]];
pipe_clamps = [[146, pipe_z_hi], [122, pipe_z_hi], [80, pipe_z_hi], [28, pipe_z_lo]];
pipe_orn_y  = 110;  // gauge (left) / valve wheel (right)

vent_z   = floor_t + fan_gap + 8;              // vents level with the cooler
vent_low  = st_y1 + 6;                          // intake band
vent_high = st_y1 + stack[1] - 32;              // exhaust band

echo(str("Outer W x H = ", W, " x ", H, " mm; depth ", D_top, " mm behind screen, ",
         D_bot, " mm at keyboard (+", feet_h, " mm feet)"));

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
module ring_rect(c, outer, inner, h, r = 1.5) {
    difference() {
        crect(c, outer, h, r);
        translate([0, 0, -1]) crect(c, inner, h + 2, r);
    }
}
module rivet(r = 1.2) { scale([1, 1, 0.6]) sphere(r = r); }
module slot(len, w, h) {
    hull() for (y = [-len/2 + w/2, len/2 - w/2]) translate([0, y, 0]) cylinder(d = w, h = h);
}
module gear2d(r_root, r_tip, teeth) {
    union() {
        circle(r = r_root);
        for (i = [0 : teeth - 1]) rotate(i * 360 / teeth)
            polygon([[r_root - 0.5, -2.1], [r_tip, -1.2], [r_tip, 1.2], [r_root - 0.5, 2.1]]);
    }
}

// Body = side profile (Y-Z) extruded across the width, intersected with the
// rounded plan outline (concave profile: hull() can't make it).
module profile2d(zf) {
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
module side_vent_cuts() {
    for (x = [-2, W - wall - 1]) for (band = [vent_low, vent_high])
        vent_band(band) translate([x, 0, vent_z])
            rotate([0, 90, 0]) translate([-8, 0, 0]) cube([16, 2.2, wall + 3]);
}
module top_vent_cuts() {
    for (i = [-5:5]) translate([W/2 + i*5, H - wall - 1, vent_z + 2])
        rotate([-90, 0, 0]) slot(20, 2.2, wall + 3);
}
module porthole_cut() {
    // concentric rings held by six spokes: ~70% open area over the fan
    translate([fan_c[0], fan_c[1], -feet_h - 1]) linear_extrude(floor_t + feet_h + 2)
        difference() {
            circle(d = grille_d);
            for (r = [4.5, 9.5, 14.5]) difference() { circle(r = r + 1.4); circle(r = r); }
            circle(r = 3.2);
            for (a = [0 : 60 : 300]) rotate(a) translate([0, -0.8]) square([grille_d, 1.6]);
        }
}
// raised steampunk details on the outside of the tub
module tub_deco() {
    // framed steam-vent plates around the side louvers, riveted at the corners
    for (side = [0, 1]) for (band = [vent_low, vent_high]) {
        x0 = side == 0 ? -deco_h : W - 0.01;
        translate([x0, band - 4, vent_z - 11]) cube([deco_h + 0.01, 6*4.5 + 3.8, 22]);
        if (rivets) for (dy = [-2, 6*4.5 + 1.8], dz = [-9, 9])
            translate([side == 0 ? -deco_h : W + deco_h, band + dy, vent_z + dz])
                rotate([0, side == 0 ? -90 : 90, 0]) rivet(0.9);
    }
    // top-edge vent plate
    translate([W/2 - 30, H - 0.01, vent_z - 9]) cube([60, deco_h + 0.01, 22]);
    // feet: domed standoffs on the flat back
    for (fx = [14, W - 14], fy = [ys + 10, H - 12])
        translate([fx, fy, 0]) {
            translate([0, 0, -(feet_h - 2)]) cylinder(d = 8, h = feet_h - 2 + 0.01);
            translate([0, 0, -(feet_h - 2)]) scale([1, 1, 0.5]) sphere(d = 8);
        }
    // rivet line around the back plate
    if (rivets) {
        inset = 5.5;
        xs = [for (i = [0:7]) inset + 4 + i*(W - 2*inset - 8)/7];
        ysr = [for (i = [0:6]) ys + inset + i*(H - ys - 2*inset)/6];
        for (p = concat([for (x = xs) [x, ys + inset]], [for (x = xs) [x, H - inset]],
                        [for (y = ysr) [inset, y]], [for (y = ysr) [W - inset, y]]))
            if (min([for (f = [[14, ys + 10], [W - 14, ys + 10], [14, H - 12], [W - 14, H - 12]]) norm(p - f)]) > 7)
                translate([p[0], p[1], 0]) mirror([0, 0, 1]) rivet(1.1);
    }
}
module tub() {
    difference() {
        union() {
            intersection() {
                union() {
                    difference() { body_outer(); body_inner(); }
                    for (b = bosses) translate([b[0], b[1], 0]) cylinder(r = boss_r, h = split_z);
                    for (b = mid_bosses) translate([b[0], b[1], 0]) cylinder(r = mid_boss_r, h = split_z);
                    // corner guides for the stack
                    for (sx = [0, 1], sy = [0, 1])
                        translate([W/2 + (sx ? 1 : -1)*(stack[0]/2 + gap),
                                   st_cy + (sy ? 1 : -1)*(stack[1]/2 + gap), floor_t])
                            mirror([sx, 0, 0]) mirror([0, sy, 0])
                                translate([-1.6, -1.6, 0]) difference() {
                                    cube([10, 10, 8]);
                                    translate([1.6, 1.6, -1]) cube([10, 10, 10]);
                                }
                    // keyboard rails (split in the middle for the CardKB cable)
                    for (dy = [-kb[1]/2 + 4, kb[1]/2 - 4], sx = [-1, 1])
                        translate([W/2 + (sx < 0 ? -kb[0]/2 + 6 : 9), kb_cy + dy - 1.5, 0])
                            cube([kb[0]/2 - 15, 3, D_top - D_bot + floor_t + kb_rail_h]);
                }
                body_outer();
            }
            tub_deco();
            lanyard_tab();
        }
        translate([-50, -50, split_z]) cube([W + 100, H + 100, 100]);
        for (b = all_bosses) translate([b[0], b[1], split_z - 6]) cylinder(d = insert_d, h = 7);
        side_vent_cuts();
        top_vent_cuts();
        porthole_cut();
        // X1202 charge ports, right wall
        translate([W - wall - 2, st_cy + usbc_y_off, floor_t + port_z])
            rotate([0, 90, 0]) hull() for (dy = [-3.1, 3.1])
                translate([0, dy, 0]) cylinder(d = 3.8, h = wall + 4);
        translate([W - wall - 2, st_cy + dc_y_off, floor_t + port_z])
            rotate([0, 90, 0]) cylinder(d = 9, h = wall + 4);
        // snap windows for the bezel's bottom tongues
        for (sx = [-1, 1]) translate([W/2 + sx*25 - 5, -1, split_z - 2.4]) cube([10, wall + 2, 1.4]);
        // rear engraving above and below the porthole, read from behind
        for (i = [0 : len(back_top) - 1])
            translate([W/2, H - 14 - i*6.5, -0.01]) mirror([1, 0, 0])
                linear_extrude(0.7) text(back_top[i][0], size = back_top[i][1],
                    halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        for (i = [0 : len(back_bot) - 1])
            translate([W/2, fan_c[1] - grille_d/2 - 10 - i*4.6, -0.01]) mirror([1, 0, 0])
                linear_extrude(0.7) text(back_bot[i][0], size = back_bot[i][1],
                    halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
}
module lanyard_tab() {
    difference() {
        translate([W - 32, -7, D_top - D_bot]) rbox([16, 7 + corner_r, D_bot - bezel_depth], 3);
        translate([W - 34, -3.5, D_top - D_bot + (D_bot - bezel_depth)/2])
            rotate([0, 90, 0]) cylinder(d = 3.6, h = 20);
    }
}

// ---------------- trim: brass gear ring around the porthole ----------------
module trim() {
    translate([fan_c[0], fan_c[1], -1.2]) difference() {
        union() {
            linear_extrude(1.2) difference() {
                gear2d(grille_d/2 + 5, grille_d/2 + 7.5, 20);
                circle(d = grille_d + 1);
            }
            if (rivets) for (a = [30 : 60 : 330]) rotate(a) translate([grille_d/2 + 3, 0, 0])
                mirror([0, 0, 1]) rivet(1.0);
        }
    }
}


// ---------------- pipes: copper pipe runs on both sides ----------------
// Built for the left wall (outer face at x = 0) and mirrored to the right.
// Each run is a D-profile (flat back glued to the wall) so it prints flat.
module pipe_run(orn) {
    c = 0.35 * pipe_r;                 // centreline sits slightly into the wall
    P = [for (q = pipe_path) [-c, q[0], q[1]]];
    body_h = c + pipe_r + 1.2;          // gauge / valve body height off the wall
    intersection() {
        union() {
            for (i = [0 : len(P) - 2]) hull() {
                translate(P[i]) sphere(r = pipe_r, $fn = 32);
                translate(P[i + 1]) sphere(r = pipe_r, $fn = 32);
            }
            for (i = [1, 2]) translate(P[i]) sphere(r = pipe_r + 0.7, $fn = 32);   // elbow collars
            for (e = [[P[0], [0, 1, 0]], [P[3], [0, -1, 0]]])                        // end flanges
                translate(e[0]) rotate([90, 0, 0]) cylinder(r = pipe_r + 1.4, h = 1.8, center = true, $fn = 32);
            for (k = pipe_clamps) {                                                  // riveted clamps
                translate([-c, k[0], k[1]]) rotate([90, 0, 0])
                    cylinder(r = pipe_r + 0.6, h = 2.4, center = true, $fn = 32);
                translate([-0.8, k[0] - 1.2, k[1] - (pipe_r + 4)]) cube([0.81, 2.4, 2*(pipe_r + 4)]);
                if (rivets) for (dz = [-1, 1])
                    translate([-0.8, k[0], k[1] + dz*(pipe_r + 2.6)]) rotate([0, -90, 0]) rivet(0.8);
            }
            translate([0, pipe_orn_y, pipe_z_hi]) rotate([0, -90, 0]) {
                if (orn == "gauge") {
                    cylinder(r = 7, h = body_h, $fn = 40);
                    translate([0, 0, body_h]) {
                        difference() {
                            cylinder(r = 7, h = 1.2, $fn = 40);
                            translate([0, 0, 0.6]) cylinder(r = 5.8, h = 1, $fn = 40);
                        }
                        for (a = [-120 : 30 : 120]) rotate(a)
                            translate([-0.25, 4.2, 0.5]) cube([0.5, 1.2, 0.5]);
                        rotate(-35) translate([-0.4, 0, 0.5]) cube([0.8, 4.4, 0.6]);   // needle
                        cylinder(r = 0.9, h = 1.3, $fn = 16);
                    }
                } else {
                    cylinder(r = 5, h = body_h, $fn = 6);                                // hex valve body
                    translate([0, 0, body_h]) {
                        difference() {
                            cylinder(r = 6.5, h = 1.4, $fn = 40);
                            translate([0, 0, -1]) cylinder(r = 5.2, h = 4, $fn = 40);
                        }
                        for (a = [0, 60, 120]) rotate(a) translate([-0.6, -6, 0]) cube([1.2, 12, 1.4]);
                        cylinder(r = 1.6, h = 2.2, $fn = 20);
                    }
                }
            }
        }
        translate([-50, -60, -60]) cube([50, H + 120, 200]);   // keep only what's outside the wall
    }
}
module pipes() {
    pipe_run("gauge");
    translate([W, 0, 0]) mirror([1, 0, 0]) pipe_run("valve");
}

// ---------------- bezel ----------------
module bezel_deco() {
    translate([0, 0, D_top - 0.01]) {
        // bead frame around the screen with riveted corner brackets
        ring_rect([W/2, ek_cy], win_outer + [6, 6], win_outer, deco_h + 0.01, 2.5);
        for (sx = [-1, 1], sy = [-1, 1]) {
            c = [W/2 + sx*(win_outer[0]/2 + 3), ek_cy + sy*(win_outer[1]/2 + 3)];
            translate([c[0], c[1], 0]) linear_extrude(deco_h + 0.01)
                polygon([[0, 0], [-sx*11, 0], [0, -sy*11]]);
            if (rivets) translate([c[0] - sx*3, c[1] - sy*3, deco_h]) rivet(1.0);
        }
        // bead frame around the keyboard recess
        ring_rect([W/2, kb_cy], [kb[0] + 6, kb[1] + 6], [kb[0] + 3, kb[1] + 3], deco_h * 0.75 + 0.01, 3);
        // riveted nameplates
        for (pl = [[label_cy, plate], [top_cy, top_plate]]) {
            translate([W/2 - pl[1][0]/2, pl[0] - pl[1][1]/2, 0])
                crbox([pl[1][0], pl[1][1], deco_h + 0.01], 1.5, ct = 0.4);
            if (rivets) for (sx = [-1, 1])
                translate([W/2 + sx*(pl[1][0]/2 - 2.4), pl[0], deco_h]) rivet(0.9);
        }
    }
}
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
            bezel_deco();
            // alignment lip into the tub
            difference() {
                translate([wall + 0.3, wall + 0.3, split_z - 3])
                    rbox([W-2*wall-0.6, H-2*wall-0.6, 3], corner_r - wall);
                translate([wall + 1.5, wall + 1.5, split_z - 4])
                    rbox([W-2*wall-3, H-2*wall-3, 5], corner_r - wall - 1.2);
                for (b = all_bosses) translate([b[0], b[1], split_z - 4]) cylinder(r = boss_r + 0.5, h = 5);
            }
            // bottom tongues with snap bumps
            for (sx = [-1, 1]) translate([W/2 + sx*25 - 5, wall + 0.3, split_z - 3]) {
                cube([10, 1.4, 3]);
                translate([0, -0.6, 0.6]) cube([10, 0.6, 1.2]);
            }
            if (rivets) rivet_ring();
        }
        for (b = all_bosses) {
            translate([b[0], b[1], split_z - 5]) cylinder(d = screw_d, h = bezel_depth + 10);
            translate([b[0], b[1], D_top - 2]) cylinder(d = head_d, h = 4);
        }
        for (p = posts) translate([p[0], p[1], face_z - 6]) cylinder(d = post_hole, h = 6);
        // screen window, chamfered toward the viewer
        translate([W/2 + eink_view_off[0], ek_cy + eink_view_off[1], face_z - 0.01]) hull() {
            crect([0, 0], [eink_view[0] + 1, eink_view[1] + 1], 0.01, 1);
            translate([0, 0, bezel_t]) crect([0, 0], win_outer, 0.02, 2);
        }
        // keyboard opening + shallow front recess
        translate([0, 0, face_z - 1]) crect([W/2, kb_cy], [kb[0] - 2*kb_lip, kb[1] - 2*kb_lip], bezel_t + 2, 2);
        translate([0, 0, D_top - 1.0]) crect([W/2, kb_cy], [kb[0] + 3, kb[1] + 3], 3, 3);
        // nameplate lettering
        translate([W/2, label_cy, D_top + deco_h - 0.6])
            linear_extrude(1) text(label, size = 3.5, halign = "center", valign = "center",
                                   font = "Liberation Sans:style=Bold");
        translate([W/2, top_cy, D_top + deco_h - 0.6])
            linear_extrude(1) text(top_label, size = 3.2, halign = "center", valign = "center",
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
        if (min([for (b = all_bosses) norm(p - b)]) > 7
            && !(abs(p[0] - W/2) < plate[0]/2 + 2 && abs(p[1] - label_cy) < plate[1]/2 + 2)
            && !(abs(p[0] - W/2) < top_plate[0]/2 + 2 && abs(p[1] - top_cy) < top_plate[1]/2 + 2))
            translate([p[0], p[1], D_top]) rivet(1.2);
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
module ghost_stack() {   // flipped: cooler toward the back wall, cells toward the screen
    z0 = floor_t + fan_gap;
    translate([W/2 - stack[0]/2, st_y1, z0]) {
        translate([stack[0]/2 - 20 - cooler_off[0], stack[1]/2 - 20 + cooler_off[1], 0])
            cube([40, 40, 13]);                                            // active cooler
        translate([(stack[0] - 85)/2, (stack[1] - 56)/2, 13]) cube([85, 56, 1.6]);   // Pi 5
        translate([0, 0, 23]) cube([stack[0], stack[1], 1.6]);             // X1202
        for (i = [0:3]) translate([10 + i*21, 10, 24.6 + 9.6])              // 4x 18650
            rotate([-90, 0, 0]) cylinder(d = 18.5, h = 65.3);
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
else if (part == "trim") trim();
else if (part == "pipes") pipes();
else if (part == "ghost_stack") ghost_stack();
else if (part == "ghost_eink") ghost_eink();
else if (part == "ghost_kb") ghost_kb();
else {
    color("#3b3b3b") tub();
    color("#b08d57") bezel();
    color("#b87333") trim();
    color("#c96b3c") pipes();
    color("#666") retainer();
    color("#4a7", 0.6) ghost_stack();
    color("#eee") ghost_eink();
    color("#333") ghost_kb();
}

// Key coordinates for the viewer's airflow overlay (see render.sh)
echo(str("LAYOUT {\"W\":", W, ",\"H\":", H, ",\"D\":", D_top, ",\"fan\":[", fan_c[0], ",", fan_c[1],
         "],\"grille_r\":", grille_d/2, ",\"vent_z\":", vent_z, ",\"vent_low\":", vent_low + 13,
         ",\"vent_high\":", vent_high + 13, ",\"feet\":", feet_h, "}"));
