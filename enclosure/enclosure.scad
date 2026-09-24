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
//   plumbing — functional: the pipes are cable conduits (3/8" copper tube,
//              7.9 mm bore). Left "data line": USB + accessory I2C + gauge
//              LED. Right "power line": 6-18 V solar/car input + power
//              button. The gauge is a real RGB status light; the valve wheel
//              is the real power button. All lines end at a junction box
//              under the step, where the external ports are.
//   fittings / manifold / manifold_lid / gauge_face / valve_cap — printed
//              parts for the plumbing (pipes can be real copper + real brass
//              3/8" compression elbows/tees, or printed)
//
// Render one part:  openscad -D 'part="tub"' -o tub.stl enclosure.scad
//
// Sizes marked VERIFY are not in any datasheet — measure the real parts with
// calipers before sending anything to a print service.

part = "assembly"; // tub | bezel | retainer | trim | pipes | fittings | manifold | manifold_lid | gauge_face | valve_cap | ghost_stack | ghost_eink | ghost_kb | assembly

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

// X1202 USB-C charge port on the right-hand wall (the X1202 is the front
// board of the stack, so its edge ports sit ~27-31 mm above the floor) — VERIFY.
// Its DC jack is extended through the power line to the junction box.
usbc_y_off = 20;
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
pipe_od   = 9.53;  // 3/8" soft copper tube
pipe_id   = 7.9;
fit_r     = pipe_od/2 + 1.6;   // fitting body radius (≈ 3/8" compression elbow/tee)
pz        = 42;    // depth of every pipe run: clear of vents (≤23) and the USB-C port (≤33)
px_off    = 5.3;   // pipe centre outside each side wall
gland_x   = 12;    // pipes enter the case through the top face, this far in from each side
top_rise  = 6;     // top loop height above the top face (doubles as a corner roll bar)
tee_y     = 115;   // gauge (left) / power valve (right)
clamp_ys  = [146, 90, 60];
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

bosses     = [[22, H-wall-4.5], [W-22, H-wall-4.5]];   // inboard of the top pipe glands
side_free  = (inner_w - kb[0]) / 2;
mid_bosses = [[wall+side_free/2+0.4, kb_top - 8], [W-wall-side_free/2-0.4, kb_top - 8]];
all_bosses = concat(bosses, mid_bosses);
posts = [[W/2-25.5, top_cy], [W/2+25.5, top_cy], [W/2-35, div_cy], [W/2+35, div_cy]];

win_outer = [eink_view[0] + 1 + 2*bezel_t, eink_view[1] + 1 + 2*bezel_t];
plate     = [76, 7.6];     // bottom nameplate
top_plate = [58, 6.6];

// junction box under the step (behind the thin keyboard section)
man = [18, W - 18, 14, 34, 34, D_top - D_bot];   // x0, x1, y0, y1, z0, z1
man_wall = 1.8;
pipe_bot_y = (man[2] + man[3]) / 2;
// left-side pipe centreline (right side is mirrored)
P_A = [gland_x, H - 2, pz];            // inside the top gland
P_B = [gland_x, H + top_rise, pz];     // elbow
P_C = [-px_off, H + top_rise, pz];     // elbow
P_T = [-px_off, tee_y, pz];            // tee: gauge / valve
P_D = [-px_off, pipe_bot_y, pz];       // elbow
P_E = [man[0] + 5, pipe_bot_y, pz];    // into the junction box
gauge_c = [-px_off - 1.2, tee_y];

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
        // wire glands through the top face for both pipe lines
        for (gx = [gland_x, W - gland_x]) translate([gx, H - wall - 2, pz])
            rotate([-90, 0, 0]) cylinder(d = pipe_id, h = wall + 4);
        // junction-box mounting screws, driven from inside through the thin floor
        for (mx = [W/2 - 18, W/2 + 18]) translate([mx, man[3] - 4, D_top - D_bot - 1]) {
            cylinder(d = 2.9, h = floor_t + 2);
            translate([0, 0, floor_t + 1 - 1.4]) cylinder(d1 = 2.9, d2 = 5.8, h = 1.41);
        }
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


