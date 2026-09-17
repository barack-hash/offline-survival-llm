# Phase 5a wiring — 4x4 keypad + LCD1602 on Arduino UNO (LAFVIN kit)

Parts from the LAFVIN Super Starter Kit for UNO R3:
UNO R3, membrane 4x4 keypad, LCD1602 (16-pin parallel), 10K potentiometer,
breadboard, jumper wires, one 220Ω resistor (backlight).

Photograph the finished wiring and save the photo in this folder
(git rule: every hardware phase gets pictures).

## 1. Keypad (8-pin ribbon)

Hold the keypad with the keys facing you, ribbon at the bottom;
ribbon pins are numbered 1..8 left to right.

| Keypad ribbon pin | Meaning | Arduino pin |
|---|---|---|
| 1 | Row 1 (1 2 3 A) | D9 |
| 2 | Row 2 (4 5 6 B) | D8 |
| 3 | Row 3 (7 8 9 C) | D7 |
| 4 | Row 4 (* 0 # D) | D6 |
| 5 | Col 1 (1 4 7 *) | D5 |
| 6 | Col 2 (2 5 8 0) | D4 |
| 7 | Col 3 (3 6 9 #) | D3 |
| 8 | Col 4 (A B C D) | D2 |

(If rows/cols behave swapped or mirrored, don't rewire — tell the build
assistant which keys come out wrong; it's a keymap fix in the sketch.)

## 2. LCD1602 with I2C backpack — 4 wires, no breadboard

The kit's LCD turned out to have an I2C backpack (small board soldered on
the back with 4 pins: GND, VCC, SDA, SCL). That replaces the whole
16-pin parallel wiring, the contrast pot, and the backlight resistor
(contrast is the tiny blue trim screw on the backpack itself).

Use 4 female-to-male jumpers (female end on the backpack pin):

| Backpack pin | Arduino pin |
|---|---|
| GND | GND |
| VCC | 5V |
| SDA | A4 |
| SCL | A5 |

A4/A5 are the UNO's I2C bus — the LCD must be on exactly those two.
If the screen backlights but shows no text: (a) turn the blue trim screw
on the backpack with a small screwdriver until characters appear;
(b) if still blank, the backpack's address is 0x3F — change LCD_ADDR in
keypad_serial.ino.

## 3. Flash + connect

1. Arduino IDE → Library Manager → install "Keypad" (Mark Stanley /
   Alexander Brevig) AND "LiquidCrystal I2C" (Frank de Brabander).
2. Open scripts/keypad_serial.ino, board "Arduino Uno", flash.
3. LCD should say `Survival ref. / Type & press #`. Test typing standalone
   first (multi-tap: 2=abc, *=backspace, A=commit letter, #=send).
4. Plug the Arduino into the Pi via USB. On the Pi: `ls /dev/ttyACM*`.
5. In scripts/main.py set `INPUT_MODE = "serial"` (and SERIAL_PORT if not
   /dev/ttyACM0), run it, type a question on the keypad, press `#`.
   Answer pages appear on the LCD every ~3 s.

## Typing cheat sheet

| Key | Taps |
|---|---|
| 2..9 | letters then the digit (2=a b c 2) |
| 1 | 1 . , ? ! ' |
| 0 | space |
| * | backspace |
| A | commit current letter immediately |
| # | send question |
| B C D | reserved (menus later) |
