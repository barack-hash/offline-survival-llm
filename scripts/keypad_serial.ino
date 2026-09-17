/*
  keypad_serial.ino — multi-tap text entry + LCD1602 feedback

  Hardware (LAFVIN Super Starter Kit for UNO R3):
    - UNO R3
    - 4x4 membrane keypad ("Membrane Switch Module", 8-pin ribbon)
    - LCD1602 (parallel, 16 pins) + 10K potentiometer for contrast
    - Breadboard + jumper wires

  Typing works like an old phone (multi-tap):
    2=abc2  3=def3  4=ghi4  5=jkl5  6=mno6  7=pqrs7  8=tuv8  9=wxyz9
    1 = 1 . , ? ! '        0 = space
    * = backspace          # = SEND question to the Pi
    A = commit current letter now (instead of waiting for the timeout)
    B/C/D = reserved for menus later
  A letter commits automatically after LETTER_TIMEOUT_MS, or when you
  press a different key.

  The whole question is buffered here and shown on the LCD as you type.
  Only when you press '#' is the finished line (+ '\n') sent to the Pi,
  so the Pi never sees backspaces or half-finished multi-taps.

  The Pi sends the answer back over the same serial link in short
  pre-paced pages (see main.py); each incoming line is simply shown
  across the LCD's two rows. Keep pages <= 32 chars on the Pi side.

  Wiring:
    Keypad ribbon pins 1-8 (left to right, keys facing you):
      1-4 (rows R1-R4)  -> D9, D8, D7, D6
      5-8 (cols C1-C4)  -> D5, D4, D3, D2
    LCD1602 with I2C backpack (4 female-to-male jumpers, no breadboard):
      GND -> Arduino GND     VCC -> Arduino 5V
      SDA -> Arduino A4      SCL -> Arduino A5

  Libraries (IDE -> Manage Libraries):
    - "Keypad" by Mark Stanley / Alexander Brevig
    - "LiquidCrystal I2C" by Frank de Brabander
  If the LCD stays blank but backlights, the backpack may use address
  0x3F instead of 0x27 — change LCD_ADDR below.
*/

#include <Keypad.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ---------- keypad ----------
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};
byte rowPins[ROWS] = {9, 8, 7, 6};
byte colPins[COLS] = {5, 4, 3, 2};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// ---------- LCD via I2C backpack ----------
const byte LCD_ADDR = 0x27;   // try 0x3F if the display stays blank
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);

// ---------- multi-tap state ----------
const char *TAP_MAP[10] = {
  " ",        // 0 -> space
  "1.,?!'",   // 1 -> digit + punctuation
  "abc2", "def3", "ghi4", "jkl5", "mno6", "pqrs7", "tuv8", "wxyz9"
};
const unsigned long LETTER_TIMEOUT_MS = 1000;

char questionBuf[81];        // question being typed (UNO RAM is small)
byte qLen = 0;
char pendingKey = 0;         // digit key currently being tapped
byte pendingTaps = 0;
unsigned long lastTapMs = 0;

// ---------- incoming answer line ----------
char lineBuf[41];
byte lineLen = 0;

void showTyping() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(F("Ask:"));
  // show the tail of the buffer plus the letter in progress
  char preview = pendingKey ? TAP_MAP[pendingKey - '0'][pendingTaps] : 0;
  byte total = qLen + (preview ? 1 : 0);
  byte start = (total > 16) ? total - 16 : 0;
  lcd.setCursor(0, 1);
  for (byte i = start; i < qLen && i < start + 16; i++) lcd.print(questionBuf[i]);
  if (preview && qLen - start < 16) lcd.print(preview);
}

void commitPending() {
  if (!pendingKey) return;
  if (qLen < sizeof(questionBuf) - 1) {
    questionBuf[qLen++] = TAP_MAP[pendingKey - '0'][pendingTaps];
    questionBuf[qLen] = 0;
  }
  pendingKey = 0;
  pendingTaps = 0;
}

void showAnswerLine(const char *s) {
  lcd.clear();
  lcd.setCursor(0, 0);
  for (byte i = 0; s[i] && i < 16; i++) lcd.print(s[i]);
  lcd.setCursor(0, 1);
  for (byte i = 16; s[i] && i < 32; i++) lcd.print(s[i]);
}

void setup() {
  Serial.begin(9600);
  lcd.init();
  lcd.backlight();
  lcd.print(F("Survival ref."));
  lcd.setCursor(0, 1);
  lcd.print(F("Type & press #"));
}

void loop() {
  // auto-commit a letter when the multi-tap window closes
  if (pendingKey && millis() - lastTapMs > LETTER_TIMEOUT_MS) {
    commitPending();
    showTyping();
  }

  char key = keypad.getKey();
  if (key) {
    if (key >= '0' && key <= '9') {
      const char *opts = TAP_MAP[key - '0'];
      if (key == pendingKey) {
        pendingTaps = (pendingTaps + 1) % strlen(opts);   // cycle letters
      } else {
        commitPending();
        pendingKey = key;
        pendingTaps = 0;
        if (strlen(opts) == 1) commitPending();           // '0' = instant space
      }
      lastTapMs = millis();
    } else if (key == 'A') {          // commit letter now
      commitPending();
    } else if (key == '*') {          // backspace
      if (pendingKey) { pendingKey = 0; pendingTaps = 0; }
      else if (qLen > 0) { questionBuf[--qLen] = 0; }
    } else if (key == '#') {          // send to Pi
      commitPending();
      if (qLen > 0) {
        Serial.print(questionBuf);
        Serial.print('\n');
        lcd.clear();
        lcd.print(F("Thinking..."));
        lcd.setCursor(0, 1);
        lcd.print(F("(30-90 sec)"));
        qLen = 0;
        questionBuf[0] = 0;
        return;                       // skip showTyping while waiting
      }
    }
    showTyping();
  }

  // answer pages arriving from the Pi, one line at a time
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n') {
      lineBuf[lineLen] = 0;
      if (lineLen > 0) showAnswerLine(lineBuf);
      lineLen = 0;
    } else if (lineLen < sizeof(lineBuf) - 1) {
      lineBuf[lineLen++] = c;
    }
  }
}
