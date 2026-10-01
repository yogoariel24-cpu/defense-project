/**
 * ============================================================================
 * VIGILIS INTELLIGENT HOME ACCESS CONTROL & SECURITY SYSTEM
 * ALL-IN-ONE ACCESS CONTROLLER (No LCD Screen)
 * ============================================================================
 * 
 * Target Board: ESP32 Dev Module (WROOM-32 / NodeMCU-32S)
 * 
 * Connected Hardware & EXACT Pinout (UNCHANGED):
 *   -------------------------------------------------------------------------
 *   RC522 RFID Reader:
 *     - SDA / SS : GPIO 5
 *     - SCK      : GPIO 18
 *     - MISO     : GPIO 19
 *     - MOSI     : GPIO 23
 *     - RST      : GPIO 27
 *     - 3.3V     : 3.3V (Do NOT connect to 5V!)
 *     - GND      : GND
 * 
 *   SG90 Servo Motor (Door Actuator):
 *     - Signal   : GPIO 13
 *     - VCC      : 5V (or external 5V supply)
 *     - GND      : Common GND
 * 
 *   Buzzer:
 *     - Signal (+) : GPIO 25
 *     - GND (-)    : GND
 * 
 *   Panic Button (Optional):
 *     - Pin        : GPIO 4 (Active LOW)
 *   -------------------------------------------------------------------------
 *   LCD SCREEN: REMOVED as requested.
 * 
 * Behavior:
 *   - Correct Card Scanned:
 *       -> Motor turns (0 deg -> 90 deg)
 *       -> Door stays open for 5 seconds
 *       -> Motor returns to closed position (0 deg)
 *       -> (Sends event to backend / triggers camera snapshot)
 * 
 *   - Wrong Card Scanned:
 *       -> Buzzer starts sounding alarm
 *       -> Door remains firmly locked
 * ============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// ============================================================================
// CONFIGURATION & PIN DEFINITIONS (Exact Pins Kept)
// ============================================================================
#define RFID_SS_PIN       5
#define RFID_RST_PIN      27
#define SERVO_PIN         13
#define BUZZER_PIN        25
#define PANIC_BUTTON_PIN  4

// Servo Angles & Timing
const int SERVO_CLOSED_ANGLE        = 0;     // Locked position
const int SERVO_OPEN_ANGLE          = 90;    // Open position
const unsigned long DOOR_OPEN_TIME  = 5000;  // 5 seconds open time

// Buzzer Alarm Settings
const int BUZZER_BEEP_DURATION_MS   = 150;   // Duration of single beep pulse
const int BUZZER_ALARM_PULSES       = 4;     // Number of alarm beeps for wrong card

// Master Authorized Card UIDs
// "DD 5A D9 05" is the authorized card that turns the motor!
const String MASTER_AUTHORIZED_CARDS[] = {
  "DD 5A D9 05"
};
const int NUM_MASTER_CARDS = sizeof(MASTER_AUTHORIZED_CARDS) / sizeof(MASTER_AUTHORIZED_CARDS[0]);

#define DEVICE_IDENTIFIER "ESP32_ACCESS_DOOR_01"

// ============================================================================
// HARDWARE INSTANCES & SYSTEM STATE
// ============================================================================
MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);
Servo doorServo;
Preferences prefs;
WebServer server(80);

// Wi-Fi & Backend Credentials
String wifiSsid       = "Vigilis-Secure-WiFi";
String wifiPassword   = "VigilisPassword";
String backendUrl     = "https://defense-project-production.up.railway.app/api";

// Camera IP / URL (if your ESP32-CAM is connected to the same Wi-Fi)
String cameraIp       = "http://192.168.1.100"; // Optional ESP32-CAM endpoint

bool isDoorOpen = false;
unsigned long doorOpenedTimestamp = 0;
unsigned long lastHeartbeat = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000; // 30 seconds

// Panic Button Debounce
bool panicTriggered = false;
unsigned long panicPressTime = 0;

// ============================================================================
// HARDWARE ACTIONS: MOTOR & BUZZER
// ============================================================================

/**
 * Turns the servo motor to open the door (Correct Card)
 */
void openDoor() {
  Serial.println(F(">>> [ACCESS GRANTED] Motor turning to 90 degrees (OPEN)..."));
  doorServo.write(SERVO_OPEN_ANGLE);
  isDoorOpen = true;
  doorOpenedTimestamp = millis();
}

/**
 * Returns the servo motor to 0 degrees to lock the door
 */
void closeDoor() {
  Serial.println(F(">>> [AUTO-LOCK] Motor returning to 0 degrees (LOCKED)..."));
  doorServo.write(SERVO_CLOSED_ANGLE);
  isDoorOpen = false;
}

