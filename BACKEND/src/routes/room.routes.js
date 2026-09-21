const express = require('express');
const router = express.Router();
const {
  getHouseRooms,
  createRoom,
  updateRoom,
  deleteRoom,
  getRoomPermissions,
  setRoomPermission,
  getResidentRoomPermissions,
} = require('../controllers/room.controller');
const { authenticate } = require('../middlewares/authMiddleware');
const { tenantGuard } = require('../middlewares/tenantGuard');

// All room management routes require user authentication & house tenantGuard
router.use(authenticate);
router.use(tenantGuard);

// Room CRUD
router.get('/', getHouseRooms);
router.post('/', createRoom);
router.put('/:id', updateRoom);
router.delete('/:id', deleteRoom);

// Room Permissions
router.get('/:id/permissions', getRoomPermissions);
router.put('/:roomId/permissions/:residentId', setRoomPermission);
router.get('/resident/:residentId/permissions', getResidentRoomPermissions);

module.exports = router;
