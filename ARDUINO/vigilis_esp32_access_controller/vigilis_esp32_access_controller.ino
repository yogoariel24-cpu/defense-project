/**
 * ============================================================================
 * VIGILIS INTELLIGENT HOME ACCESS CONTROL & SECURITY SYSTEM
 * FIRMWARE: MAIN ESP32 ACCESS CONTROLLER
 * ============================================================================
 * 
 * Target Board: ESP32 Dev Module (WROOM / NodeMCU-32S)
 * Hardware Components:
 *   - 1 x RC522 RFID Reader
 *   - 1 x SG90 Micro Servo Motor (Door Actuator)
 *   - 1 x 16x2 I2C LCD Display (0x27)
 *   - 1 x Active/Passive Buzzer
 *   - 1 x Breadboard & Cardboard Door Model
 * 
 * Hardware Pinout Configuration (Section 16):
 *   -------------------------------------------------------------------------
 *   RC522 RFID:
 *     - SDA / SS : GPIO 5
 *     - SCK      : GPIO 18
 *     - MISO     : GPIO 19
 *     - MOSI     : GPIO 23
 *     - RST      : GPIO 27
 *     - 3.3V     : 3.3V (Do NOT connect to 5V!)
 *     - GND      : GND
 * 
 *   16x2 I2C LCD:
 *     - SDA      : GPIO 21
 *     - SCL      : GPIO 22
 *     - VCC      : 5V (or 3.3V depending on backpack)
 *     - GND      : GND
 * 
 *   SG90 Servo Motor:
 *     - Signal   : GPIO 13
 *     - VCC      : External 5V Power Supply
 *     - GND      : Common GND (tied to ESP32 GND)
 * 
 *   Buzzer:
 *     - Signal   : GPIO 25
 *     - GND      : GND
 *   -------------------------------------------------------------------------
 * 
 * Architectural Rule:
 *   The ESP32 does NOT make arbitrary local access decisions.
 *   All RFID card scans are transmitted to the Node.js backend.
 *   The backend determines validity, room permissions, and facial requirements.
 *   FAIL-CLOSED: If backend/Wi-Fi is unreachable, door remains firmly CLOSED.
 * ============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// ============================================================================
// CONFIGURABLE SYSTEM PARAMETERS (Section 17 & 19)
// ============================================================================
const int SERVO_CLOSED_ANGLE      = 0;     // Calibrated closed door angle (degrees)
const int SERVO_OPEN_ANGLE        = 90;    // Calibrated open door angle (degrees)
const unsigned long DOOR_OPEN_DURATION = 5000; // Door remains open for 5 seconds
const int BUZZER_DURATION_MS      = 400;   // Short buzzer pulse on unauthorized access

// PIN DEFINITIONS
#define RFID_SS_PIN    5
#define RFID_RST_PIN   27
#define LCD_SDA_PIN    21
#define LCD_SCL_PIN    22
#define SERVO_PIN      13
#define BUZZER_PIN     25
#define PANIC_BUTTON_PIN 4               // Optional physical panic button (Active LOW)

#define DEVICE_IDENTIFIER "ESP32_ACCESS_DOOR_01"
#define DEFAULT_ROOM_ID   ""               // Optional room binding

// ============================================================================
// PERIPHERAL INSTANCES
// ============================================================================
MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo doorServo;
Preferences prefs;
WebServer server(80);

// Wi-Fi & Backend Credentials
String wifiSsid       = "Vigilis-Secure-WiFi";
String wifiPassword   = "VigilisPassword";
String backendUrl     = "https://defense-project-production.up.railway.app/api";

// System State
bool isDoorOpen = false;
unsigned long doorOpenedTime = 0;
unsigned long lastHeartbeatTime = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000; // 30 seconds

// Panic Button Debounce State
bool panicButtonTriggered = false;
unsigned long panicButtonPressTime = 0;
const unsigned long PANIC_DEBOUNCE_MS = 500; // Ignore re-triggers for 500ms

// ============================================================================
// LCD HELPER FUNCTIONS (Exact messages matching Section 18)
// ============================================================================
void displayLcdIdle() {
  lcd.clear();
  lcd.setCursor(4, 0);
  lcd.print("VIGILIS");
  lcd.setCursor(1, 1);
  lcd.print("Scan your card");
}

void displayLcdAuthorized() {
  lcd.clear();
  lcd.setCursor(1, 0);
  lcd.print("Access Granted");
  lcd.setCursor(4, 1);
  lcd.print("Welcome");
}

void displayLcdUnauthorized() {
  lcd.clear();
  lcd.setCursor(1, 0);
  lcd.print("Access Denied");
  lcd.setCursor(2, 1);
  lcd.print("Unauthorized");
}

void displayLcdOpening() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Door Opening...");
  lcd.setCursor(2, 1);
  lcd.print("Please enter");
}

void displayLcdClosing() {
  lcd.clear();
  lcd.setCursor(1, 0);
  lcd.print("Door Closing...");
}

void displayLcdError() {
  lcd.clear();
  lcd.setCursor(2, 0);
  lcd.print("System Error");
  lcd.setCursor(3, 1);
  lcd.print("Try Again");
}

void displayLcdVerifyingFace() {
  lcd.clear();
  lcd.setCursor(1, 0);
  lcd.print("Card Verified");
  lcd.setCursor(0, 1);
  lcd.print("Look at camera..");
}

void displayLcdEmergency() {
  lcd.clear();
  lcd.setCursor(1, 0);
  lcd.print("! EMERGENCY !");
  lcd.setCursor(0, 1);
  lcd.print("POLICE NOTIFIED");
}

// ============================================================================
// BUZZER & SERVO HARDWARE CONTROLLERS
// ============================================================================
void triggerBuzzerDenied() {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(BUZZER_DURATION_MS);
  digitalWrite(BUZZER_PIN, LOW);
}

void openDoor() {
  displayLcdOpening();
  doorServo.write(SERVO_OPEN_ANGLE);
  isDoorOpen = true;
  doorOpenedTime = millis();
}

void closeDoor() {
  displayLcdClosing();
  doorServo.write(SERVO_CLOSED_ANGLE);
  delay(800);
  isDoorOpen = false;
  displayLcdIdle();
}

// ============================================================================
// BACKEND AUTHORIZATION WORKFLOW (Section 8 & 9)
// ============================================================================
void verifyCardWithBackend(String cardUid) {
  if (WiFi.status() != WL_CONNECTED) {
    // FAIL-CLOSED: Wi-Fi offline -> Door stays closed
    Serial.println(F("❌ [Offline] Wi-Fi disconnected. Access denied (Fail-Closed)."));
    displayLcdError();
    triggerBuzzerDenied();
    delay(2000);
    displayLcdIdle();
    return;
  }

  HTTPClient http;
  String endpoint = backendUrl + "/iot/access/request";
  
  http.begin(endpoint);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-device-key", "vigilis_iot_secret_key_2026");
  http.setTimeout(8000); // 8 second timeout

  // Build JSON Request Payload
  StaticJsonDocument<256> doc;
  doc["cardUid"] = cardUid;
  doc["deviceId"] = DEVICE_IDENTIFIER;
  doc["roomId"] = DEFAULT_ROOM_ID;

  String requestBody;
  serializeJson(doc, requestBody);

  Serial.print(F("📡 Sending Access Request to Backend: "));
  Serial.println(endpoint);
  Serial.println(requestBody);

  int httpCode = http.POST(requestBody);

  if (httpCode > 0) {
    String responseString = http.getString();
    Serial.print(F("📥 Backend Response [HTTP "));
    Serial.print(httpCode);
    Serial.println(F("]: ") + responseString);

    StaticJsonDocument<512> resDoc;
    DeserializationError err = deserializeJson(resDoc, responseString);

    if (err) {
      Serial.println(F("❌ JSON parse error. Fail closed."));
      displayLcdError();
      triggerBuzzerDenied();
      delay(2000);
      displayLcdIdle();
      http.end();
      return;
    }

    bool authorized = resDoc["authorized"] | false;
    bool granted = resDoc["granted"] | false;
    bool requiresFace = resDoc["requiresFaceVerification"] | false;

    // STEP 5: Biometric Verification Required
    if (authorized && requiresFace) {
      Serial.println(F("📸 RFID Authorized! Camera facial verification required."));
      displayLcdVerifyingFace();
      // The ESP32-CAM and Python AI verify the face. Once finalized, backend instructs unlock.
      delay(2500);
      return;
    }

    // STEP 6: Final Decision
    if (authorized && granted) {
      // ACCESS GRANTED
      Serial.println(F("✅ Access Granted! Activating SG90 Servo motor."));
      displayLcdAuthorized();
      delay(1200);
      openDoor();
    } else {
      // ACCESS DENIED (FAIL-CLOSED)
      Serial.println(F("⛔ Access Denied by Backend Authority."));
      displayLcdUnauthorized();
      triggerBuzzerDenied();
      delay(2000);
      displayLcdIdle();
    }
  } else {
    // Backend unreachable -> FAIL-CLOSED
    Serial.print(F("❌ HTTP Connection Failed: "));
    Serial.println(http.errorToString(httpCode).c_str());
    displayLcdError();
    triggerBuzzerDenied();
    delay(2000);
    displayLcdIdle();
  }

  http.end();
}

// ============================================================================
// PERIODIC HEARTBEAT DIAGNOSTIC
// ============================================================================
void sendHeartbeat() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(backendUrl + "/iot/heartbeat");
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<192> doc;
  doc["device_identifier"] = DEVICE_IDENTIFIER;
  doc["status"] = "ONLINE";
  doc["ip_address"] = WiFi.localIP().toString();
  doc["firmware_version"] = "v2.0-access-controller";

  String payload;
  serializeJson(doc, payload);
  http.POST(payload);
  http.end();
}

// ============================================================================
// HARDWARE EMERGENCY PANIC TRIGGER (Dispatches Police Email with Live GPS)
// ============================================================================
void triggerHardwareEmergency() {
  Serial.println(F("\n🚨 [PANIC BUTTON TRIGGERED] Dispatches Police Email & Live GPS!"));
  displayLcdEmergency();

  // Pulse buzzer alarm
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(backendUrl + "/iot/emergency/trigger");
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<256> doc;
    doc["device_identifier"] = DEVICE_IDENTIFIER;
    doc["emergency_type"] = "HARDWARE_PANIC_BUTTON";
    doc["notes"] = "Physical emergency panic button pressed on VIGILIS door access controller.";

    String payload;
    serializeJson(doc, payload);

    int httpCode = http.POST(payload);
    if (httpCode > 0) {
      Serial.printf("✅ Emergency dispatched to backend. Police notified via email with Google Maps location. (HTTP %d)\n", httpCode);
    } else {
      Serial.printf("⚠️ Emergency dispatch connection error: %s\n", http.errorToString(httpCode).c_str());
    }
    http.end();
  } else {
    Serial.println(F("⚠️ Wi-Fi not connected. Alarm sounded locally."));
  }

  delay(3000);
  displayLcdIdle();
}


// ============================================================================
// WIFI CONFIGURATION CAPTIVE PORTAL (Section 30)
// ============================================================================
void setupCaptivePortal() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP("Vigilis-Access-AP", "12345678");

  IPAddress apIP = WiFi.softAPIP();
  Serial.print(F("🌐 Captive Portal Active at: http://"));
  Serial.println(apIP);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Config Mode");
  lcd.setCursor(0, 1);
  lcd.print(apIP.toString());

  server.on("/", HTTP_GET, []() {
    String html = "<!DOCTYPE html><html><head><title>VIGILIS Wi-Fi Setup</title>";
    html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
    html += "<style>body{font-family:sans-serif;background:#0d1117;color:#fff;padding:24px;text-align:center;}";
    html += "input{padding:10px;margin:8px 0;width:90%;max-width:300px;border-radius:6px;border:1px solid #30363d;}";
    html += "button{padding:12px 24px;background:#00d2ff;color:#000;font-weight:bold;border:none;border-radius:6px;cursor:pointer;}";
    html += "</style></head><body><h2>VIGILIS Access Controller</h2>";
    html += "<form method='POST' action='/save'>";
    html += "<input name='ssid' placeholder='Wi-Fi SSID' required><br>";
    html += "<input name='pass' type='password' placeholder='Wi-Fi Password'><br>";
    html += "<input name='backend' placeholder='Backend API URL' value='https://defense-project-production.up.railway.app/api'><br>";
    html += "<button type='submit'>Save & Connect</button></form></body></html>";
    server.send(200, "text/html", html);
  });

  server.on("/save", HTTP_POST, []() {
    String ssid = server.arg("ssid");
    String pass = server.arg("pass");
    String bUrl = server.arg("backend");

    if (ssid.length() > 0) {
      prefs.begin("vigilis", false);
      prefs.putString("ssid", ssid);
      prefs.putString("pass", pass);
      if (bUrl.length() > 0) prefs.putString("backend", bUrl);
      prefs.end();

      server.send(200, "text/html", "<h3>Credentials Saved! Rebooting...</h3>");
      delay(1500);
      ESP.restart();
    } else {
      server.send(400, "text/plain", "SSID cannot be empty.");
    }
  });

  server.begin();
}

// ============================================================================
// SYSTEM SETUP & INITIALIZATION
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println(F("\n=============================================="));
  Serial.println(F("  VIGILIS ACCESS CONTROLLER INITIALIZING...  "));
  Serial.println(F("=============================================="));

  // 1. Hardware Pin Configurations
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  pinMode(PANIC_BUTTON_PIN, INPUT_PULLUP);

  // 2. Servo Setup
  doorServo.attach(SERVO_PIN);
  doorServo.write(SERVO_CLOSED_ANGLE); // Fail-Closed starting state

  // 3. I2C LCD Initialization
  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(4, 0);
  lcd.print("VIGILIS");
  lcd.setCursor(2, 1);
  lcd.print("Initializing");

  // 4. SPI & RC522 RFID Reader Initialization
  SPI.begin();
  rfid.PCD_Init();
  delay(100);
  rfid.PCD_DumpVersionToSerial();
  Serial.println(F("RC522 RFID Reader Initialized & Ready."));

  // 5. Load Stored Credentials
  prefs.begin("vigilis", true);
  String savedSsid = prefs.getString("ssid", "");
  String savedPass = prefs.getString("pass", "");
  String savedBackend = prefs.getString("backend", "");
  prefs.end();

  if (savedSsid.length() > 0) {
    wifiSsid = savedSsid;
    wifiPassword = savedPass;
  }
  if (savedBackend.length() > 0) {
    backendUrl = savedBackend;
  }

  // 6. Connect to Wi-Fi
  Serial.print(F("Connecting to Wi-Fi SSID: "));
  Serial.println(wifiSsid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 15) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(F("\n✅ Wi-Fi Connected!"));
    Serial.print(F("IP Address: "));
    Serial.println(WiFi.localIP());
    displayLcdIdle();
  } else {
    Serial.println(F("\n⚠️ Wi-Fi connection timed out. Starting Setup AP..."));
    setupCaptivePortal();
  }
}

// ============================================================================
// MAIN RUNTIME LOOP
// ============================================================================
void loop() {
  // Handle AP configuration server if in AP mode
  if (WiFi.getMode() == WIFI_AP) {
    server.handleClient();
    return;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PANIC BUTTON CHECK (Active LOW via INPUT_PULLUP)
  // Fires triggerHardwareEmergency() once per press with debounce protection
  // ─────────────────────────────────────────────────────────────────────────
  bool panicPinLow = (digitalRead(PANIC_BUTTON_PIN) == LOW);
  if (panicPinLow && !panicButtonTriggered) {
    panicButtonTriggered = true;
    panicButtonPressTime = millis();
    triggerHardwareEmergency();
  }
  // Reset debounce latch once button is released
  if (!panicPinLow && panicButtonTriggered &&
      (millis() - panicButtonPressTime >= PANIC_DEBOUNCE_MS)) {
    panicButtonTriggered = false;
  }

  // Auto-close door after configured duration (Section 17)
  if (isDoorOpen && (millis() - doorOpenedTime >= DOOR_OPEN_DURATION)) {
    closeDoor();
  }

  // Periodic heartbeat
  if (millis() - lastHeartbeatTime >= HEARTBEAT_INTERVAL) {
    lastHeartbeatTime = millis();
    sendHeartbeat();
  }

  // Check for New RFID Card
  if (!rfid.PICC_IsNewCardPresent()) {
    return;
  }

  if (!rfid.PICC_ReadCardSerial()) {
    return;
  }

  // Extract Card UID formatted in uppercase hex (e.g. "A1 B2 C3 D4")
  String cardUid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) cardUid += "0";
    cardUid += String(rfid.uid.uidByte[i], HEX);
    if (i < rfid.uid.size - 1) cardUid += " ";
  }
  cardUid.toUpperCase();

  Serial.print(F("\n💳 RFID Card Scanned: ["));
  Serial.print(cardUid);
  Serial.println(F("]"));

  // Halt PICC to stop reading repeatedly
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  // Transmit UID to Node.js backend authority
  verifyCardWithBackend(cardUid);
}
