const express = require('express');
const router = express.Router();
const {
  getHouseCameras,
  addCamera,
  updateCamera,
  toggleCameraStatus,
  deleteCamera,
  getCameraStatus,
} = require('../controllers/camera.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');
const { requireRole } = require('../middlewares/roleMiddleware');

router.use(authenticate);
router.use(tenantGuard);

// Camera Management routes
router.get('/', getHouseCameras);
router.post('/', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), addCamera);
router.put('/:id', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), updateCamera);
router.patch('/:id/status', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), toggleCameraStatus);
router.delete('/:id', requireRole(['PLATFORM_ADMIN', 'HOMEOWNER']), deleteCamera);
router.get('/:id/status', getCameraStatus);

module.exports = router;