// ---------------- plumbing: pipes that are cable conduits ----------------
// Built for the left side; the right side is the mirror image.
module seg(a, b, r) {
    v = b - a; L = norm(v);
    translate(a) rotate([0, acos(v[2]/L), atan2(v[1], v[0])]) cylinder(r = r, h = L);
}
module tube(a, b) {                 // hollow tube between two centreline points
    u = (b - a) / norm(b - a);
    difference() { seg(a, b, pipe_od/2); seg(a - u, b + u, pipe_id/2); }
}
module hex_nut(p, u) { seg(p + u*(fit_r*0.55), p + u*(fit_r*0.55 + 3.5), fit_r * 1.12, $fn = 6); }
module fitting_at(p, legs) {        // elbow / tee body with compression nuts on each leg
    sphere(r = fit_r, $fn = 32);    // (called already translated to p)
    for (u = legs) hex_nut([0, 0, 0], u);
}
module side_pipes() {
    $fn = 32;
    tube(P_A, P_B); tube(P_B, P_C); tube(P_C, P_T); tube(P_T, P_D); tube(P_D, P_E);
}
module side_fittings(orn) {
    $fn = 32;
    difference() {
        union() {
            translate(P_B) fitting_at(P_B, [[0, -1, 0], [-1, 0, 0]]);
            translate(P_C) fitting_at(P_C, [[1, 0, 0], [0, -1, 0]]);
            translate(P_D) fitting_at(P_D, [[0, 1, 0], [1, 0, 0]]);
            translate(P_T) fitting_at(P_T, [[0, 1, 0], [0, -1, 0], [0, 0, 1]]);
            // top gland: flange on the top face + nut
            translate([gland_x, H - 0.01, pz]) rotate([-90, 0, 0]) {
                cylinder(r = fit_r + 2.2, h = 1.8);
                cylinder(r = fit_r * 1.12, h = 4.5, $fn = 6);
            }
            // pipe clamps along the side wall, riveted to it (kept outside the wall)
            intersection() {
                for (y = clamp_ys) {
                    hull() {
                        seg([-px_off, y - 2, pz], [-px_off, y + 2, pz], pipe_od/2 + 1.6);
                        translate([-0.8, y - 2, pz - pipe_od/2 - 1.6]) cube([0.8, 4, pipe_od + 3.2]);
                    }
                    translate([-0.8, y - 2, pz - pipe_od/2 - 6]) cube([0.8, 4, pipe_od + 12]);
                }
                translate([-50, -60, -60]) cube([50, H + 120, 200]);
            }
            if (rivets) for (y = clamp_ys, dz = [-1, 1])
                translate([-0.8, y, pz + dz*(pipe_od/2 + 4)]) rotate([0, -90, 0]) rivet(0.8);
            // gauge housing (left) / power-valve body (right), facing the front
            translate([gauge_c[0], gauge_c[1], pz]) {
                if (orn == "gauge") {
                    cylinder(r = 6, h = 60.2 - pz, $fn = 40);
                    translate([0, 0, 58.8 - pz]) cylinder(r = 6.3, h = 1.4, $fn = 40);
                } else {
                    cylinder(r = 6, h = 58.4 - pz, $fn = 6);
                }
            }
        }
        // tube sockets through every fitting and clamp (tube OD + 0.15 clearance)
        seg(P_B, P_C, pipe_od/2 + 0.15);  seg(P_C, P_D, pipe_od/2 + 0.15);
        seg(P_D, P_E, pipe_od/2 + 0.15);
        translate([gauge_c[0], gauge_c[1], pz]) {
            cylinder(r = 2, h = 30);
            if (orn == "gauge") {
                translate([0, 0, 60.2 - pz - 9]) cylinder(r = 4.2, h = 10, $fn = 32);   // 5 mm RGB LED
                translate([0, 0, 58.8 - pz]) cylinder(r = 5.9, h = 3, $fn = 40);        // dial seat
            } else {
                translate([-3.15, -3.15, 58.4 - pz - 4.5]) cube([6.3, 6.3, 5]);            // 6x6 tactile switch
            }
        }
        seg(P_A - [0, 5, 0], P_B, pipe_od/2 + 0.15);
    }
}
module pipes()    { side_pipes(); translate([W, 0, 0]) mirror([1, 0, 0]) side_pipes(); }
module fittings() { side_fittings("gauge"); translate([W, 0, 0]) mirror([1, 0, 0]) side_fittings("valve"); }

module gauge_face() {   // print in white/clear: the status LED glows through it
    translate([gauge_c[0], gauge_c[1], 59.0]) difference() {
        cylinder(r = 5.75, h = 1.2, $fn = 40);
        for (a = [-120 : 30 : 120]) rotate(a) translate([-0.25, 3.6, 0.8]) cube([0.5, 1.3, 1]);
        rotate(-35) translate([-0.35, 0, 0.8]) cube([0.7, 3.4, 1]);
    }
}
module valve_cap() {    // press the wheel = Pi 5 power button (switch in the valve body)
    translate([W - gauge_c[0], gauge_c[1], 0]) {
        translate([0, 0, 58.6]) {
            difference() { cylinder(r = 6.5, h = 1.4, $fn = 40); translate([0, 0, -1]) cylinder(r = 5.2, h = 4, $fn = 40); }
            for (a = [0, 60, 120]) rotate(a) translate([-0.6, -6, 0]) cube([1.2, 12, 1.4]);
            cylinder(r = 1.8, h = 1.8, $fn = 20);
        }
        translate([0, 0, 56.6]) cylinder(r = 1.4, h = 2.1, $fn = 20);   // plunger onto the switch
    }
}

