const express = require('express');
const router = express.Router();
const {
  getResidents,
  addResident,
  updateResidentPermissions,
  registerFaceProfile,
  deleteResident,
} = require('../controllers/resident.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');
const { requireRole } = require('../middlewares/roleMiddleware');

router.use(authenticate);
router.use(tenantGuard);

router.get('/', getResidents);
router.post('/', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), addResident);
router.put('/:residentId', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), updateResidentPermissions);
router.post('/:residentId/face-profile', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), registerFaceProfile);
router.delete('/:residentId', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), deleteResident);

module.exports = router;
