/*
  keypad_serial.ino

  Reads a matrix keypad (works with the standard 4x4 keypad in most
  Arduino starter kits) and sends each pressed key over USB-serial to
  the Raspberry Pi, one character at a time. A rotary encoder is also
  read for scrolling/navigation (optional — comment out if you don't
  wire one up yet).

  Wiring (typical 4x4 keypad):
    Keypad pins 1-4 (rows)    -> Arduino pins 9, 8, 7, 6
    Keypad pins 5-8 (columns) -> Arduino pins 5, 4, 3, 2

  Rotary encoder (optional):
    CLK -> pin 10
    DT  -> pin 11
    SW (push-button, optional) -> pin 12

  Requires the "Keypad" library (Library Manager -> search "Keypad" by
  Mark Stanley / Alexander Brevig — this is in most Arduino starter kit
  library bundles already).

  On the Pi side, main_serial_input.py reads whatever this sketch prints.
*/

#include <Keypad.h>

const byte ROWS = 4;
const byte COLS = 4;

// Map physical keys to characters. Customize this layout for your
// steampunk keypad's actual labels/legend.
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

byte rowPins[ROWS] = {9, 8, 7, 6};
byte colPins[COLS] = {5, 4, 3, 2};

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// --- Optional rotary encoder for scrolling/navigation ---
const int ENCODER_CLK = 10;
const int ENCODER_DT = 11;
const int ENCODER_SW = 12;
int lastClkState;

void setup() {
  Serial.begin(9600);

  pinMode(ENCODER_CLK, INPUT);
  pinMode(ENCODER_DT, INPUT);
  pinMode(ENCODER_SW, INPUT_PULLUP);
  lastClkState = digitalRead(ENCODER_CLK);
}

void loop() {
  char key = keypad.getKey();
  if (key) {
    Serial.print(key);   // send the character to the Pi
  }

  // Rotary encoder: send '<' or '>' for scroll direction.
  int clkState = digitalRead(ENCODER_CLK);
  if (clkState != lastClkState) {
    if (digitalRead(ENCODER_DT) != clkState) {
      Serial.print('>');  // clockwise
    } else {
      Serial.print('<');  // counter-clockwise
    }
    lastClkState = clkState;
  }

  // Encoder push (use as Enter/submit)
  if (digitalRead(ENCODER_SW) == LOW) {
    Serial.print('\n');
    delay(300); // simple debounce
  }
}
