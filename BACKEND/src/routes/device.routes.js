const express = require('express');
const router = express.Router();
const { getHouseDevices, registerDevice, sendHeartbeat } = require('../controllers/device.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');
const { requireRole } = require('../middlewares/roleMiddleware');

// Heartbeat endpoint can be called by devices
router.post('/heartbeat', sendHeartbeat);

router.use(authenticate);
router.use(tenantGuard);

router.get('/', getHouseDevices);
router.post('/', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), registerDevice);

module.exports = router;
