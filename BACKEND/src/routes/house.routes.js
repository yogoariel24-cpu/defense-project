const express = require('express');
const router = express.Router();
const { getHouseDetails, updateHouseSettings } = require('../controllers/house.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');
const { requireRole } = require('../middlewares/roleMiddleware');

router.use(authenticate);
router.use(tenantGuard);

router.get('/:houseId?', getHouseDetails);
router.put('/:houseId?', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), updateHouseSettings);

module.exports = router;