/**
 * Sounds the buzzer alarm (Wrong Card)
 */
void triggerBuzzerAlarm() {
  Serial.println(F(">>> [ACCESS DENIED] Triggering buzzer alarm!"));
  for (int i = 0; i < BUZZER_ALARM_PULSES; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(BUZZER_BEEP_DURATION_MS);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }
}

/**
 * Short single confirmation beep (Card read success)
 */
void triggerSuccessBeep() {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
}

// ============================================================================
// LOCAL CARD CHECK (Allows immediate offline demo / fallback)
// ============================================================================
bool isLocalAuthorizedCard(String cardUid) {
  for (int i = 0; i < NUM_MASTER_CARDS; i++) {
    if (cardUid.equalsIgnoreCase(MASTER_AUTHORIZED_CARDS[i])) {
      return true;
    }
  }
  return false;
}

// ============================================================================
// CAMERA TRIGGER (Optional snapshot capture)
// ============================================================================
void triggerCameraCapture() {
  if (WiFi.status() != WL_CONNECTED || cameraIp.length() == 0) return;
  
  // Non-blocking quick GET request to camera capture endpoint
  HTTPClient camHttp;
  camHttp.begin(cameraIp + "/capture");
  camHttp.setTimeout(1500);
  int code = camHttp.GET();
  if (code > 0) {
    Serial.printf("📸 Camera snapshot triggered (HTTP %d)\n", code);
  }
  camHttp.end();
}

// ============================================================================
// BACKEND AUTHORIZATION & LOGIC
// ============================================================================
void verifyCard(String cardUid) {
  Serial.print(F("Verifying Card UID: ["));
  Serial.print(cardUid);
  Serial.println(F("]"));

  bool accessGranted = false;

  // 1. Check local master authorized list (Instant acceptance)
  if (isLocalAuthorizedCard(cardUid)) {
    accessGranted = true;
  }

  // 2. Query Backend Online Verification if not already approved
  if (!accessGranted && WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String endpoint = backendUrl + "/iot/access/request";
    http.begin(endpoint);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("x-device-key", "vigilis_iot_secret_key_2026");
    http.setTimeout(4000); // 4-second timeout

    StaticJsonDocument<256> doc;
    doc["cardUid"] = cardUid;
    doc["deviceId"] = DEVICE_IDENTIFIER;

    String requestBody;
    serializeJson(doc, requestBody);

    int httpCode = http.POST(requestBody);

    if (httpCode > 0) {
      String response = http.getString();
      StaticJsonDocument<512> resDoc;
      DeserializationError err = deserializeJson(resDoc, response);

      if (!err) {
        bool authorized = resDoc["authorized"] | false;
        bool granted = resDoc["granted"] | false;

        if (authorized && granted) {
          accessGranted = true;
        }
      }
    }
    http.end();
  }

  // 2. Perform Physical Actions
  if (accessGranted) {
    Serial.println(F("✅ [VERIFIED] Correct Card! Opening door."));
    triggerSuccessBeep();
    openDoor();
    triggerCameraCapture();
  } else {
    Serial.println(F("❌ [UNAUTHORIZED] Wrong Card! Sounding alarm."));
    triggerBuzzerAlarm();
  }
}

// ============================================================================
// HEARTBEAT TELEMETRY
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

  String payload;
  serializeJson(doc, payload);
  http.POST(payload);
  http.end();
}

// ============================================================================
// EMERGENCY PANIC BUTTON
// ============================================================================
void triggerHardwareEmergency() {
  Serial.println(F("\n🚨 [PANIC BUTTON TRIGGERED] Dispatches Police Email & Live GPS!"));
  
  // Pulse alarm
  for (int i = 0; i < 5; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(150);
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
    doc["notes"] = "Physical emergency panic button pressed.";

    String payload;
    serializeJson(doc, payload);
    int httpCode = http.POST(payload);
    if (httpCode > 0) {
      Serial.printf("Emergency dispatched to backend (HTTP %d)\n", httpCode);
    }
    http.end();
  }
}

