/*
 * ============================================================================
 * VIGILIS INTELLIGENT HOUSE SYSTEM — ESP32 SMART LIGHTING CONTROLLER
 * Firmware: esp32_smart_lighting.ino
 * Target Board: ESP32 Dev Module / NodeMCU-32S
 * ============================================================================
 * Features:
 *  - WiFi Auto-connect & Reconnection
 *  - Analog Light Sensor (LDR) reading on GPIO 34 (ADC1)
 *  - Smooth Hardware PWM LED Dimming on GPIO 23 (LEDC channel 0, 5kHz, 8-bit)
 *  - Periodic Heartbeat & Sensor Telemetry to Vigilis Backend
 *  - Automatic light adjustment mode vs Manual override from Vigilis App
 * ============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ---------- WIFI CONFIGURATION ----------
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ---------- VIGILIS BACKEND CONFIGURATION ----------
// Replace with your PC's local IP running Node.js backend (e.g. 192.168.1.100)
const char* BACKEND_BASE_URL = "http://192.168.1.100:5000/api";
const char* DEVICE_TOKEN     = "YOUR_HOMEOWNER_JWT_TOKEN"; // or Device Auth Token
const char* HOUSE_ID         = "HOUSE_101";
const char* DEVICE_ID        = "DEV_LIGHT_01";

// ---------- HARDWARE PINOUTS ----------
const int LDR_PIN       = 34; // Analog input ADC1_CH6
const int LED_PWM_PIN   = 23; // PWM Output to MOSFET or LED Driver
const int STATUS_LED    = 2;  // Built-in onboard LED

// ---------- PWM SETTINGS ----------
const int PWM_FREQ       = 5000; // 5 kHz
const int PWM_CHANNEL    = 0;
const int PWM_RESOLUTION = 8;    // 8-bit (0-255)

// ---------- GLOBAL VARIABLES ----------
String lightMode = "AUTO";       // "AUTO" or "MANUAL"
int targetBrightness = 0;        // 0 to 100%
int currentPwmValue = 0;         // 0 to 255
unsigned long lastHeartbeat = 0;
const unsigned long HEARTBEAT_INTERVAL = 3000; // 3 seconds

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n--- [VIGILIS] Starting Smart Lighting Controller ---");

  // Setup pins
  pinMode(LDR_PIN, INPUT);
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);

  // Setup LEDC PWM for smooth dimming
  ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
  ledcAttachPin(LED_PWM_PIN, PWM_CHANNEL);
  ledcWrite(PWM_CHANNEL, 0);

  // Connect to WiFi
  connectToWiFi();
}

void loop() {
  // Ensure WiFi is connected
  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(STATUS_LED, LOW);
    connectToWiFi();
  } else {
    digitalWrite(STATUS_LED, HIGH);
  }

  // Read ambient light from LDR (0 = dark, 4095 = bright)
  int rawLdr = analogRead(LDR_PIN);
  float ambientLux = map(rawLdr, 0, 4095, 0, 1000);

  // Auto-lighting algorithm if in AUTO mode
  if (lightMode == "AUTO") {
    if (rawLdr < 1200) {
      // Dark room -> High brightness
      targetBrightness = map(rawLdr, 0, 1200, 100, 30);
    } else {
      // Bright room -> Turn lights off
      targetBrightness = 0;
    }
  }

  // Apply smooth PWM transition
  int targetPwm = map(targetBrightness, 0, 100, 0, 255);
  if (currentPwmValue != targetPwm) {
    if (currentPwmValue < targetPwm) currentPwmValue += 2;
    else if (currentPwmValue > targetPwm) currentPwmValue -= 2;
    ledcWrite(PWM_CHANNEL, currentPwmValue);
  }

  // Send periodic heartbeat & sync state with backend
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = millis();
    syncWithBackend(ambientLux, targetBrightness);
  }

  delay(20);
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected! IP Address: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi connection failed. Retrying in loop...");
  }
}

void syncWithBackend(float lux, int brightness) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(BACKEND_BASE_URL) + "/devices/heartbeat";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-house-id", HOUSE_ID);
  if (strlen(DEVICE_TOKEN) > 0) {
    http.addHeader("Authorization", String("Bearer ") + DEVICE_TOKEN);
  }

  StaticJsonDocument<256> doc;
  doc["device_identifier"] = DEVICE_ID;
  doc["type"] = "ESP32_LIGHTING";
  doc["ambient_lux"] = lux;
  doc["brightness"] = brightness;
  doc["mode"] = lightMode;

  String requestBody;
  serializeJson(doc, requestBody);

  int httpCode = http.POST(requestBody);
  if (httpCode == 200 || httpCode == 201) {
    String response = http.getString();
    StaticJsonDocument<512> resDoc;
    DeserializationError error = deserializeJson(resDoc, response);
    if (!error && resDoc["success"] == true) {
      if (resDoc["data"]["mode"]) {
        lightMode = resDoc["data"]["mode"].as<String>();
      }
      if (resDoc["data"]["brightness"]) {
        if (lightMode == "MANUAL") {
          targetBrightness = resDoc["data"]["brightness"].as<int>();
        }
      }
    }
  } else {
    Serial.printf("[HTTP] Heartbeat POST failed, code: %d\n", httpCode);
  }

  http.end();
}
