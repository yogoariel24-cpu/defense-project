const express = require('express');
const router = express.Router();
const {
  handleRfidAccessAttempt,
  handleFaceAccessAttempt,
  handleIoTEvent,
  handleDeviceHeartbeat,
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

// 1. RFID Card Access Attempt
router.post('/access/rfid', handleRfidAccessAttempt);

// 2. Facial Recognition Face Embedding Access Attempt
router.post('/access/face', handleFaceAccessAttempt);

// 3. Sensor / Presence Detection Telemetry Events
router.post('/events', handleIoTEvent);

// 4. Device Heartbeat
router.post('/heartbeat', handleDeviceHeartbeat);

module.exports = router;
