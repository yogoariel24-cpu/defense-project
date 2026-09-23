/**
 * ============================================================================
 * VIGILIS HOME SECURITY - ESP32 DUAL RFID ACCESS CONTROL SYSTEM
 * ============================================================================
 * Hardware:
 *   - 1x ESP32 NodeMCU / DevKit Board
 *   - 2x MFRC522 RFID Card Readers (Reader 1: Main Door, Reader 2: Interior/Room)
 *   - 2x Relay Modules / Solenoid Door Locks (Door 1 & Door 2)
 *   - Optional: 1x Buzzer & Status LEDs
 * 
 * Notice:
 *   - PIR Motion Sensor has been completely removed as requested.
 *   - Both RFID readers share the same hardware SPI bus (SCK, MOSI, MISO)
 *     and use separate SS (SDA) and RST pins.
 * ============================================================================
 * 
 * WIRING DIAGRAM:
 * ----------------------------------------------------------------------------
 * Shared SPI Pins (Connect BOTH RFID readers to these same pins on ESP32):
 *   - SCK  (Clock)        -> ESP32 GPIO 18
 *   - MOSI (Master Out)   -> ESP32 GPIO 23
 *   - MISO (Master In)    -> ESP32 GPIO 19
 *   - 3.3V (VCC)          -> ESP32 3.3V (Do NOT use 5V for RC522!)
 *   - GND                 -> ESP32 GND
 * 
 * Reader 1 Dedicated Pins (Front Door / Entrance):
 *   - SDA / SS (Chip Select) -> ESP32 GPIO 5
 *   - RST (Reset)            -> ESP32 GPIO 22
 * 
 * Reader 2 Dedicated Pins (Room Door / Master Bedroom):
 *   - SDA / SS (Chip Select) -> ESP32 GPIO 15
 *   - RST (Reset)            -> ESP32 GPIO 4
 * 
 * Door Actuator Relays:
 *   - Door 1 Relay (Solenoid) -> ESP32 GPIO 25
 *   - Door 2 Relay (Solenoid) -> ESP32 GPIO 26
 * 
 * Optional Feedback:
 *   - Buzzer (+)             -> ESP32 GPIO 14
 *   - Status LED (+)         -> ESP32 GPIO 27
 * ============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

// ============================================================================
// 1. NETWORK & BACKEND CONFIGURATION (Edit these values)
// ============================================================================
const char* WIFI_SSID     = "YOUR_WIFI_NAME";        // Your 2.4GHz WiFi Name
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";    // Your WiFi Password

// Backend URL: If running locally on PC, use your PC's IP address (e.g. 192.168.1.50)
// If deployed on cloud/Railway, use your full domain (e.g. "https://your-app.railway.app")
const char* BACKEND_BASE_URL = "http://192.168.1.50:5000"; 

// Device Authentication Key (must match IOT_DEVICE_SECRET in backend .env)
const char* IOT_SECRET_KEY   = "vigilis_iot_secret_key_2026";

// Device Identifiers registered in Vigilis
const char* DEVICE_ID_READER_1 = "RFID_READER_01"; // Controls Door 1 (e.g. Main Entrance)
const char* DEVICE_ID_READER_2 = "RFID_READER_02"; // Controls Door 2 (e.g. Room/Interior)

// ============================================================================
// 2. HARDWARE PIN DEFINITIONS
// ============================================================================
// RFID Reader 1 Pins
#define RFID1_SS_PIN   5
#define RFID1_RST_PIN  22

// RFID Reader 2 Pins
#define RFID2_SS_PIN   15
#define RFID2_RST_PIN  4

// Door Relays (Active LOW for standard relay modules)
#define RELAY_DOOR1_PIN  25
#define RELAY_DOOR2_PIN  26

// Optional Indicators
#define BUZZER_PIN       14
#define LED_STATUS_PIN   27

// Relay trigger logic (Most relay modules activate on LOW)
#define RELAY_UNLOCK     LOW
#define RELAY_LOCK       HIGH

// ============================================================================
// 3. GLOBAL OBJECTS & STATE TIMERS
// ============================================================================
MFRC522 mfrc522_reader1(RFID1_SS_PIN, RFID1_RST_PIN);
MFRC522 mfrc522_reader2(RFID2_SS_PIN, RFID2_RST_PIN);

unsigned long door1LockTimer = 0;
unsigned long door2LockTimer = 0;
bool isDoor1Unlocked = false;
bool isDoor2Unlocked = false;

unsigned long lastHeartbeatTime = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000; // 30 seconds

// ============================================================================
// 4. HELPER FUNCTIONS
// ============================================================================

// Beep buzzer
void beep(int frequency, int durationMs, int count = 1) {
  for (int i = 0; i < count; i++) {
    tone(BUZZER_PIN, frequency, durationMs);
    delay(durationMs + 50);
  }
}

// Convert byte array UID to formatted hex string (e.g. "A1:B2:C3:D4")
String formatCardUid(byte *buffer, byte bufferSize) {
  String uidStr = "";
  for (byte i = 0; i < bufferSize; i++) {
    if (buffer[i] < 0x10) uidStr += "0";
    uidStr += String(buffer[i], HEX);
    if (i < bufferSize - 1) uidStr += ":";
  }
  uidStr.toUpperCase();
  return uidStr;
}

// Ensure WiFi is connected
void verifyWiFiConnection() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print("\n[WIFI] Connecting to: ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 25) {
    delay(500);
    Serial.print(".");
    digitalWrite(LED_STATUS_PIN, !digitalRead(LED_STATUS_PIN));
    retries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connected successfully!");
    Serial.print("[WIFI] ESP32 IP Address: ");
    Serial.println(WiFi.localIP());
    digitalWrite(LED_STATUS_PIN, HIGH);
    beep(2000, 100);
  } else {
    Serial.println("\n[WIFI] Failed to connect. Will retry automatically.");
    digitalWrite(LED_STATUS_PIN, LOW);
  }
}

// Send RFID access attempt to Vigilis backend
void sendRfidAccessAttempt(const char* deviceId, String cardUid, int relayPin, int doorNumber) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] Cannot verify card: WiFi is offline!");
    beep(500, 300, 2);
    return;
  }

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/api/iot/access/rfid";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-device-key", IOT_SECRET_KEY);

  // Prepare JSON Request Payload
  StaticJsonDocument<256> reqDoc;
  reqDoc["device_identifier"] = deviceId;
  reqDoc["card_uid"] = cardUid;

  String reqBody;
  serializeJson(reqDoc, reqBody);

  Serial.println("\n--------------------------------------------------");
  Serial.print("[RFID SCAN] Reader: ");
  Serial.print(deviceId);
  Serial.print(" | Card UID: ");
  Serial.println(cardUid);
  Serial.print("[HTTP] Sending verification to: ");
  Serial.println(url);

  int httpCode = http.POST(reqBody);

  if (httpCode > 0) {
    String responseString = http.getString();
    Serial.print("[HTTP Response ");
    Serial.print(httpCode);
    Serial.print("]: ");
    Serial.println(responseString);

    StaticJsonDocument<512> resDoc;
    DeserializationError error = deserializeJson(resDoc, responseString);

    if (!error) {
      bool granted = resDoc["granted"] | false;
      bool doorUnlocked = resDoc["door_unlocked"] | false;
      int durationSeconds = resDoc["unlock_duration_seconds"] | 5;
      const char* message = resDoc["message"] | "";

      if (granted && doorUnlocked) {
        Serial.print("✅ ACCESS GRANTED! Unlocking Door #");
        Serial.print(doorNumber);
        Serial.print(" for ");
        Serial.print(durationSeconds);
        Serial.println(" seconds.");
        Serial.println(message);

        // Unlock the specific door relay
        digitalWrite(relayPin, RELAY_UNLOCK);
        
        if (doorNumber == 1) {
          isDoor1Unlocked = true;
          door1LockTimer = millis() + ((unsigned long)durationSeconds * 1000);
        } else {
          isDoor2Unlocked = true;
          door2LockTimer = millis() + ((unsigned long)durationSeconds * 1000);
        }

        // Positive feedback tone (Two high chimes)
        beep(1800, 80);
        delay(60);
        beep(2400, 120);

      } else {
        const char* reason = resDoc["reason"] | "Unauthorized";
        Serial.print("❌ ACCESS DENIED at Door #");
        Serial.print(doorNumber);
        Serial.print(". Reason: ");
        Serial.println(reason);

        // Keep relay locked
        digitalWrite(relayPin, RELAY_LOCK);

        // Negative feedback tone (Three low buzzes)
        beep(400, 150, 3);
      }
    } else {
      Serial.println("[ERROR] Failed to parse backend JSON response.");
      beep(600, 200, 2);
    }
  } else {
    Serial.print("[HTTP ERROR] Failed to connect to server: ");
    Serial.println(http.errorToString(httpCode).c_str());
    beep(500, 250, 2);
  }

  http.end();
  Serial.println("--------------------------------------------------");
}

// Send periodic heartbeat to backend
void sendHeartbeat(const char* deviceId) {
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
  doc["firmware_version"] = "v2.0-esp32-dual-rfid";

  String requestBody;
  serializeJson(doc, requestBody);

  int httpCode = http.POST(requestBody);
  http.end();
}

// ============================================================================
// 5. ARDUINO SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n==================================================");
  Serial.println("🛡️  VIGILIS ESP32 DUAL RFID CONTROLLER STARTING...");
  Serial.println("==================================================");

  // Initialize Relay outputs (Ensure doors start locked)
  pinMode(RELAY_DOOR1_PIN, OUTPUT);
  pinMode(RELAY_DOOR2_PIN, OUTPUT);
  digitalWrite(RELAY_DOOR1_PIN, RELAY_LOCK);
  digitalWrite(RELAY_DOOR2_PIN, RELAY_LOCK);

  // Initialize Indicators
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_STATUS_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_STATUS_PIN, LOW);

  // Initialize SPI bus
  SPI.begin();

  // Initialize RFID Reader 1 (Front Door)
  mfrc522_reader1.PCD_Init();
  delay(50);
  mfrc522_reader1.PCD_DumpVersionToSerial();
  Serial.println("✅ RFID Reader 1 initialized on SS Pin " + String(RFID1_SS_PIN));

  // Initialize RFID Reader 2 (Room Door)
  mfrc522_reader2.PCD_Init();
  delay(50);
  mfrc522_reader2.PCD_DumpVersionToSerial();
  Serial.println("✅ RFID Reader 2 initialized on SS Pin " + String(RFID2_SS_PIN));

  // Connect to WiFi
  verifyWiFiConnection();

  Serial.println("🚀 System Ready! Scan card on Reader 1 or Reader 2.\n");
}

// ============================================================================
// 6. ARDUINO MAIN LOOP
// ============================================================================
void loop() {
  // 1. Maintain WiFi Connection
  if (WiFi.status() != WL_CONNECTED) {
    verifyWiFiConnection();
  }

  // 2. Check and enforce automatic re-locking of Door 1
  if (isDoor1Unlocked && millis() >= door1LockTimer) {
    digitalWrite(RELAY_DOOR1_PIN, RELAY_LOCK);
    isDoor1Unlocked = false;
    Serial.println("🔒 Door #1 automatically re-locked.");
    beep(1000, 80);
  }

  // 3. Check and enforce automatic re-locking of Door 2
  if (isDoor2Unlocked && millis() >= door2LockTimer) {
    digitalWrite(RELAY_DOOR2_PIN, RELAY_LOCK);
    isDoor2Unlocked = false;
    Serial.println("🔒 Door #2 automatically re-locked.");
    beep(1000, 80);
  }

  // 4. SCAN RFID READER 1 (Front Door)
  if (mfrc522_reader1.PICC_IsNewCardPresent() && mfrc522_reader1.PICC_ReadCardSerial()) {
    String cardUid = formatCardUid(mfrc522_reader1.uid.uidByte, mfrc522_reader1.uid.size);
    sendRfidAccessAttempt(DEVICE_ID_READER_1, cardUid, RELAY_DOOR1_PIN, 1);
    
    // Stop encryption and halt reader to prevent duplicate scans
    mfrc522_reader1.PICC_HaltA();
    mfrc522_reader1.PCD_StopCrypto1();
    delay(500);
  }

  // 5. SCAN RFID READER 2 (Room Door)
  if (mfrc522_reader2.PICC_IsNewCardPresent() && mfrc522_reader2.PICC_ReadCardSerial()) {
    String cardUid = formatCardUid(mfrc522_reader2.uid.uidByte, mfrc522_reader2.uid.size);
    sendRfidAccessAttempt(DEVICE_ID_READER_2, cardUid, RELAY_DOOR2_PIN, 2);

    // Stop encryption and halt reader to prevent duplicate scans
    mfrc522_reader2.PICC_HaltA();
    mfrc522_reader2.PCD_StopCrypto1();
    delay(500);
  }

  // 6. Periodic Heartbeat for both devices (keeps devices active in Vigilis)
  if (millis() - lastHeartbeatTime >= HEARTBEAT_INTERVAL) {
    lastHeartbeatTime = millis();
    sendHeartbeat(DEVICE_ID_READER_1);
    sendHeartbeat(DEVICE_ID_READER_2);
  }

  delay(50); // Small loop delay for CPU stability
}
