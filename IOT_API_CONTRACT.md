# VIGILIS Intelligent House — IoT Hardware API Contract

This document specifies the exact REST API contract, request/response formats, authentication, and status codes for external IoT devices (RFID Readers, Edge-AI Cameras, Presence/Ultrasonic Sensors, Door Controllers) communicating with the Vigilis Backend.

> **Hardware / Firmware Notice**: Device firmware is engineered separately. The Vigilis application server strictly exposes these standard HTTP/JSON and WebSocket interfaces to receive telemetry and control physical access points.

---

## 1. Network & Base URL

- **Protocol**: HTTP/1.1 or HTTP/2, TLS/HTTPS recommended in production
- **Default Base Endpoint**: `http://<BACKEND_HOST>:5000/api/iot`
- **Data Format**: `Content-Type: application/json`

### Authentication Headers (Optional / Configurable)
If `IOT_REQUIRE_AUTH=true` is enabled on the backend, every IoT request must include:
```http
x-iot-device-key: vigilis_iot_secret_key_2026
```
Otherwise, devices identify themselves via their unique registered `device_identifier` in each payload.

---

## 2. Endpoints Overview

| Method | Endpoint | Description | Primary Devices |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/iot/access/rfid` | Process RFID card scan attempt | RFID / NFC Keycard Readers |
| `POST` | `/api/iot/access/face` | Process facial recognition access attempt using face embedding | Edge-AI Cameras / Biometric Scanners |
| `POST` | `/api/iot/events` | Ingest sensor events (Presence, Motion, Tamper) | Ultrasonic Sensors, PIR Sensors, Break-ins |
| `POST` | `/api/iot/heartbeat` | Health check & online status ping | All IoT Controllers |

---

## 3. Endpoint Specifications

### 3.1 RFID Access Attempt

Invoked when an RFID card or NFC keyfob is presented to an RFID door reader.

- **URL**: `POST /api/iot/access/rfid`
- **Payload Schema**:
```json
{
  "card_uid": "A1:B2:C3:D4",
  "device_identifier": "RFID_FRONT_DOOR_01",
  "room_id": "8a329d20-410a-408a-8289-53e92ad34bb1",
  "timestamp": "2026-09-21T12:00:00Z"
}
```

- **Parameters**:
  - `card_uid` *(string, required)*: Hexadecimal or raw UID string read from the card.
  - `device_identifier` *(string, required)*: Registered identifier of the reader hardware.
  - `room_id` *(UUID string, optional)*: Specific room ID. If omitted, backend defaults to device's registered room.
  - `timestamp` *(ISO 8601 string, optional)*: Hardware event timestamp.

- **Response (200 OK — Access Granted)**:
```json
{
  "success": true,
  "granted": true,
  "status": "GRANTED",
  "door_unlocked": true,
  "message": "Access granted. Door unlocked for Martin Dupont.",
  "data": {
    "resident": { "id": "uuid-here", "name": "Martin Dupont" },
    "room": { "id": "uuid-here", "name": "Living Room" },
    "card": { "id": "uuid-here", "uid": "A1:B2:C3:D4", "label": "Martin Main Fob" },
    "timestamp": "2026-09-21T12:00:00.123Z"
  }
}
```

- **Response (403 Forbidden — Access Denied)**:
```json
{
  "success": true,
  "granted": false,
  "status": "DENIED",
  "door_unlocked": false,
  "reason": "Access to Server Room is restricted for this resident."
}
```
*Denial Reasons include*: `UNREGISTERED_CARD`, `CARD_BLOCKED`, `CARD_REVOKED`, `INACTIVE_ACCOUNT`, `ROOM_PERMISSION_DENIED`, `RESTRICTED_ROOM_NO_PERMISSION`.

---

### 3.2 Face Recognition Access Attempt (Biometric Embedding)

Invoked by an edge camera that computes a 128-d or 512-d biometric face embedding vector. No raw images or photos are required; the backend performs vector comparison against registered house residents.

- **URL**: `POST /api/iot/access/face`
- **Payload Schema**:
```json
{
  "device_identifier": "CAM_ENTRANCE_01",
  "room_id": "8a329d20-410a-408a-8289-53e92ad34bb1",
  "face_embedding": [-0.043, 0.128, 0.082, -0.019, 0.055, "..."],
  "timestamp": "2026-09-21T12:00:00Z"
}
```

- **Parameters**:
  - `face_embedding` *(array of floats, required)*: Biometric feature vector.
  - `device_identifier` *(string, required)*: Camera device identifier.
  - `room_id` *(UUID string, optional)*: Target room.
  - `timestamp` *(ISO 8601 string, optional)*: Timestamp.

- **Response (200 OK — Access Granted)**:
```json
{
  "success": true,
  "granted": true,
  "status": "GRANTED",
  "door_unlocked": true,
  "message": "Face recognized: Martin Dupont. Door unlocked automatically.",
  "data": {
    "resident": { "id": "uuid-here", "name": "Martin Dupont" },
    "room": { "id": "uuid-here", "name": "Front Entrance" },
    "distance": 0.23,
    "timestamp": "2026-09-21T12:00:00.450Z"
  }
}
```

- **Response (403 Forbidden — Unrecognized Face / Denied)**:
```json
{
  "success": true,
  "granted": false,
  "status": "DENIED",
  "door_unlocked": false,
  "reason": "Unrecognized face. Access denied.",
  "data": {
    "minDistance": 0.72
  }
}
```

---

### 3.3 Sensor Events & Presence Ingestion

Invoked by ultrasonic distance sensors, PIR motion detectors, door magnetic contacts, or tamper switches.

> **Crucial Rule: Detection $\neq$ Verified Threat**
> - Standard presence readings are marked `DETECTED` (telemetry/activity).
> - Only genuine verified intrusions (e.g. system is armed, perimeter tamper, or verified intruder) reach `VERIFIED_THREAT`.
> - Once `VERIFIED_THREAT` is reached, the backend automatically triggers the emergency response without requiring manual user intervention!

- **URL**: `POST /api/iot/events`
- **Payload Schema**:
```json
{
  "device_identifier": "US_LIVING_01",
  "event_type": "PRESENCE_DETECTED",
  "room_id": "8a329d20-410a-408a-8289-53e92ad34bb1",
  "is_verified_threat": false,
  "severity": "LOW",
  "metadata": {
    "distance_cm": 145,
    "sensor_model": "HC-SR04"
  },
  "timestamp": "2026-09-21T12:00:00Z"
}
```

- **Supported `event_type` Values**:
  - `PRESENCE_DETECTED` (ultrasonic / radar / PIR presence)
  - `MOTION_DETECTED`
  - `DOOR_OPENED`
  - `DOOR_TAMPER` (forced door / lock sabotage)
  - `INTRUSION_ALARM`

- **Response (200 OK — Normal Detection)**:
```json
{
  "success": true,
  "message": "IoT event recorded.",
  "data": {
    "threatStatus": "DETECTED",
    "isVerifiedThreat": false,
    "eventType": "PRESENCE_DETECTED",
    "deviceId": "uuid-here",
    "room": { "id": "uuid-here", "name": "Living Room" },
    "timestamp": "2026-09-21T12:00:00Z"
  }
}
```

- **Response (200 OK — Verified Genuine Threat Dispatched)**:
```json
{
  "success": true,
  "message": "Verified threat registered. Automated response dispatched.",
  "data": {
    "threatStatus": "VERIFIED_THREAT",
    "isVerifiedThreat": true,
    "eventType": "DOOR_TAMPER",
    "deviceId": "uuid-here",
    "room": { "id": "uuid-here", "name": "Front Entrance" },
    "securityEvent": { "id": "uuid-here", "status": "CONFIRMED_THREAT" },
    "timestamp": "2026-09-21T12:00:00Z"
  }
}
```

---

### 3.4 Device Heartbeat

Periodic liveness check sent by every IoT controller (e.g. every 30–60 seconds).

- **URL**: `POST /api/iot/heartbeat`
- **Payload Schema**:
```json
{
  "device_identifier": "RFID_FRONT_DOOR_01",
  "status": "ONLINE",
  "ip_address": "192.168.1.105",
  "firmware_version": "v2.1.0-iot"
}
```

- **Response (200 OK)**:
```json
{
  "success": true,
  "message": "Heartbeat acknowledged.",
  "data": {
    "device_identifier": "RFID_FRONT_DOOR_01",
    "status": "ONLINE",
    "last_heartbeat_at": "2026-09-21T12:00:00.000Z"
  }
}
```

---

## 4. Real-time WebSocket Events (Socket.IO)

The backend broadcasts events to client apps via Socket.IO room `house_<house_id>`:

| Event Name | Description |
| :--- | :--- |
| `access_attempt` | Emitted when an RFID card or face embedding attempt is processed. |
| `iot_detection_event` | Emitted when a sensor detects presence or motion (`status: DETECTED`). |
| `security_threat_alert` | Emitted immediately when an event reaches `status: VERIFIED_THREAT`. |
| `security_status_changed` | Emitted when security state toggles (`ARMED_AWAY`, `ARMED_HOME`, `DISARMED`). |
