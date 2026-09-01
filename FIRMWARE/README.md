# 🛠️ Vigilis IoT Hardware & Firmware Documentation

This folder contains the complete, production-ready C++ firmware sketches for the **Vigilis Intelligent House IoT Hardware Ecosystem**.

---

## 📦 IoT Device Nodes Overview

| Node | Firmware Sketch | Target Microcontroller | Sensors & Actuators |
|---|---|---|---|
| **1. Smart Lighting Node** | [`esp32_smart_lighting.ino`](file:///c:/Users/THERESE/Desktop/VIGILIS%20APP/FIRMWARE/esp32_smart_lighting/esp32_smart_lighting.ino) | ESP32 DevKit V1 | LDR Light Sensor, PWM MOSFET/Relay, Auto-dimming |
| **2. AI Security Radar** | [`esp32_cam_ai_security.ino`](file:///c:/Users/THERESE/Desktop/VIGILIS%20APP/FIRMWARE/esp32_cam_ai_security/esp32_cam_ai_security.ino) | AI-Thinker ESP32-CAM | OV2640 Camera, PIR Motion Sensor, Flash Strobe |
| **3. Emergency Siren Hub** | [`esp32_security_alarm_hub.ino`](file:///c:/Users/THERESE/Desktop/VIGILIS%20APP/FIRMWARE/esp32_security_alarm_hub/esp32_security_alarm_hub.ino) | ESP32 DevKit V1 | Hardware Panic Button, High-Decibel Siren, Strobe LED |

---

## 🔌 1. Smart Lighting Node Wiring

```text
               +-------------------+
               |  ESP32 DevKit V1  |
               +-------------------+
   3.3V  ------> LDR Pin 1 (with 10kΩ Pull-down to GND)
 GPIO 34 <------ LDR Center Pin (ADC1)
 GPIO 23 ------> Gate of MOSFET (IRLZ44N) or Relay Signal IN
    GND  ------> Power Supply Ground
```

### Pinout Table:
- **GPIO 34 (ADC1)**: Analog LDR Light Sensor.
- **GPIO 23**: Hardware PWM LED Dimmer / Relay Trigger.
- **GPIO 2**: Onboard Status Indicator.

---

## 📷 2. AI Security Radar (ESP32-CAM) Wiring

```text
               +-------------------+
               |  ESP32-CAM Module |
               +-------------------+
  5V / 2A -----> VCC (requires min 2A clean power supply)
    GND  ------> GND
 GPIO 13 <------ PIR Sensor OUT (Motion Detection Trigger)
 GPIO 4  ------> Onboard High-Power Flash LED
```

### FTDI Flashing Connection:
- **FTDI VCC (5V)** $\rightarrow$ ESP32-CAM **5V**
- **FTDI GND** $\rightarrow$ ESP32-CAM **GND**
- **FTDI TX** $\rightarrow$ ESP32-CAM **U0R (RX)**
- **FTDI RX** $\rightarrow$ ESP32-CAM **U0T (TX)**
- **Connect `GPIO 0` to `GND` during flashing**, then disconnect and press **RST** to run.

---

## 🚨 3. Emergency Siren & Panic Hub Wiring

```text
               +-------------------+
               |  ESP32 DevKit V1  |
               +-------------------+
 GPIO 4  <------ Push Button (other leg to GND, uses internal PULLUP)
 GPIO 18 ------> Active Piezo Siren Buzzer (+)
 GPIO 19 ------> Red Warning Strobe LED (+) with 220Ω resistor
    GND  ------> Buzzer (-), LED (-), Button GND
```

---

## ⚙️ Software & Library Requirements

In **Arduino IDE** (or **PlatformIO**):
1. Install **ESP32 Board Package**:
   - `Preferences` $\rightarrow$ Additional Board Manager URLs: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. Install Required Libraries via Library Manager:
   - **`ArduinoJson`** (by Benoit Blanchon, Version 6.x or 7.x)
   - **`WiFi`** (Built-in for ESP32)
   - **`HTTPClient`** (Built-in for ESP32)

---

## 📡 Configuring WiFi and Backend IP
In each `.ino` file:
```cpp
const char* WIFI_SSID     = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* BACKEND_BASE_URL = "http://192.168.1.100:5000/api"; // Your Computer's Local IP
```
