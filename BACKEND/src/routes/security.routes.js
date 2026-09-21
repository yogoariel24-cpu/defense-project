const express = require('express');
const router = express.Router();
const {
  getSecurityStatus,
  setSecurityState,
  ingestDetection,
  getDetectionEvents,
  getSecurityEvents,
  getSecurityEventById,
  getEventsByCamera,
  updateSecurityEventStatus,
  reportSensorOrCameraCapture,
} = require('../controllers/security.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard, checkResidentPermission } = require('../middlewares/tenantGuard');

// Middleware to authenticate external service via shared secret header OR standard JWT
const authenticateAIServiceOrUser = (req, res, next) => {
  const serviceKey = req.headers['x-ai-service-key'];
  const expectedKey = process.env.AI_SERVICE_SECRET || 'vigilis_ai_secret_key_2026';

  if (serviceKey && serviceKey === expectedKey) {
    req.targetHouseId = req.body.house_id;
    return next();
  }

  return authenticate(req, res, () => {
    return tenantGuard(req, res, next);
  });
};

// 1. Telemetry / Detection Ingestion Endpoints
router.post('/detections', authenticateAIServiceOrUser, ingestDetection);
router.post('/telemetry/capture', authenticateAIServiceOrUser, reportSensorOrCameraCapture);

// 2. Authenticated & House-Isolated Endpoints for Users
router.use(authenticate);
router.use(tenantGuard);

// Security Status & State Management
router.get('/', getSecurityStatus);
router.post('/state', checkResidentPermission('can_arm_security'), setSecurityState);

// Detection Events (Real-time Ingestion log)
router.get('/detections', getDetectionEvents);

// Security Events
router.get('/events', getSecurityEvents);
router.get('/events/:id', getSecurityEventById);
router.patch('/events/:id/status', updateSecurityEventStatus);

// Camera Specific Events
router.get('/cameras/:cameraId/events', getEventsByCamera);

module.exports = router;

