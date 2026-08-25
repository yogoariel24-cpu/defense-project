const express = require('express');
const router = express.Router();
const { getLightingStatus, setLightMode, setBrightness } = require('../controllers/lighting.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard, checkResidentPermission } = require('../middlewares/tenantGuard');

router.use(authenticate);
router.use(tenantGuard);

router.get('/', getLightingStatus);
router.post('/mode', checkResidentPermission('can_control_lights'), setLightMode);
router.post('/brightness', checkResidentPermission('can_control_lights'), setBrightness);

module.exports = router;
