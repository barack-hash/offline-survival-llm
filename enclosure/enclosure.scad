// enclosure.scad — handheld enclosure for the offline survival reference device
//
// Layout (device held upright, front face toward you):
//   top:    Waveshare 4.2" e-paper module (400x300)
//   bottom: M5Stack CardKB v1.1 keyboard
//   behind: Raspberry Pi 5 + active cooler stacked on a Geekworm X1202
//           UPS board carrying 4x 18650 cells
//
// Printed parts:
//   tub      — rear shell: holds the Pi/UPS stack, vents, charge ports
//   bezel    — front cap: screen window, keyboard opening
//   retainer — plate that clamps screen + keyboard against the bezel
//
// Render one part:  openscad -D 'part="tub"' -o tub.stl enclosure.scad
//
// !! Component sizes marked VERIFY are from datasheets/listings, not
// !! measured parts. Measure the real parts with calipers and update
// !! them before sending anything to a print service.

part = "assembly"; // tub | bezel | retainer | ghost_stack | ghost_eink | ghost_kb | assembly

$fn = 48;

// ---------------- components ----------------
stack    = [97.4, 85.0, 56.0];  // X1202 PCB 97.4x85 (Geekworm wiki); height VERIFY
eink_pcb = [103.0, 78.5, 1.6];  // Waveshare 4.2" module outline — VERIFY
eink_glass = [91.0, 77.0, 1.2]; // glass panel on the PCB front — VERIFY
eink_view  = [84.8, 63.6];      // active area — VERIFY
kb       = [84.0, 54.0, 8.5];   // CardKB 84x54 (listing); thickness VERIFY
kb_lip   = 2.0;                 // bezel overlap on each keyboard edge

// X1202 charge ports on the right-hand wall — positions VERIFY
usbc_y_off = 20;   // from stack centre, along height
dc_y_off   = -20;
port_z     = 6;    // height of port centres above the tub floor

// ---------------- shell ----------------
wall      = 2.4;
floor_t   = 2.4;
bezel_t   = 2.4;
gap       = 0.8;   // clearance around every part
corner_r  = 7;
margin_top = 10;   // room for the top screw bosses above the screen
margin_bot = 13;   // room for the bottom bosses + engraved label
divider   = 8;     // bar between screen and keyboard
retainer_t = 2;
boss_r    = 4.5;
insert_d  = 4.2;   // M3 heat-set insert
screw_d   = 3.4;   // M3 clearance
head_d    = 6.2;   // M3 button-head counterbore
post_r    = 2.5;
post_hole = 1.8;   // M2 self-tapping
rivets    = true;
label     = "OFFLINE SURVIVAL REFERENCE";
edge_ch   = 1.8;   // chamfer on the outer front and back edges
back_text = [      // engraved on the rear shell, read from behind
    ["OFFLINE SURVIVAL REFERENCE", 4.4],
    ["CHARGE: USB-C 5V 5A  |  DC 6-18V", 3.0],
    ["", 3.0],
    ["REFERENCE AID - NOT A SOLE AUTHORITY", 2.8],
    ["FOR MEDICAL DOSING, STRUCTURAL", 2.8],
    ["OR ELECTRICAL DECISIONS", 2.8]];

// ---------------- derived ----------------
inner_w = max(eink_pcb[0], stack[0], kb[0]) + 2*gap;
inner_h = margin_top + eink_pcb[1] + divider + kb[1] + margin_bot + 2*gap;
front_layer = max(kb[2], eink_pcb[2] + eink_glass[2]) + 2;
inner_d = stack[2] + front_layer + retainer_t + 1;

W = inner_w + 2*wall;
H = inner_h + 2*wall;
D = inner_d + floor_t + bezel_t;

bezel_depth = bezel_t + front_layer;
tub_depth   = D - bezel_depth;
face_z      = D - bezel_t;          // underside of the front face

