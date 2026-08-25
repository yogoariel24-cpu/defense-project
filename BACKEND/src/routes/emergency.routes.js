const express = require('express');
const router = express.Router();
const { triggerManualEmergency, getEmergencyHistory, resolveEmergency } = require('../controllers/emergency.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard, checkResidentPermission } = require('../middlewares/tenantGuard');
const { requireRole } = require('../middlewares/roleMiddleware');

router.use(authenticate);
router.use(tenantGuard);

router.post('/trigger', checkResidentPermission('can_trigger_emergency'), triggerManualEmergency);
router.get('/history', getEmergencyHistory);
router.post('/:emergencyId/resolve', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), resolveEmergency);

module.exports = router;
