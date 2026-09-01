/**
 * ============================================================================
 * VIGILIS IOT HARDWARE EMULATOR & SIMULATOR CLI
 * ============================================================================
 * Zero-dependency native Node.js simulator that emulates physical ESP32 devices
 * communicating with the Vigilis backend REST API in real time.
 *
 * Emulated Hardware:
 *  1. ESP32 Smart Lighting Node (LDR Sensor & PWM Dimmer)
 *  2. AI-Thinker ESP32-CAM (Motion Sensor & Face Radar)
 *  3. ESP32 Emergency Siren Hub (Panic Button & Buzzer)
 *
 * Usage:
 *  node src/scripts/iot_device_simulator.js
 * ============================================================================
 */

const http = require('http');

const PORT = process.env.PORT || 5000;
const HOUSE_ID = process.env.HOUSE_ID || 'HOUSE_101';

console.log('================================================================');
console.log('⚡ VIGILIS PHYSICAL IOT HARDWARE EMULATOR STARTED');
console.log(`📡 Backend Target: http://localhost:${PORT}/api`);
console.log(`🏠 Target House: ${HOUSE_ID}`);
console.log('================================================================\n');

function postJSON(path, data, callback) {
  const payload = JSON.stringify(data);
  const req = http.request(
    {
      hostname: 'localhost',
      port: PORT,
      path: `/api${path}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'x-house-id': HOUSE_ID,
      },
    },
    (res) => {
      let responseBody = '';
      res.on('data', (chunk) => (responseBody += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseBody);
          callback(null, parsed);
        } catch (e) {
          callback(e);
        }
      });
    }
  );

  req.on('error', (err) => callback(err));
  req.write(payload);
  req.end();
}

// 1. Emulate ESP32 Smart Lighting LDR Heartbeat (every 5s)
setInterval(() => {
  const rawLux = Math.floor(120 + Math.random() * 750);
  const calculatedBrightness = rawLux < 300 ? 85 : 0;

  postJSON(
    '/devices/heartbeat',
    {
      device_identifier: 'DEV_LIGHT_ESP32_01',
      type: 'ESP32_LIGHTING',
      ambient_lux: rawLux,
      brightness: calculatedBrightness,
      mode: 'AUTO',
    },
    (err, res) => {
      if (!err && res && res.success) {
        console.log(`💡 [ESP32-Light #01] LDR: ${rawLux} Lux -> Actuator PWM: ${calculatedBrightness}% (Status: Online)`);
      } else {
        console.log(`⚠️ [ESP32-Light] Heartbeat waiting for backend at http://localhost:${PORT}...`);
      }
    }
  );
}, 5000);

// 2. Emulate ESP32-CAM Motion Sensor & AI Telemetry (every 12s)
setInterval(() => {
  const hasPerson = Math.random() > 0.45;

  postJSON(
    '/security/telemetry/capture',
    {
      camera_id: 'CAM_FRONT_GATE_01',
      event_type: 'MOTION_DETECTED',
      has_person: hasPerson,
      person_confidence: hasPerson ? 0.96 : 0.1,
      has_face: hasPerson,
      face_confidence: hasPerson ? 0.91 : 0.05,
    },
    (err, res) => {
      if (!err && res && res.success) {
        console.log(`📷 [ESP32-CAM] PIR Sensor -> Person Detected: ${hasPerson ? 'YES (AI Verified)' : 'NO'}`);
      }
    }
  );
}, 12000);
