const express = require('express');
const router = express.Router();
const {
  handleRfidAccessAttempt,
  handleFaceAccessAttempt,
  handleIoTEvent,
  handleDeviceHeartbeat,
  handleLightSensorReading,
  handleGetDoorStatus,
  handleGetLightState,
  handleLightStateSync,
  handleGetDeviceConfig,
  handleEmergencyTrigger,
} = require('../controllers/iot.controller');

/**
 * Middleware to optionally check IoT Device Secret Header if configured.
 * Enforces hardware integration security while accepting registered devices.
 */
const verifyIoTToken = (req, res, next) => {
  const deviceKey = req.headers['x-iot-device-key'] || req.headers['x-device-key'];
  const expectedKey = process.env.IOT_DEVICE_SECRET || 'vigilis_iot_secret_key_2026';

  // If secret is set and provided, verify match
  if (process.env.IOT_REQUIRE_AUTH === 'true' && deviceKey !== expectedKey) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized: Invalid or missing IoT device authentication key.',
    });
  }

  next();
};

router.use(verifyIoTToken);

// 1. Access Control (RFID & Facial Recognition)
router.post('/access/rfid', handleRfidAccessAttempt);
router.post('/access/face', handleFaceAccessAttempt);
router.get('/door/status/:device_identifier', handleGetDoorStatus);

// 2. Sensor / Presence Detection Telemetry Events
router.post('/events', handleIoTEvent);
router.post('/sensors/light', handleLightSensorReading);

// 3. Smart Actuators (Relays & Lighting)
router.get('/lights/:device_identifier/state', handleGetLightState);
router.post('/lights/state-sync', handleLightStateSync);

// 4. Device Lifecycle & Diagnostics
router.post('/heartbeat', handleDeviceHeartbeat);
router.get('/config/:device_identifier', handleGetDeviceConfig);

// 5. Hardware Emergency Trigger
router.post('/emergency/trigger', handleEmergencyTrigger);

module.exports = router;
