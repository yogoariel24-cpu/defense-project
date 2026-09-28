const express = require('express');
const router = express.Router();
const {
  handleAccessRequest,
  handleRfidAccessAttempt,
  handleFaceAccessAttempt,
  handleFaceVerification,
  handleIoTEvent,
  handleDeviceHeartbeat,
  handleGetDoorStatus,
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

  if (process.env.IOT_REQUIRE_AUTH === 'true' && deviceKey !== expectedKey) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized: Invalid or missing IoT device authentication key.',
    });
  }

  next();
};

router.use(verifyIoTToken);

// 1. Access Control Endpoints (RFID & Facial Verification)
router.post('/access/request', handleAccessRequest);       // Main access request from ESP32
router.post('/access/rfid', handleRfidAccessAttempt);      // RFID reader endpoint
router.post('/access/verify-face', handleFaceVerification); // ESP32-CAM image verification via AI
router.post('/access/face', handleFaceAccessAttempt);      // Biometric face vector endpoint
router.get('/door/status/:device_identifier', handleGetDoorStatus);

// 2. Security & Telemetry Events
router.post('/events', handleIoTEvent);

// 3. Device Lifecycle & Diagnostics
router.post('/heartbeat', handleDeviceHeartbeat);
router.get('/config/:device_identifier', handleGetDeviceConfig);

// 4. Hardware Emergency Trigger
router.post('/emergency/trigger', handleEmergencyTrigger);

module.exports = router;
