const express = require('express');
const router = express.Router();
const { getSecurityStatus, setSecurityState, reportSensorOrCameraCapture } = require('../controllers/security.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard, checkResidentPermission } = require('../middlewares/tenantGuard');

// Hardware/Camera intake telemetry endpoint
router.post('/telemetry/capture', reportSensorOrCameraCapture);

router.use(authenticate);
router.use(tenantGuard);

router.get('/', getSecurityStatus);
router.post('/state', checkResidentPermission('can_arm_security'), setSecurityState);

module.exports = router;
