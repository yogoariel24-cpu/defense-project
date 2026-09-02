const express = require('express');
const router = express.Router();
const {
  getHouseDetails,
  updateHouseSettings,
  submitPayment,
  getPaymentStatus,
  orderDevice,
  getHouseDeviceOrders,
} = require('../controllers/house.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard, requirePaymentActive } = require('../middlewares/tenantGuard');
const { requireRole } = require('../middlewares/roleMiddleware');

router.use(authenticate);

// Payment endpoints (available even before validation)
router.post('/payment/submit', requireRole(['HOMEOWNER']), submitPayment);
router.get('/payment/status', getPaymentStatus);

// Hardware device ordering & purchase
router.post('/devices/order', tenantGuard, requirePaymentActive, requireRole(['HOMEOWNER']), orderDevice);
router.get('/devices/orders', tenantGuard, requirePaymentActive, getHouseDeviceOrders);

// House management endpoints (requires active payment verification for non-admins)
router.get('/:houseId?', tenantGuard, requirePaymentActive, getHouseDetails);
router.put('/:houseId?', tenantGuard, requirePaymentActive, requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), updateHouseSettings);

module.exports = router;
