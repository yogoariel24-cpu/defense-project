/**
 * ============================================================================
 * VIGILIS ALL-IN-ONE SMART HOME IOT FIRMWARE (ESP32)
 * ============================================================================
 * 
 * ONE SINGLE CODE FOR ALL YOUR IOT DEVICES:
 *   1. DUAL RFID ACCESS CONTROL (2x MFRC522 Readers)
 *      - Reader 1: Main Entrance Door (Unlocks Door 1 Solenoid/Relay)
 *      - Reader 2: Interior / Room Door (Unlocks Door 2 Solenoid/Relay)
 *   2. SMART LIGHTING & RELAY CONTROL
 *      - Smart Light Relay Actuator (Remote Mobile App & Automated Control)
 *      - Physical Wall Switch input (Toggles relay & syncs to Mobile App)
 *   3. AMBIENT LIGHT SENSOR (LDR)
 *      - Reads room/outdoor lux and triggers auto-lighting when dark
 *   4. HARDWARE EMERGENCY PANIC BUTTON
 *      - Physical push-button that instantly triggers police/alarm dispatch
 *   5. AUDIO & VISUAL STATUS FEEDBACK
 *      - Buzzer chimes and status LED for access granted/denied/alarms
 * 
 * NOTICE:
 *   - PIR Motion Sensor has been COMPLETELY REMOVED as requested.
 * ============================================================================
 * 
 * COMPLETE WIRING PINOUT FOR ESP32:
 * ----------------------------------------------------------------------------
 * 1. SPI BUS (Connect BOTH MFRC522 RFID readers in parallel to these 3 pins):
 *      - SCK  -> GPIO 18
 *      - MISO -> GPIO 19
 *      - MOSI -> GPIO 23
 *      - VCC  -> 3.3V (IMPORTANT: Never connect RC522 to 5V!)
 *      - GND  -> GND
 * 
 * 2. RFID READER 1 (Main Entrance Door):
 *      - SDA (SS) -> GPIO 5
 *      - RST      -> GPIO 22
 * 
 * 3. RFID READER 2 (Interior / Room Door):
 *      - SDA (SS) -> GPIO 15
 *      - RST      -> GPIO 4
 * 
 * 4. DOOR ACTUATOR RELAYS (Active LOW):
 *      - Door 1 Lock Relay -> GPIO 25
 *      - Door 2 Lock Relay -> GPIO 26
 * 
 * 5. SMART LIGHTING:
 *      - Smart Light Relay -> GPIO 12
 *      - Physical Wall Switch Button -> GPIO 14 (Between GPIO 14 and GND)
 * 
 * 6. AMBIENT LIGHT SENSOR (LDR):
 *      - LDR Analog Input -> GPIO 34 (Analog ADC1)
 * 
 * 7. HARDWARE EMERGENCY PANIC BUTTON:
 *      - Panic Pushbutton -> GPIO 33 (Between GPIO 33 and GND)
 * 
 * 8. STATUS INDICATORS:
 *      - Buzzer (+)       -> GPIO 27
 *      - Status LED (+)   -> GPIO 2 (Or Built-in LED)
 * ============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

// ============================================================================
// 1. CONFIGURATION (Edit your WiFi & Backend Server settings here)
// ============================================================================
const char* WIFI_SSID     = "YOUR_WIFI_NAME";        // 2.4GHz WiFi SSID
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";    // WiFi Password

// Backend URL: 
// Local PC: e.g. "http://192.168.1.50:5000" (replace with your computer IP)
// Cloud/Railway: e.g. "https://your-app.railway.app"
const char* BACKEND_BASE_URL = "http://192.168.1.50:5000";

// IoT Security Key (Must match IOT_DEVICE_SECRET in backend .env)
const char* IOT_SECRET_KEY   = "vigilis_iot_secret_key_2026";

// Device Identifiers in Vigilis Backend
const char* ID_RFID_READER_1 = "RFID_READER_01"; // Door 1
const char* ID_RFID_READER_2 = "RFID_READER_02"; // Door 2
const char* ID_SMART_LIGHT   = "RELAY_LIVING_01"; // Light
const char* ID_LIGHT_SENSOR  = "LUX_SENSOR_01";  // LDR
const char* ID_PANIC_BUTTON  = "PANIC_BTN_01";   // Panic Button

// ============================================================================
// 2. HARDWARE PIN DEFINITIONS
// ============================================================================
// RFID Readers
#define PIN_RFID1_SS       5
#define PIN_RFID1_RST      22
#define PIN_RFID2_SS       15
#define PIN_RFID2_RST      4

// Relays
#define PIN_DOOR1_RELAY    25
#define PIN_DOOR2_RELAY    26
#define PIN_LIGHT_RELAY    12

// Inputs
#define PIN_WALL_SWITCH    14  // Pull-up button to toggle light
#define PIN_PANIC_BUTTON   33  // Pull-up button for emergency
#define PIN_LDR_ANALOG     34  // Analog light sensor

// Indicators
#define PIN_BUZZER         27
#define PIN_STATUS_LED     2

// Relay logic (Most relay modules are active LOW)
#define RELAY_ACTIVE       LOW
#define RELAY_INACTIVE     HIGH

// ============================================================================
// 3. GLOBAL OBJECTS & STATE TIMERS
// ============================================================================
MFRC522 rfid_door1(PIN_RFID1_SS, PIN_RFID1_RST);
MFRC522 rfid_door2(PIN_RFID2_SS, PIN_RFID2_RST);

// Door relocking timers (non-blocking)
unsigned long door1RelockAt = 0;
unsigned long door2RelockAt = 0;
bool isDoor1Open = false;
bool isDoor2Open = false;

// Smart Light state
bool isLightOn = false;
int lastWallSwitchState = HIGH;
unsigned long lastWallSwitchDebounce = 0;

// Panic button state
int lastPanicState = HIGH;
unsigned long lastPanicDebounce = 0;

// Periodic timers
unsigned long lastLdrReadTime = 0;
const unsigned long LDR_INTERVAL = 15000; // Send light reading every 15s

unsigned long lastLightPollTime = 0;
const unsigned long LIGHT_POLL_INTERVAL = 5000; // Poll mobile app light changes every 5s

unsigned long lastHeartbeatTime = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000; // Heartbeat ping every 30s

// ============================================================================
// 4. AUDIO & VISUAL FEEDBACK
// ============================================================================
void beep(int frequency, int durationMs, int repetitions = 1) {
  for (int i = 0; i < repetitions; i++) {
    tone(PIN_BUZZER, frequency, durationMs);
    delay(durationMs + 40);
  }
}

// Format RFID card UID bytes into standard hex string (e.g. "4A:2F:8C:11")
String formatUid(byte *buffer, byte bufferSize) {
  String uid = "";
  for (byte i = 0; i < bufferSize; i++) {
    if (buffer[i] < 0x10) uid += "0";
    uid += String(buffer[i], HEX);
    if (i < bufferSize - 1) uid += ":";
  }
  uid.toUpperCase();
  return uid;
}

// ============================================================================
// 5. WIFI CONNECTION MANAGER
// ============================================================================
void verifyWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print("[WIFI] Connecting to SSID: ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    digitalWrite(PIN_STATUS_LED, !digitalRead(PIN_STATUS_LED));
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connected! IP Address: " + WiFi.localIP().toString());
    digitalWrite(PIN_STATUS_LED, HIGH);
    beep(2200, 100);
  } else {
    Serial.println("\n[WIFI] Connection failed. Running offline loop.");
    digitalWrite(PIN_STATUS_LED, LOW);
  }
}

// ============================================================================
// 6. BACKEND API CALLS
// ============================================================================

// 6.1 Verify RFID Card with Backend
void verifyRfidAccess(const char* deviceId, String cardUid, int relayPin, int doorNumber) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ [RFID] WiFi offline - cannot verify card.");
    beep(400, 200, 2);
    return;
  }

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/access/rfid";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  StaticJsonDocument<256> reqDoc;
  reqDoc["device_identifier"] = deviceId;
  reqDoc["card_uid"] = cardUid;

  String reqBody;
  serializeJson(reqDoc, reqBody);

  Serial.println("\n--------------------------------------------------");
  Serial.println("💳 [RFID SCAN] Door #" + String(doorNumber) + " (" + deviceId + ") | Card UID: " + cardUid);

  int httpCode = http.POST(reqBody);

  if (httpCode > 0) {
    String response = http.getString();
    StaticJsonDocument<512> resDoc;
    DeserializationError err = deserializeJson(resDoc, response);

    if (!err) {
      bool granted = resDoc["granted"] | false;
      bool unlocked = resDoc["door_unlocked"] | false;
      int durationSec = resDoc["unlock_duration_seconds"] | 5;

      if (granted && unlocked) {
        Serial.println("✅ [ACCESS GRANTED] Door #" + String(doorNumber) + " unlocked for " + String(durationSec) + "s!");

        // Unlock Relay
        digitalWrite(relayPin, RELAY_ACTIVE);
        if (doorNumber == 1) {
          isDoor1Open = true;
          door1RelockAt = millis() + ((unsigned long)durationSec * 1000);
        } else {
          isDoor2Open = true;
          door2RelockAt = millis() + ((unsigned long)durationSec * 1000);
        }

        // Happy tone
        beep(1800, 80);
        delay(50);
        beep(2400, 120);
      } else {
        const char* reason = resDoc["reason"] | "Denied";
        Serial.println("❌ [ACCESS DENIED] Door #" + String(doorNumber) + " | Reason: " + String(reason));
        digitalWrite(relayPin, RELAY_INACTIVE);
        beep(350, 150, 3); // Negative tone
      }
    }
  } else {
    Serial.println("⚠️ [HTTP ERROR] Cannot reach backend server.");
    beep(500, 200, 2);
  }

  http.end();
  Serial.println("--------------------------------------------------");
}

// 6.2 Send Ambient Light Sensor Reading (LDR)
void sendLdrTelemetry() {
  if (WiFi.status() != WL_CONNECTED) return;

  // Read analog value (0 - 4095 on ESP32 ADC)
  int rawAdc = analogRead(PIN_LDR_ANALOG);
  // Estimate approximate lux (0 - 1000 lux range)
  float estimatedLux = map(rawAdc, 0, 4095, 0, 1000);

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/sensors/light";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  StaticJsonDocument<256> doc;
  doc["device_identifier"] = ID_LIGHT_SENSOR;
  doc["current_lux"] = estimatedLux;

  String body;
  serializeJson(doc, body);

  int httpCode = http.POST(body);
  if (httpCode > 0) {
    String resp = http.getString();
    StaticJsonDocument<256> resDoc;
    if (!deserializeJson(resDoc, resp)) {
      bool shouldActivate = resDoc["data"]["should_activate_lights"] | false;
      const char* mode = resDoc["data"]["mode"] | "AUTO";

      // If backend AUTO lighting mode says lights should be turned ON:
      if (String(mode) == "AUTO") {
        if (shouldActivate && !isLightOn) {
          isLightOn = true;
          digitalWrite(PIN_LIGHT_RELAY, RELAY_ACTIVE);
          Serial.println("💡 [AUTO LIGHT] Darkness detected. Light turned ON.");
        } else if (!shouldActivate && isLightOn) {
          isLightOn = false;
          digitalWrite(PIN_LIGHT_RELAY, RELAY_INACTIVE);
          Serial.println("💡 [AUTO LIGHT] Daylight sufficient. Light turned OFF.");
        }
      }
    }
  }
  http.end();
}

// 6.3 Synchronize Smart Light State with Backend
void syncLightState(bool newState, const char* source) {
  isLightOn = newState;
  digitalWrite(PIN_LIGHT_RELAY, isLightOn ? RELAY_ACTIVE : RELAY_INACTIVE);
  Serial.println("💡 [LIGHT] Toggled to " + String(isLightOn ? "ON" : "OFF") + " via " + source);

  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/lights/state-sync";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  StaticJsonDocument<256> doc;
  doc["device_identifier"] = ID_SMART_LIGHT;
  doc["is_on"] = isLightOn;
  doc["triggered_by"] = source;

  String body;
  serializeJson(doc, body);
  http.POST(body);
  http.end();
}

// 6.4 Poll Backend for Remote Light State Changes from Flutter App
void pollRemoteLightState() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/lights/" + String(ID_SMART_LIGHT) + "/state";
  http.begin(url);
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  int code = http.GET();
  if (code == 200) {
    String response = http.getString();
    StaticJsonDocument<256> doc;
    if (!deserializeJson(doc, response)) {
      bool remoteIsOn = doc["is_on"] | false;
      if (remoteIsOn != isLightOn) {
        isLightOn = remoteIsOn;
        digitalWrite(PIN_LIGHT_RELAY, isLightOn ? RELAY_ACTIVE : RELAY_INACTIVE);
        Serial.println("📱 [APP REMOTE] Light updated to: " + String(isLightOn ? "ON" : "OFF"));
      }
    }
  }
  http.end();
}

// 6.5 Trigger Emergency Alert from Physical Hardware Button
void triggerEmergencyAlert() {
  Serial.println("\n🚨🚨🚨 [EMERGENCY] HARDWARE PANIC BUTTON PRESSED! 🚨🚨🚨");
  beep(3000, 200, 3); // High alarm beeps

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ [PANIC] WiFi is offline - cannot send emergency alert.");
    return;
  }

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/emergency/trigger";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  StaticJsonDocument<256> doc;
  doc["device_identifier"] = ID_PANIC_BUTTON;
  doc["emergency_type"] = "PANIC_BUTTON";
  doc["notes"] = "Hardware Panic Button pressed on Main Controller Panel!";

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  if (code > 0) {
    Serial.println("🚨 [EMERGENCY DISPATCHED] Emergency contacts and authority notified!");
  }
  http.end();
}

// 6.6 Send Heartbeat Ping to Keep Devices Active in Backend
void sendHeartbeatPing(const char* deviceId) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/heartbeat";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  StaticJsonDocument<256> doc;
  doc["device_identifier"] = deviceId;
  doc["status"] = "ONLINE";
  doc["ip_address"] = WiFi.localIP().toString();
  doc["firmware_version"] = "v3.0-all-in-one";

  String body;
  serializeJson(doc, body);
  http.POST(body);
  http.end();
}

// ============================================================================
// 7. ARDUINO SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n========================================================");
  Serial.println("🛡️  VIGILIS ALL-IN-ONE SMART IOT CONTROLLER STARTING...  ");
  Serial.println("========================================================");

  // Initialize Relays (Ensure doors and lights start in safe state)
  pinMode(PIN_DOOR1_RELAY, OUTPUT);
  pinMode(PIN_DOOR2_RELAY, OUTPUT);
  pinMode(PIN_LIGHT_RELAY, OUTPUT);
  digitalWrite(PIN_DOOR1_RELAY, RELAY_INACTIVE); // Door 1 locked
  digitalWrite(PIN_DOOR2_RELAY, RELAY_INACTIVE); // Door 2 locked
  digitalWrite(PIN_LIGHT_RELAY, RELAY_INACTIVE); // Light off

  // Initialize Inputs
  pinMode(PIN_WALL_SWITCH, INPUT_PULLUP);
  pinMode(PIN_PANIC_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LDR_ANALOG, INPUT);

  // Initialize Indicators
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_STATUS_LED, LOW);

  // Initialize Hardware SPI Bus for Dual RFID
  SPI.begin();

  // Initialize RFID Reader 1 (Door 1)
  rfid_door1.PCD_Init();
  delay(40);
  Serial.println("✅ RFID Reader #1 (Door 1) initialized on SS Pin " + String(PIN_RFID1_SS));

  // Initialize RFID Reader 2 (Door 2)
  rfid_door2.PCD_Init();
  delay(40);
  Serial.println("✅ RFID Reader #2 (Door 2) initialized on SS Pin " + String(PIN_RFID2_SS));

  // Connect to Home WiFi
  verifyWiFi();

  Serial.println("🚀 System fully operational!\n");
}

// ============================================================================
// 8. ARDUINO MAIN LOOP (Non-Blocking Multi-Device Engine)
// ============================================================================
void loop() {
  // 1. Maintain WiFi Connection
  if (WiFi.status() != WL_CONNECTED) {
    verifyWiFi();
  }

  // 2. Door 1 Auto-Relocking Timer
  if (isDoor1Open && millis() >= door1RelockAt) {
    digitalWrite(PIN_DOOR1_RELAY, RELAY_INACTIVE);
    isDoor1Open = false;
    Serial.println("🔒 Door #1 re-locked.");
    beep(1000, 60);
  }

  // 3. Door 2 Auto-Relocking Timer
  if (isDoor2Open && millis() >= door2RelockAt) {
    digitalWrite(PIN_DOOR2_RELAY, RELAY_INACTIVE);
    isDoor2Open = false;
    Serial.println("🔒 Door #2 re-locked.");
    beep(1000, 60);
  }

  // 4. SCAN RFID READER 1 (Door 1 / Main Entrance)
  if (rfid_door1.PICC_IsNewCardPresent() && rfid_door1.PICC_ReadCardSerial()) {
    String uid = formatUid(rfid_door1.uid.uidByte, rfid_door1.uid.size);
    verifyRfidAccess(ID_RFID_READER_1, uid, PIN_DOOR1_RELAY, 1);
    rfid_door1.PICC_HaltA();
    rfid_door1.PCD_StopCrypto1();
    delay(300);
  }

  // 5. SCAN RFID READER 2 (Door 2 / Room Interior)
  if (rfid_door2.PICC_IsNewCardPresent() && rfid_door2.PICC_ReadCardSerial()) {
    String uid = formatUid(rfid_door2.uid.uidByte, rfid_door2.uid.size);
    verifyRfidAccess(ID_RFID_READER_2, uid, PIN_DOOR2_RELAY, 2);
    rfid_door2.PICC_HaltA();
    rfid_door2.PCD_StopCrypto1();
    delay(300);
  }

  // 6. CHECK PHYSICAL WALL SWITCH (Debounced Toggle)
  int wallReading = digitalRead(PIN_WALL_SWITCH);
  if (wallReading != lastWallSwitchState) {
    lastWallSwitchDebounce = millis();
  }
  if ((millis() - lastWallSwitchDebounce) > 50) {
    if (wallReading == LOW && lastWallSwitchState == HIGH) {
      // Toggle light state
      syncLightState(!isLightOn, "PHYSICAL_WALL_SWITCH");
    }
  }
  lastWallSwitchState = wallReading;

  // 7. CHECK HARDWARE EMERGENCY PANIC BUTTON
  int panicReading = digitalRead(PIN_PANIC_BUTTON);
  if (panicReading != lastPanicState) {
    lastPanicDebounce = millis();
  }
  if ((millis() - lastPanicDebounce) > 50) {
    if (panicReading == LOW && lastPanicState == HIGH) {
      triggerEmergencyAlert();
    }
  }
  lastPanicState = panicReading;

  // 8. PERIODIC AMBIENT LIGHT SENSOR TELEMETRY (LDR)
  if (millis() - lastLdrReadTime >= LDR_INTERVAL) {
    lastLdrReadTime = millis();
    sendLdrTelemetry();
  }

  // 9. PERIODIC SYNC WITH MOBILE APP (Check if homeowner tapped light in app)
  if (millis() - lastLightPollTime >= LIGHT_POLL_INTERVAL) {
    lastLightPollTime = millis();
    pollRemoteLightState();
  }

  // 10. PERIODIC HEARTBEAT PING (Keeps all devices green in Vigilis)
  if (millis() - lastHeartbeatTime >= HEARTBEAT_INTERVAL) {
    lastHeartbeatTime = millis();
    sendHeartbeatPing(ID_RFID_READER_1);
    sendHeartbeatPing(ID_RFID_READER_2);
    sendHeartbeatPing(ID_SMART_LIGHT);
  }

  delay(30); // 30ms CPU breather
}
