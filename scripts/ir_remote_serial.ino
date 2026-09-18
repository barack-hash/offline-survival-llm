/*
  ir_remote_serial.ino — IR remote multi-tap text entry + LCD1602 (I2C)

  Replaces the 4x4 membrane keypad, which shipped defective (internal
  shorts on ribbon lines 1-8 and 4-6 — see BUILD_LOG 2026-09-18).
  Input device: the LAFVIN kit's NEC IR remote (arrows/OK + 1-9,*,0,#).

  Typing (old-phone multi-tap, same scheme as the keypad design):
    2=abc2 3=def3 4=ghi4 5=jkl5 6=mno6 7=pqrs7 8=tuv8 9=wxyz9
    1 = 1 . , ? ! '     0 = space
    * = backspace       # = SEND question to the Pi
    OK = commit the letter in progress immediately
    Arrows = reserved for menus later.
  A letter also commits after LETTER_TIMEOUT_MS or when a different
  button is pressed.

  The full question is buffered here (LCD preview while typing) and one
  finished line + '\n' goes to the Pi on '#'. Answer pages come back
  over serial (paced by main.py) and are shown across both LCD rows.

  Wiring:
    IR receiver (G/R/Y): G->GND, R->5V (or IOREF), Y->D2
    LCD1602 I2C backpack: GND->GND, VCC->5V, SDA->A4, SCL->A5

  Libraries: IRremote (v4+), LiquidCrystal I2C (Frank de Brabander).

  Button codes measured from the actual remote on 2026-09-18
  (NEC protocol, IrReceiver.decodedIRData.command):
*/

#include <IRremote.hpp>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

const int IR_PIN = 2;
const byte LCD_ADDR = 0x27;   // try 0x3F if the display stays blank
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);

// measured NEC command codes -> logical keys
char irToKey(uint8_t cmd) {
  switch (cmd) {
    case 0x16: return '1';
    case 0x19: return '2';
    case 0x0D: return '3';
    case 0x0C: return '4';
    case 0x18: return '5';
    case 0x5E: return '6';
    case 0x08: return '7';
    case 0x1C: return '8';
    case 0x5A: return '9';
    case 0x52: return '0';
    case 0x42: return '*';
    case 0x4A: return '#';
    case 0x40: return 'K';  // OK
    case 0x46: return 'U';  // up
    case 0x15: return 'D';  // down
    case 0x44: return 'L';  // left
    case 0x43: return 'R';  // right
    default:   return 0;
  }
}

// ---------- multi-tap state ----------
const char *TAP_MAP[10] = {
  " ",        // 0 -> space
  "1.,?!'",   // 1 -> digit + punctuation
  "abc2", "def3", "ghi4", "jkl5", "mno6", "pqrs7", "tuv8", "wxyz9"
};
const unsigned long LETTER_TIMEOUT_MS = 1200;

char questionBuf[81];
byte qLen = 0;
char pendingKey = 0;
byte pendingTaps = 0;
unsigned long lastTapMs = 0;

// ---------- incoming answer line ----------
char lineBuf[41];
byte lineLen = 0;

void showTyping() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(F("Ask:"));
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

void handleKey(char key) {
  if (key >= '0' && key <= '9') {
    const char *opts = TAP_MAP[key - '0'];
    if (key == pendingKey) {
      pendingTaps = (pendingTaps + 1) % strlen(opts);
    } else {
      commitPending();
      pendingKey = key;
      pendingTaps = 0;
      if (strlen(opts) == 1) commitPending();  // '0' = instant space
    }
    lastTapMs = millis();
  } else if (key == 'K') {           // OK: commit letter now
    commitPending();
  } else if (key == '*') {           // backspace
    if (pendingKey) { pendingKey = 0; pendingTaps = 0; }
    else if (qLen > 0) { questionBuf[--qLen] = 0; }
  } else if (key == '#') {           // send to Pi
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
      return;                        // keep "Thinking" on screen
    }
  }
  showTyping();
}

void setup() {
  Serial.begin(9600);
  IrReceiver.begin(IR_PIN, ENABLE_LED_FEEDBACK);
  lcd.init();
  lcd.backlight();
  lcd.print(F("Survival ref."));
  lcd.setCursor(0, 1);
  lcd.print(F("Type & press #"));
}

void loop() {
  if (pendingKey && millis() - lastTapMs > LETTER_TIMEOUT_MS) {
    commitPending();
    showTyping();
  }

  if (IrReceiver.decode()) {
    bool isRepeat = IrReceiver.decodedIRData.flags & IRDATA_FLAGS_IS_REPEAT;
    uint8_t cmd = IrReceiver.decodedIRData.command;
    IrReceiver.resume();
    if (!isRepeat) {                 // held button = one press
      char key = irToKey(cmd);
      if (key) handleKey(key);
    }
  }

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