kb_cx  = W/2;
kb_cy  = wall + gap + margin_bot + kb[1]/2;
div_cy = wall + gap + margin_bot + kb[1] + divider/2;
ek_cy  = wall + gap + margin_bot + kb[1] + divider + eink_pcb[1]/2;
top_cy = H - wall - gap - margin_top/2;
st_cy  = H/2;

bosses = [[wall+5, wall+5], [W-wall-5, wall+5],
          [wall+5, H-wall-5], [W-wall-5, H-wall-5]];
side_free = (inner_w - kb[0]) / 2;
posts = [[wall+side_free/2, kb_cy], [W-wall-side_free/2, kb_cy],
         [wall+side_free/2, div_cy], [W-wall-side_free/2, div_cy],
         [W/2-30, top_cy], [W/2+30, top_cy]];

echo(str("Outer size W x H x D = ", W, " x ", H, " x ", D, " mm"));

// ---------------- helpers ----------------
module rbox(s, r) {
    r2 = max(min(r, s[0]/2 - 0.01, s[1]/2 - 0.01), 0.01);
    hull() for (x = [r2, s[0]-r2], y = [r2, s[1]-r2])
        translate([x, y, 0]) cylinder(r = r2, h = s[2]);
}
module crbox(s, r, ct = 0, cb = 0) {   // rbox with chamfered top/bottom edges
    hull() {
        translate([cb, cb, 0]) rbox([s[0] - 2*cb, s[1] - 2*cb, 0.01], r - cb);
        translate([0, 0, cb]) rbox([s[0], s[1], s[2] - cb - ct], r);
        translate([ct, ct, s[2] - 0.01]) rbox([s[0] - 2*ct, s[1] - 2*ct, 0.01], r - ct);
    }
}
module crect(c, s, h, r = 1) {   // rect centred on c=[x,y], from z=0 to h
    translate([c[0]-s[0]/2, c[1]-s[1]/2, 0]) rbox([s[0], s[1], h], r);
}
module slot(len, w, h) {         // rounded slot along Y, extruded along Z
    hull() for (y = [-len/2 + w/2, len/2 - w/2]) translate([0, y, 0]) cylinder(d = w, h = h);
}

