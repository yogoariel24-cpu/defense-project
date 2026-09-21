const express = require('express');
const router = express.Router();
const { getHouseAccessHistory } = require('../controllers/accessHistory.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');

// Access history audit log requires authentication & house isolation
router.use(authenticate);
router.use(tenantGuard);

router.get('/', getHouseAccessHistory);

module.exports = router;
