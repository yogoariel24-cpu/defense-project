const { House, SecurityEvent, AIAnalysis, Camera, MotionSensor, FaceProfile } = require('../models');
const { analyzeThreatAndBiometrics } = require('../services/aiThreatService');

const getSecurityStatus = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const house = await House.findByPk(houseId, {
      attributes: ['id', 'name', 'security_status', 'last_security_change_at'],
    });

    const recentEvents = await SecurityEvent.findAll({
      where: { house_id: houseId },
      include: [{ model: AIAnalysis, as: 'aiAnalysis' }],
      limit: 20,
      order: [['created_at', 'DESC']],
    });

    const cameras = await Camera.findAll({ where: { house_id: houseId } });
    const motionSensors = await MotionSensor.findAll({ where: { house_id: houseId } });

    res.status(200).json({
      success: true,
      data: {
        houseId: house?.id,
        securityStatus: house?.security_status,
        lastChangedAt: house?.last_security_change_at,
        recentEvents,
        cameras,
        motionSensors,
      },
    });
  } catch (error) {
    next(error);
  }
};

const setSecurityState = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { status } = req.body; // 'DISARMED', 'ARMED_AWAY', 'ARMED_HOME'

    if (!['DISARMED', 'ARMED_AWAY', 'ARMED_HOME'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid security state.' });
    }

    const house = await House.findByPk(houseId);
    if (!house) return res.status(404).json({ success: false, message: 'House not found.' });

    house.security_status = status;
    house.last_security_change_at = new Date();
    await house.save();

    // Log security state change event
    await SecurityEvent.create({
      house_id: houseId,
      event_type: status === 'DISARMED' ? 'SECURITY_DISARMED' : 'SECURITY_ARMED',
      severity: 'LOW',
      description: `House security state changed to ${status} by user ${req.user.first_name} ${req.user.last_name}.`,
      status: 'RESOLVED',
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('security_status_changed', {
        houseId,
        securityStatus: status,
        changedBy: `${req.user.first_name} ${req.user.last_name}`,
        timestamp: new Date().toISOString(),
      });
    }

    res.status(200).json({
      success: true,
      message: `Security system successfully set to ${status}.`,
      data: { securityStatus: status },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Endpoint called by ESP32 / ESP32-CAM or Test Simulator when motion or capture occurs.
 */
const reportSensorOrCameraCapture = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId || req.body.house_id;
    const {
      device_id,
      event_type = 'MOTION_DETECTED',
      image_url,
      has_person = true,
      person_confidence = 0.94,
      has_face = true,
      face_confidence = 0.91,
      face_embedding = null,
    } = req.body;

    const securityEvent = await SecurityEvent.create({
      house_id: houseId,
      device_id,
      event_type,
      severity: 'MEDIUM',
      image_url: image_url || 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600',
      description: `Telemetry trigger: ${event_type} detected. AI threat analysis initiated.`,
      status: 'INVESTIGATING',
    });

    const io = req.app.get('io');

    // Run Node.js AI Threat Analysis
    const aiResult = await analyzeThreatAndBiometrics({
      houseId,
      securityEventId: securityEvent.id,
      hasPerson: has_person,
      personConfidence: person_confidence,
      hasFace: has_face,
      faceConfidence: face_confidence,
      incomingEmbedding: face_embedding,
      capturedImageUrl: securityEvent.image_url,
      io,
    });

    res.status(201).json({
      success: true,
      message: 'Telemetry received and analyzed.',
      data: {
        securityEvent,
        aiAnalysis: aiResult.aiRecord,
        threatLevel: aiResult.threatLevel,
        riskScore: aiResult.riskScore,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getSecurityStatus, setSecurityState, reportSensorOrCameraCapture };