// ============================================================================
// CAPTIVE PORTAL FOR WI-FI SETUP
// ============================================================================
void setupCaptivePortal() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP("Vigilis-Access-AP", "12345678");

  IPAddress apIP = WiFi.softAPIP();
  Serial.print(F("Wi-Fi Setup Portal started. Connect to 'Vigilis-Access-AP' at http://"));
  Serial.println(apIP);

  server.on("/", HTTP_GET, []() {
    String html = "<!DOCTYPE html><html><head><title>VIGILIS Wi-Fi Setup</title>";
    html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
    html += "<style>body{font-family:sans-serif;background:#0d1117;color:#fff;padding:24px;text-align:center;}";
    html += "input{padding:10px;margin:8px 0;width:90%;max-width:300px;border-radius:6px;border:1px solid #30363d;}";
    html += "button{padding:12px 24px;background:#00d2ff;color:#000;font-weight:bold;border:none;border-radius:6px;cursor:pointer;}";
    html += "</style></head><body><h2>VIGILIS Access Setup</h2>";
    html += "<form method='POST' action='/save'>";
    html += "<input name='ssid' placeholder='Wi-Fi SSID' required><br>";
    html += "<input name='pass' type='password' placeholder='Wi-Fi Password'><br>";
    html += "<input name='backend' placeholder='Backend API URL' value='https://defense-project-production.up.railway.app/api'><br>";
    html += "<input name='cam' placeholder='ESP32-CAM IP (e.g. http://192.168.1.50)'><br>";
    html += "<button type='submit'>Save & Connect</button></form></body></html>";
    server.send(200, "text/html", html);
  });

  server.on("/save", HTTP_POST, []() {
    String ssid = server.arg("ssid");
    String pass = server.arg("pass");
    String bUrl = server.arg("backend");
    String cIp  = server.arg("cam");

    if (ssid.length() > 0) {
      prefs.begin("vigilis", false);
      prefs.putString("ssid", ssid);
      prefs.putString("pass", pass);
      if (bUrl.length() > 0) prefs.putString("backend", bUrl);
      if (cIp.length() > 0)  prefs.putString("cam", cIp);
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
// SYSTEM SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println(F("\n=============================================="));
  Serial.println(F("   VIGILIS ACCESS CONTROLLER INITIALIZING...  "));
  Serial.println(F("=============================================="));

  // 1. Configure Hardware Pins
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  pinMode(PANIC_BUTTON_PIN, INPUT_PULLUP);

  // 2. Servo Setup (Fail-Closed)
  doorServo.attach(SERVO_PIN);
  // Quick Hardware Self-Test on Boot (Tests Buzzer & Servo wiring immediately)
  Serial.println(F("Performing quick hardware self-test..."));
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
  doorServo.write(30);
  delay(250);
  doorServo.write(SERVO_CLOSED_ANGLE);
  Serial.println(F("Hardware self-test complete (Buzzer & Servo active)."));

  // 3. SPI & RC522 RFID Reader Setup
  SPI.begin(); // Uses SCK=18, MISO=19, MOSI=23, SS=5
  rfid.PCD_Init();
  delay(100);
  rfid.PCD_DumpVersionToSerial();
  Serial.println(F("RC522 RFID Reader Initialized & Ready."));

  // 4. Load Saved Wi-Fi Credentials
  prefs.begin("vigilis", true);
  String savedSsid = prefs.getString("ssid", "");
  String savedPass = prefs.getString("pass", "");
  String savedBackend = prefs.getString("backend", "");
  String savedCam = prefs.getString("cam", "");
  prefs.end();

  if (savedSsid.length() > 0) {
    wifiSsid = savedSsid;
    wifiPassword = savedPass;
  }
  if (savedBackend.length() > 0) {
    backendUrl = savedBackend;
  }
  if (savedCam.length() > 0) {
    cameraIp = savedCam;
  }

  // 5. Connect to Wi-Fi
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
    Serial.println(F("\nWi-Fi Connected!"));
    Serial.print(F("IP Address: "));
    Serial.println(WiFi.localIP());
  } else {
    Serial.println(F("\nWi-Fi timeout. Starting Captive Portal mode..."));
    setupCaptivePortal();
  }

  Serial.println(F("\nReady. Scan your RFID card below:"));
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  // Handle AP configuration server if in AP mode (NON-BLOCKING)
  if (WiFi.getMode() == WIFI_AP) {
    server.handleClient();
  }

  // Panic button check (Active LOW)
  bool panicLow = (digitalRead(PANIC_BUTTON_PIN) == LOW);
  if (panicLow && !panicTriggered) {
    panicTriggered = true;
    panicPressTime = millis();
    triggerHardwareEmergency();
  }
  if (!panicLow && panicTriggered && (millis() - panicPressTime >= 500)) {
    panicTriggered = false;
  }

  // Auto-close servo motor after DOOR_OPEN_TIME (5 seconds)
  if (isDoorOpen && (millis() - doorOpenedTimestamp >= DOOR_OPEN_TIME)) {
    closeDoor();
  }

  // Periodic heartbeat diagnostic
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = millis();
    sendHeartbeat();
  }

  // Check for RFID Card
  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  // Extract Card UID
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

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  // Verify Card
  verifyCard(cardUid);
}
