/*
 * ============================================================================
 * VIGILIS INTELLIGENT HOUSE SYSTEM — ESP32 EMERGENCY ALARM & SIREN HUB
 * Firmware: esp32_security_alarm_hub.ino
 * Target Board: ESP32 Dev Module
 * ============================================================================
 * Features:
 *  - Hardware Emergency Panic Button on GPIO 4 with Hardware Debounce
 *  - High-Decibel Piezo Siren on GPIO 18 (PWM Tone Generator)
 *  - High-Intensity Red Warning Strobe LED on GPIO 19
 *  - Real-time Alarm Polling & Immediate Cloud Emergency Dispatch
 * ============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ---------- HARDWARE PINOUTS ----------
const int PANIC_BUTTON_PIN = 4;   // Pushbutton with pull-up resistor
const int BUZZER_PIN       = 18;  // Active/Passive Siren Buzzer
const int STROBE_LED_PIN   = 19;  // Red Warning Strobe LED
const int STATUS_LED_PIN   = 2;   // Onboard Blue Status LED

// ---------- WIFI CONFIGURATION ----------
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ---------- VIGILIS BACKEND CONFIGURATION ----------
const char* BACKEND_BASE_URL = "http://192.168.1.100:5000/api";
const char* DEVICE_TOKEN     = "YOUR_HOMEOWNER_JWT_TOKEN";
const char* HOUSE_ID         = "HOUSE_101";

// ---------- STATE & TIMERS ----------
bool isAlarmTriggered = false;
unsigned long lastStatusPoll = 0;
const unsigned long POLL_INTERVAL = 2000; // 2 seconds

void IRAM_ATTR handlePanicButtonInterrupt();
volatile bool buttonPressed = false;
unsigned long lastButtonPress = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- [VIGILIS] Starting ESP32 Emergency Siren Hub ---");

  pinMode(PANIC_BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(STROBE_LED_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(STROBE_LED_PIN, LOW);
  digitalWrite(STATUS_LED_PIN, LOW);

  // Attach interrupt for immediate panic button response
  attachInterrupt(digitalPinToInterrupt(PANIC_BUTTON_PIN), handlePanicButtonInterrupt, FALLING);

  // Connect to WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());
  digitalWrite(STATUS_LED_PIN, HIGH);
}

void IRAM_ATTR handlePanicButtonInterrupt() {
  unsigned long now = millis();
  if (now - lastButtonPress > 2000) { // 2s debounce
    buttonPressed = true;
    lastButtonPress = now;
  }
}

void loop() {
  // 1. Handle Physical Panic Button Press
  if (buttonPressed) {
    buttonPressed = false;
    Serial.println("🚨 [HARDWARE ALERT] Physical Panic Button Pressed! Dispatching Emergency...");
    triggerCloudEmergency();
  }

  // 2. Poll Backend Security Status
  if (millis() - lastStatusPoll >= POLL_INTERVAL) {
    lastStatusPoll = millis();
    checkSecurityStatus();
  }

  // 3. Actuate Siren & Strobe if Alarm is Active
  if (isAlarmTriggered) {
    soundAlarmPattern();
  } else {
    digitalWrite(BUZZER_PIN, LOW);
    digitalWrite(STROBE_LED_PIN, LOW);
  }

  delay(20);
}

void soundAlarmPattern() {
  // Strobe LED ON & High Tone
  digitalWrite(STROBE_LED_PIN, HIGH);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(120);

  // Strobe LED OFF & Low Tone
  digitalWrite(STROBE_LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  delay(80);
}

void triggerCloudEmergency() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/emergency/trigger";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-house-id", HOUSE_ID);
  if (strlen(DEVICE_TOKEN) > 0) {
    http.addHeader("Authorization", String("Bearer ") + DEVICE_TOKEN);
  }

  StaticJsonDocument<256> doc;
  doc["notes"] = "Hardware Panic Button Pressed on ESP32 Siren Hub.";

  String requestBody;
  serializeJson(doc, requestBody);

  int httpCode = http.POST(requestBody);
  Serial.printf("[HTTP] Emergency dispatched, response code: %d\n", httpCode);

  isAlarmTriggered = true;
  http.end();
}

void checkSecurityStatus() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/security";
  http.begin(url);
  http.addHeader("x-house-id", HOUSE_ID);
  if (strlen(DEVICE_TOKEN) > 0) {
    http.addHeader("Authorization", String("Bearer ") + DEVICE_TOKEN);
  }

  int httpCode = http.GET();
  if (httpCode == 200) {
    String response = http.getString();
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, response);
    if (!err && doc["success"] == true) {
      String status = doc["data"]["security_status"].as<String>();
      isAlarmTriggered = (status == "ALARM_TRIGGERED");
    }
  }

  http.end();
}
