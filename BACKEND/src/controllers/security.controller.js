const { House, SecurityEvent, AIAnalysis, Camera, MotionSensor, FaceProfile } = require('../models');
const { processVisionTelemetry } = require('../services/aiVisionEngine');

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
 * Runs OpenCV Facial Recognition & Multi-Class Object Recognition (Human vs Animal vs Vehicle).
 */
const reportSensorOrCameraCapture = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId || req.body.house_id;
    const {
      device_id,
      event_type = 'MOTION_DETECTED',
      detected_object = 'person', // 'person', 'dog', 'cat', 'car', etc.
      object_confidence = 0.95,
      has_face = true,
      face_confidence = 0.91,
      face_embedding = null,
      camera_name = 'Perimeter Camera',
      image_url,
    } = req.body;

    const securityEvent = await SecurityEvent.create({
      house_id: houseId,
      device_id,
      event_type,
      severity: 'MEDIUM',
      image_url: image_url || 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600',
      description: `Telemetry trigger: ${event_type} (${detected_object}) detected. AI Vision evaluation running.`,
      status: 'INVESTIGATING',
    });

    const io = req.app.get('io');

    // Run AI Vision & Object Classification Pipeline
    const aiResult = await processVisionTelemetry({
      houseId,
      securityEventId: securityEvent.id,
      detectedObjectLabel: detected_object,
      objectConfidence: object_confidence,
      hasFace: has_face,
      faceConfidence: face_confidence,
      incomingEmbedding: face_embedding,
      cameraName: camera_name,
      imageUrl: securityEvent.image_url,
      io,
    });

    res.status(201).json({
      success: true,
      message: 'Telemetry received and evaluated by Vigilis AI Vision Engine.',
      data: {
        securityEvent,
        aiAnalysis: aiResult.aiRecord,
        objectCategory: aiResult.objectCategory,
        faceMatchResult: aiResult.matchResult,
        threatLevel: aiResult.threatLevel,
        riskScore: aiResult.riskScore,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getSecurityStatus, setSecurityState, reportSensorOrCameraCapture };
