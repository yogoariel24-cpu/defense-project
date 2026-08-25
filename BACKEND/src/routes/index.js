const express = require('express');
const router = express.Router();

const authRoutes = require('./auth.routes');
const adminRoutes = require('./admin.routes');
const houseRoutes = require('./house.routes');
const residentRoutes = require('./resident.routes');
const deviceRoutes = require('./device.routes');
const lightingRoutes = require('./lighting.routes');
const securityRoutes = require('./security.routes');
const emergencyRoutes = require('./emergency.routes');
const notificationRoutes = require('./notification.routes');

// Health Check
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ONLINE',
    service: 'Vigilis Intelligent House Backend API',
    timestamp: new Date().toISOString(),
  });
});

router.use('/auth', authRoutes);
router.use('/admin', adminRoutes);
router.use('/houses', houseRoutes);
router.use('/residents', residentRoutes);
router.use('/devices', deviceRoutes);
router.use('/lighting', lightingRoutes);
router.use('/security', securityRoutes);
router.use('/emergency', emergencyRoutes);
router.use('/notifications', notificationRoutes);

module.exports = router;
