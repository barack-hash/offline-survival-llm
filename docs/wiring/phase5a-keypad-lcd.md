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

## 2. LCD1602 (4-bit mode) + contrast pot

Put the LCD and the 10K pot on the breadboard. Pot: one outer leg to 5V,
other outer leg to GND, middle (wiper) to LCD VO.

| LCD pin | Goes to |
|---|---|
| 1 VSS | GND |
| 2 VDD | 5V |
| 3 VO  | pot wiper (contrast — turn until text is crisp) |
| 4 RS  | D13 |
| 5 RW  | GND |
| 6 E   | D12 |
| 7-10 D0-D3 | (leave unconnected — 4-bit mode) |
| 11 D4 | D11 |
| 12 D5 | D10 |
| 13 D6 | A0 |
| 14 D7 | A1 |
| 15 A (backlight +) | 5V through 220Ω resistor |
| 16 K (backlight −) | GND |

Power: breadboard + / − rails from Arduino 5V and GND; LCD and pot feed
from the rails.

## 3. Flash + connect

1. Arduino IDE → Library Manager → install "Keypad" (Mark Stanley /
   Alexander Brevig). LiquidCrystal is built in.
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
