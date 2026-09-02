const express = require('express');
const router = express.Router();
const {
  getAllHomeowners,
  createHomeowner,
  updateHomeowner,
  updateAccountStatus,
  deleteAccount,
  getPlatformStats,
  validatePayment,
  provisionDeviceToHouse,
  getAllDeviceOrders,
} = require('../controllers/admin.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { requireRole } = require('../middlewares/roleMiddleware');

router.use(authenticate);
router.use(requireRole(['PLATFORM_ADMIN']));

router.get('/homeowners', getAllHomeowners);
router.post('/homeowners', createHomeowner);
router.put('/homeowners/:userId', updateHomeowner);
router.patch('/homeowners/:userId/payment', validatePayment);
router.patch('/users/:userId/status', updateAccountStatus);
router.delete('/users/:userId', deleteAccount);
router.get('/stats', getPlatformStats);

// Device Provisioning & Orders
router.post('/houses/:houseId/devices', provisionDeviceToHouse);
router.get('/device-orders', getAllDeviceOrders);

module.exports = router;