// junction box under the step: every line ends here, at the external ports
module manifold() {
    x0 = man[0]; x1 = man[1]; y0 = man[2]; y1 = man[3]; z0 = man[4]; z1 = man[5];
    difference() {
        union() {
            translate([x0, y0, z0]) rbox([x1 - x0, y1 - y0, z1 - z0], 3);
            for (sx = [x0, x1]) translate([sx, pipe_bot_y, pz]) rotate([0, 90, 0])
                cylinder(r = fit_r + 1.2, h = 3, center = true, $fn = 32);          // pipe bosses
        }
        translate([x0 + man_wall, y0 + man_wall, z0 - 1]) rbox([x1 - x0 - 2*man_wall, y1 - y0 - 2*man_wall, z1 - z0 - man_wall + 1], 1.5);
        translate([x0 + 1, y0 + 1, z0 - 0.01]) rbox([x1 - x0 - 2, y1 - y0 - 2, 1.2], 2);   // lid rebate
        for (sx = [x0 - 3, x1 - 7]) translate([sx, pipe_bot_y, pz]) rotate([0, 90, 0])
            cylinder(r = pipe_od/2 + 0.15, h = 10, $fn = 32);                      // pipe sockets
        // external ports on the bottom face
        translate([32, y0 - 1, pz]) rotate([-90, 0, 0]) translate([-4.9, -2.5, 0]) cube([9.8, 5, man_wall + 2]);   // AUX I2C (Grove)
        translate([W/2, y0 - 1, pz]) rotate([-90, 0, 0]) translate([-6.7, -3, 0]) cube([13.4, 6, man_wall + 2]); // USB-A
        translate([W - 32, y0 - 1, pz]) rotate([-90, 0, 0]) cylinder(d = 8.2, h = man_wall + 2, $fn = 32);      // DC 5.5x2.1
        for (mx = [W/2 - 18, W/2 + 18]) translate([mx, y1 - 4, z1 - 6]) cylinder(d = 2.2, h = 7);  // mounting screws
        for (cx = [x0 + 4, x1 - 4], cy = [y0 + 4, y1 - 4]) translate([cx, cy, z0 - 1]) cylinder(d = 1.8, h = 7); // lid screws
    }
    for (cx = [x0 + 4, x1 - 4], cy = [y0 + 4, y1 - 4]) translate([cx, cy, z0 + 1.2])
        difference() { cylinder(r = 2.6, h = z1 - z0 - 1.2 - man_wall); cylinder(d = 1.8, h = 20); }
    for (mx = [W/2 - 18, W/2 + 18]) translate([mx, y1 - 4, z1 - man_wall - 5])
        difference() { cylinder(r = 3, h = 5); cylinder(d = 2.2, h = 6); }
}
module manifold_lid() {
    x0 = man[0]; x1 = man[1]; y0 = man[2]; y1 = man[3]; z0 = man[4];
    difference() {
        translate([x0 + 1.1, y0 + 1.1, z0]) rbox([x1 - x0 - 2.2, y1 - y0 - 2.2, 1.2], 2);
        for (cx = [x0 + 4, x1 - 4], cy = [y0 + 4, y1 - 4]) translate([cx, cy, z0 - 1]) cylinder(d = 2.3, h = 4);
        // labels above each port, read from behind (mirrored)
        for (l = [[32, "AUX I2C"], [W/2, "USB"], [W - 32, "SOLAR 6-18V"]])
            translate([l[0], y0 + 6, z0 - 0.01]) mirror([1, 0, 0]) linear_extrude(0.5)
                text(l[1], size = 2.4, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
    if (rivets) for (cx = [x0 + 4, x1 - 4], cy = [y0 + 4, y1 - 4]) translate([cx, cy, z0]) mirror([0, 0, 1]) rivet(1.3);
}

echo(str("Copper tube centreline lengths per side (subtract your fittings' socket depth): riser ",
         P_B[1] - P_A[1], ", top run ", P_B[0] - P_C[0], ", upper side ", P_C[1] - P_T[1],
         ", lower side ", P_T[1] - P_D[1], ", into box ", P_E[0] - P_D[0], " mm"));

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
else if (part == "fittings") fittings();
else if (part == "manifold") manifold();
else if (part == "manifold_lid") manifold_lid();
else if (part == "gauge_face") gauge_face();
else if (part == "valve_cap") valve_cap();
else if (part == "ghost_stack") ghost_stack();
else if (part == "ghost_eink") ghost_eink();
else if (part == "ghost_kb") ghost_kb();
else {
    color("#3b3b3b") tub();
    color("#b08d57") bezel();
    color("#b87333") trim();
    color("#c96b3c") pipes();
    color("#b08d57") fittings();
    color("#b08d57") manifold();
    color("#b08d57") manifold_lid();
    color("#f4f1e6") gauge_face();
    color("#b08d57") valve_cap();
    color("#666") retainer();
    color("#4a7", 0.6) ghost_stack();
    color("#eee") ghost_eink();
    color("#333") ghost_kb();
}

// Key coordinates for the viewer's airflow overlay (see render.sh)
echo(str("LAYOUT {\"W\":", W, ",\"H\":", H, ",\"D\":", D_top, ",\"fan\":[", fan_c[0], ",", fan_c[1],
         "],\"grille_r\":", grille_d/2, ",\"vent_z\":", vent_z, ",\"vent_low\":", vent_low + 13,
         ",\"vent_high\":", vent_high + 13, ",\"feet\":", feet_h, "}"));