// ---------------- tub ----------------
module vent_band(y0) {
    for (i = [0:5]) translate([0, y0 + i*4.5, 0]) children();
}
module tub() {
    difference() {
        union() {
            difference() {
                crbox([W, H, tub_depth], corner_r, cb = edge_ch);
                translate([wall, wall, floor_t])
                    rbox([W-2*wall, H-2*wall, tub_depth], corner_r - wall);
            }
            for (b = bosses) translate([b[0], b[1], 0]) cylinder(r = boss_r, h = tub_depth);
            // corner guides locating the Pi/UPS stack on the floor
            for (sx = [0, 1], sy = [0, 1])
                translate([W/2 + (sx ? 1 : -1)*(stack[0]/2 + gap),
                           st_cy + (sy ? 1 : -1)*(stack[1]/2 + gap), floor_t])
                    mirror([sx, 0, 0]) mirror([0, sy, 0])
                        translate([-1.6, -1.6, 0]) difference() {
                            cube([10, 10, 8]);
                            translate([1.6, 1.6, -1]) cube([10, 10, 10]);
                        }
            lanyard_tab();
        }
        for (b = bosses) translate([b[0], b[1], tub_depth - 8]) cylinder(d = insert_d, h = 9);
        // side vents: intake low, exhaust high (device held upright)
        for (x = [-1, W - wall - 1]) for (band = [wall + 22, H - wall - 50])
            vent_band(band) translate([x, 0, floor_t + 12])
                rotate([0, 90, 0]) translate([-12, 0, 0]) cube([24, 2.2, wall + 2]);
        // grip grooves between the vent bands
        for (x = [-0.01, W - 0.8]) for (y = [wall + 55 : 5 : H - wall - 58])
            translate([x, y - 0.8, 18]) cube([0.81, 1.6, tub_depth - 24]);
        // rear engraving (mirrored so it reads correctly from behind)
        for (i = [0 : len(back_text) - 1])
            translate([W/2, H*0.70 - i*7.5, -0.01]) mirror([1, 0, 0])
                linear_extrude(0.7) text(back_text[i][0], size = back_text[i][1],
                    halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        // pockets for 10 mm stick-on rubber feet
        for (fx = [16, W - 16], fy = [18, H - 18])
            translate([fx, fy, -0.01]) cylinder(d = 10.4, h = 1.0);
        // top-edge exhaust
        for (i = [-5:5]) translate([W/2 + i*5, H - wall - 1, floor_t + 12])
            rotate([-90, 0, 0]) slot(24, 2.2, wall + 2);
        // X1202 charge ports, right wall
        translate([W - wall - 1, st_cy + usbc_y_off, floor_t + port_z])
            rotate([0, 90, 0]) hull() for (dy = [-3.1, 3.1])
                translate([0, dy, 0]) cylinder(d = 3.8, h = wall + 2);
        translate([W - wall - 1, st_cy + dc_y_off, floor_t + port_z])
            rotate([0, 90, 0]) cylinder(d = 9, h = wall + 2);
    }
}
module lanyard_tab() {
    difference() {
        translate([W - 32, -7, 0]) rbox([16, 7 + corner_r, 9], 3);
        translate([W - 34, -3.5, 4.5]) rotate([0, 90, 0]) cylinder(d = 4.2, h = 20);
    }
}

// ---------------- bezel ----------------
module bezel() {
    translate([0, 0, tub_depth]) difference() {
        union() {
            difference() {
                crbox([W, H, bezel_depth], corner_r, ct = edge_ch);
                translate([wall, wall, -1])
                    rbox([W-2*wall, H-2*wall, front_layer + 1], corner_r - wall);
            }
            for (b = bosses) translate([b[0], b[1], 0]) cylinder(r = boss_r, h = bezel_depth);
            for (p = posts) translate([p[0], p[1], 0]) cylinder(r = post_r, h = front_layer);
            // alignment lip sliding into the tub
            difference() {
                translate([wall + 0.3, wall + 0.3, -3])
                    rbox([W-2*wall-0.6, H-2*wall-0.6, 3], corner_r - wall);
                translate([wall + 1.5, wall + 1.5, -4])
                    rbox([W-2*wall-3, H-2*wall-3, 5], corner_r - wall - 1.2);
                for (b = bosses) translate([b[0], b[1], -4]) cylinder(r = boss_r + 0.5, h = 5);
            }
            if (rivets) rivet_ring();
        }
        for (b = bosses) {
            translate([b[0], b[1], -5]) cylinder(d = screw_d, h = bezel_depth + 10);
            translate([b[0], b[1], bezel_depth - 2]) cylinder(d = head_d, h = 3);
        }
        for (p = posts) translate([p[0], p[1], -1]) cylinder(d = post_hole, h = front_layer);
        // screen window, chamfered toward the viewer
        translate([W/2, ek_cy, front_layer - 0.01]) hull() {
            crect([0, 0], [eink_view[0] + 1, eink_view[1] + 1], 0.01, 1);
            translate([0, 0, bezel_t]) crect([0, 0], [eink_view[0] + 1 + 2*bezel_t, eink_view[1] + 1 + 2*bezel_t], 0.02, 2);
        }
        // keyboard: through-opening + shallow front recess so keys sit near flush
        translate([0, 0, front_layer - 1])
            crect([kb_cx, kb_cy], [kb[0] - 2*kb_lip, kb[1] - 2*kb_lip], bezel_t + 2, 2);
        translate([0, 0, bezel_depth - 1.2])
            crect([kb_cx, kb_cy], [kb[0] + 4, kb[1] + 4], 2, 3);
        // engraved label
        translate([W/2, wall + margin_bot/2 + 0.5, bezel_depth - 0.8])
            linear_extrude(1) text(label, size = 4.0, halign = "center", valign = "center",
                                   font = "Liberation Sans:style=Bold");
    }
}
module rivet_ring() {
    inset = 3.6;
    n_x = 7; n_y = 11;
    pts = concat(
        [for (i = [0:n_x-1]) [inset + corner_r + i*(W - 2*inset - 2*corner_r)/(n_x-1), inset]],
        [for (i = [0:n_x-1]) [inset + corner_r + i*(W - 2*inset - 2*corner_r)/(n_x-1), H - inset]],
        [for (i = [0:n_y-1]) [inset, inset + corner_r + i*(H - 2*inset - 2*corner_r)/(n_y-1)]],
        [for (i = [0:n_y-1]) [W - inset, inset + corner_r + i*(H - 2*inset - 2*corner_r)/(n_y-1)]]);
    for (p = pts)
        if (min([for (b = bosses) norm(p - b)]) > 7)
            translate([p[0], p[1], bezel_depth]) scale([1, 1, 0.6]) sphere(r = 1.3);
}

// ---------------- retainer ----------------
module retainer() {
    eink_back = front_layer - eink_pcb[2] - eink_glass[2];  // gap from retainer top to eink back
    kb_back   = front_layer - kb[2];
    translate([0, 0, tub_depth - retainer_t]) difference() {
        union() {
            translate([wall + 2.5, wall + 2.5, 0])
                rbox([W-2*wall-5, H-2*wall-5, retainer_t], corner_r - wall - 2);
            // raised frames that press each part's edges against the bezel
            translate([0, 0, retainer_t]) difference() {
                crect([W/2, ek_cy], [eink_pcb[0] - 1, eink_pcb[1] - 1], eink_back, 2);
                translate([0, 0, -1]) crect([W/2, ek_cy], [eink_pcb[0] - 7, eink_pcb[1] - 7], eink_back + 2, 2);
            }
            translate([0, 0, retainer_t]) difference() {
                crect([kb_cx, kb_cy], [kb[0] - 1, kb[1] - 1], kb_back, 2);
                translate([0, 0, -1]) crect([kb_cx, kb_cy], [kb[0] - 7, kb[1] - 7], kb_back + 2, 2);
                // notch for the CardKB Grove cable on its top edge
                translate([kb_cx - 7, kb_cy + kb[1]/2 - 5, -1]) cube([14, 8, kb_back + 2]);
            }
        }
        // open centres so cables reach the Pi below
        translate([0, 0, -1]) crect([W/2, ek_cy], [eink_pcb[0] - 7, eink_pcb[1] - 7], retainer_t + 2, 2);
        translate([0, 0, -1]) crect([kb_cx, kb_cy], [kb[0] - 7, kb[1] - 7], retainer_t + 2, 2);
        for (p = posts) translate([p[0], p[1], -1]) cylinder(d = 2.4, h = retainer_t + 2);
        for (b = bosses) translate([b[0], b[1], -1]) cylinder(r = boss_r + 0.8, h = retainer_t + 2);
    }
}

// ---------------- ghost components (viewer only) ----------------
module ghost_stack() {
    translate([W/2 - stack[0]/2, st_cy - stack[1]/2, floor_t]) {
        cube([stack[0], stack[1], 3]);                                  // X1202 PCB
        for (i = [0:3]) translate([6 + i*21, 8, 3 + 9.25])              // 4x 18650
            rotate([-90, 0, 0]) cylinder(d = 18.5, h = 65.3);
        translate([(stack[0] - 85)/2, (stack[1] - 56)/2, 26]) {
            cube([85, 56, 1.6]);                                        // Pi 5 PCB
            translate([85/2 - 20, 56/2 - 20, 1.6]) cube([40, 40, 12]);  // active cooler
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
    translate([kb_cx - kb[0]/2, kb_cy - kb[1]/2, face_z - kb[2]]) cube(kb);
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
