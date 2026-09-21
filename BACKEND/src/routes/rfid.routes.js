const express = require('express');
const router = express.Router();
const {
  getHouseRfidCards,
  registerRfidCard,
  updateRfidCard,
  deleteRfidCard,
} = require('../controllers/rfid.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');

// All RFID management routes require authentication & house tenantGuard
router.use(authenticate);
router.use(tenantGuard);

router.get('/', getHouseRfidCards);
router.post('/', registerRfidCard);
router.put('/:id', updateRfidCard);
router.delete('/:id', deleteRfidCard);

module.exports = router;
