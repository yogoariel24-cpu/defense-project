const express = require('express');
const router = express.Router();
const { getMyNotifications, markAsRead } = require('../controllers/notification.controller');
const { authenticate } = require('../middlewares/authMiddleware');

router.use(authenticate);

router.get('/', getMyNotifications);
router.patch('/:id/read', markAsRead);

module.exports = router;
