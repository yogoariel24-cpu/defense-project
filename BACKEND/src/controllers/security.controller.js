const {
  House,
  SecurityEvent,
  AIAnalysis,
  Camera,
  MotionSensor,
  FaceProfile,
  DetectionEvent,
  Resident,
  User,
  Notification,
  Device,
  AccessHistory,
  Room,
  RfidCard,
} = require('../models');
const { processVisionTelemetry, calculateFaceDistance } = require('../services/aiVisionEngine');
const { dispatchEmergency } = require('../services/emergencyService');
const { sendUnrecognizedFaceAlert } = require('../services/emailService');

/**
 * Retrieves the comprehensive security status:
 * - Security state (Armed/Disarmed)
 * - Device status summary (online/offline counts broken down by type)
 * - Recent RFID and Face access attempts
 * - Recent detections (Detection != Verified Threat)
 * - Security events & active threat status
 */
const getSecurityStatus = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const house = await House.findByPk(houseId, {
      attributes: ['id', 'name', 'security_status', 'last_security_change_at'],
    });

    // Recent security events
    const recentEvents = await SecurityEvent.findAll({
      where: { house_id: houseId },
      include: [
        { model: AIAnalysis, as: 'aiAnalysis' },
        { model: DetectionEvent, as: 'detectionEvent' },
      ],
      limit: 30,
      order: [['created_at', 'DESC']],
    });

    // Recent detections (Detections != Verified Threats)
    const recentDetections = await DetectionEvent.findAll({
      where: { house_id: houseId },
      limit: 20,
      order: [['timestamp', 'DESC']],
    });

    // Devices & Device Status Summary
    const devices = await Device.findAll({
      where: { house_id: houseId },
      include: [{ model: Room, as: 'room', attributes: ['id', 'name'] }],
      order: [['name', 'ASC']],
    });

    const deviceSummary = {
      total: devices.length,
      online: devices.filter((d) => d.status === 'ONLINE').length,
      offline: devices.filter((d) => d.status === 'OFFLINE').length,
      byType: {
        CAMERA: devices.filter((d) => d.type === 'CAMERA' || d.type === 'ESP32_CAM').length,
        RFID_READER: devices.filter((d) => d.type === 'RFID_READER').length,
        DOOR_LOCK: devices.filter((d) => d.type === 'DOOR_LOCK').length,
        PRESENCE_SENSOR: devices.filter((d) => d.type === 'PRESENCE_SENSOR' || d.type === 'MOTION_SENSOR').length,
        LIGHT: devices.filter((d) => d.type === 'SMART_LIGHT').length,
      },
    };

    // Recent RFID and Face Access Attempts
    const recentAccess = await AccessHistory.findAll({
      where: { house_id: houseId },
      limit: 15,
      order: [['timestamp', 'DESC']],
      include: [
        { model: Room, as: 'room', attributes: ['id', 'name'] },
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name'] }],
        },
        { model: RfidCard, as: 'rfidCard', attributes: ['id', 'card_uid', 'label'] },
      ],
    });

    // Active Threat Status: Check if any unconfirmed threat or verified threat exists
    const activeThreatEvent = recentEvents.find(
      (e) => e.status === 'CONFIRMED_THREAT' || e.status === 'INVESTIGATING'
    );
    const threatStatus = activeThreatEvent
      ? (activeThreatEvent.status === 'CONFIRMED_THREAT' ? 'VERIFIED_THREAT' : 'SUSPICIOUS')
      : 'NORMAL';

    res.status(200).json({
      success: true,
      data: {
        houseId: house?.id,
        securityStatus: house?.security_status,
        lastChangedAt: house?.last_security_change_at,
        threatStatus,
        activeThreat: activeThreatEvent || null,
        deviceSummary,
        devices,
        recentAccess,
        recentEvents,
        recentDetections,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Changes house security state (DISARMED, ARMED_AWAY, ARMED_HOME).
 */
const setSecurityState = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { status } = req.body;

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
 * Real-time AI Ingestion endpoint called by the Python YOLO + OpenCV AI Service.
 * Evaluates object classification, runs authorization checks against registered house residents,
 * calculates threat status, stores DetectionEvent, and broadcasts real-time alerts.
 */
const ingestDetection = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId || req.body.house_id;
    const {
      camera_id = null,
      camera_name = 'AI Surveillance Camera',
      object_type = 'person',
      class_name = 'person',
      confidence = 0.90,
      bounding_box = null,
      has_face = false,
      face_confidence = 0.0,
      face_embedding = null,
      snapshot_data = null,
      timestamp = new Date(),
    } = req.body;

    if (!houseId) {
      return res.status(400).json({ success: false, message: 'house_id is required.' });
    }

    const house = await House.findByPk(houseId, {
      include: [{ model: require('../models').Homeowner, as: 'homeowner', include: [{ model: User, as: 'user' }] }],
    });

    if (!house) {
      return res.status(404).json({ success: false, message: `House '${houseId}' not found.` });
    }

    const isArmed = house.security_status === 'ARMED_AWAY' || house.security_status === 'ARMED_HOME';
    const currentHour = new Date().getHours();
    const isNightTime = currentHour >= 22 || currentHour <= 5;

    // --- Threat Evaluation Pipeline ---
    let eventStatus = 'DETECTED';
    let threatLevel = 'NORMAL';
    let matchedResident = null;
    let isAuthorized = false;

    if (object_type === 'animal') {
      // Animals are harmless movement -> Filter false alarms
      eventStatus = 'NORMAL';
      threatLevel = 'NORMAL';
    } else if (object_type === 'vehicle') {
      eventStatus = (isArmed && isNightTime) ? 'SUSPICIOUS' : 'NORMAL';
      threatLevel = (isArmed && isNightTime) ? 'SUSPICIOUS' : 'NORMAL';
    } else if (object_type === 'person') {
      // Check face authorization against registered residents
      const registeredProfiles = await FaceProfile.findAll({
        where: { house_id: houseId, is_active: true },
        include: [{ model: Resident, as: 'resident', include: [{ model: User, as: 'user' }] }],
      });

      if (has_face && face_embedding && registeredProfiles.length > 0) {
        for (const profile of registeredProfiles) {
          if (profile.face_embedding) {
            try {
              const regVec = JSON.parse(profile.face_embedding);
              const dist = calculateFaceDistance(face_embedding, regVec);
              if (dist < 0.45) {
                isAuthorized = true;
                matchedResident = profile.resident?.user;
                break;
              }
            } catch (_) {}
          }
        }
      }

      if (isAuthorized) {
        eventStatus = 'NORMAL';
        threatLevel = 'NORMAL';
      } else {
        // Unknown person detected!
        if (isArmed) {
          // Armed house + Unknown person -> Verified Threat!
          eventStatus = 'VERIFIED_THREAT';
          threatLevel = 'CONFIRMED_THREAT';
        } else {
          eventStatus = 'SUSPICIOUS';
          threatLevel = 'SUSPICIOUS';
        }
      }
    }

    // 1. Persist atomic DetectionEvent
    const detectionEvent = await DetectionEvent.create({
      house_id: houseId,
      camera_id: camera_id,
      object_type: object_type,
      class_name: class_name,
      confidence: confidence,
      bounding_box: bounding_box,
      has_face: has_face,
      face_confidence: face_confidence,
      status: eventStatus,
      image_url: snapshot_data,
      timestamp: timestamp,
    });

    let securityEvent = null;
    const io = req.app.get('io');

    // 2. If threat is suspicious or verified, create SecurityEvent
    if (eventStatus === 'VERIFIED_THREAT' || eventStatus === 'SUSPICIOUS') {
      const isCritical = eventStatus === 'VERIFIED_THREAT';

      securityEvent = await SecurityEvent.create({
        house_id: houseId,
        device_id: camera_id,
        event_type: isCritical ? 'INTRUSION_ALARM' : (has_face ? 'UNKNOWN_FACE' : 'MOTION_DETECTED'),
        severity: isCritical ? 'CRITICAL' : 'HIGH',
        image_url: snapshot_data,
        description: isCritical
          ? `🚨 VERIFIED THREAT: Unknown person detected by ${camera_name} while security was ${house.security_status}!`
          : `⚠️ Suspicious ${object_type} activity detected by ${camera_name}.`,
        status: isCritical ? 'CONFIRMED_THREAT' : 'INVESTIGATING',
      });

      // Link DetectionEvent to SecurityEvent
      detectionEvent.security_event_id = securityEvent.id;
      await detectionEvent.save();

      // Create AI Analysis record
      await AIAnalysis.create({
        security_event_id: securityEvent.id,
        house_id: houseId,
        person_detected: object_type === 'person',
        person_confidence: confidence,
        face_detected: has_face,
        face_confidence: face_confidence,
        face_recognition_result: isAuthorized ? 'AUTHORIZED' : (has_face ? 'UNKNOWN' : 'NO_FACE'),
        threat_level: threatLevel,
        risk_score: isCritical ? 92.0 : 55.0,
        raw_details: {
          class_name,
          camera_name,
          bounding_box,
          eventStatus,
        },
      });

      // 3. Emit real-time high-priority alert via Socket.IO
      if (io) {
        io.to(`house_${houseId}`).emit('security_threat_alert', {
          houseId,
          securityEventId: securityEvent.id,
          detectionId: detectionEvent.id,
          status: eventStatus,
          threatLevel: threatLevel,
          cameraName: camera_name,
          objectType: object_type,
          confidence: confidence,
          description: securityEvent.description,
          imageUrl: snapshot_data,
          timestamp: new Date().toISOString(),
        });
      }

      // 4. In-App Notification
      const homeownerUser = house.homeowner?.user;
      await Notification.create({
        house_id: houseId,
        user_id: homeownerUser?.id || null,
        type: 'SECURITY_ALERT',
        title: isCritical ? '🚨 CRITICAL: Intruder Alert' : '⚠️ Suspicious Activity Detected',
        message: securityEvent.description,
        data: {
          security_event_id: securityEvent.id,
          threat_level: threatLevel,
          status: eventStatus,
        },
      }).catch(() => {});

      // 5. Automatic Emergency escalation if verified threat
      if (isCritical) {
        dispatchEmergency({
          houseId,
          securityEventId: securityEvent.id,
          source: 'AUTOMATIC_AI',
          notes: `YOLO + OpenCV Intrusion Alarm: Unknown person detected by ${camera_name} during ${house.security_status}.`,
          io,
        }).catch((err) => console.error('Emergency dispatch error:', err.message));
      }
    } else {
      // Real-time normal detection broadcast (for radar dashboard)
      if (io) {
        io.to(`house_${houseId}`).emit('detection_event', {
          houseId,
          detectionId: detectionEvent.id,
          objectType: object_type,
          className: class_name,
          confidence,
          status: eventStatus,
          timestamp: detectionEvent.timestamp,
        });
      }
    }

    res.status(201).json({
      success: true,
      message: 'Detection event evaluated and recorded.',
      data: {
        detectionEvent,
        securityEvent,
        eventStatus,
        threatLevel,
        isAuthorized,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Retrieves detection events for the caller's house (House-isolated).
 */
const getDetectionEvents = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { limit = 50, object_type, status } = req.query;

    const where = { house_id: houseId };
    if (object_type) where.object_type = object_type;
    if (status) where.status = status;

    const detections = await DetectionEvent.findAll({
      where,
      limit: parseInt(limit, 10),
      order: [['timestamp', 'DESC']],
      include: [{ model: Camera, as: 'camera', attributes: ['id', 'location_name', 'stream_url'] }],
    });

    res.status(200).json({
      success: true,
      data: { detections },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Retrieves all security events for the caller's house (House-isolated).
 */
const getSecurityEvents = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { status, severity, limit = 50 } = req.query;

    const where = { house_id: houseId };
    if (status) where.status = status;
    if (severity) where.severity = severity;

    const events = await SecurityEvent.findAll({
      where,
      include: [
        { model: AIAnalysis, as: 'aiAnalysis' },
        { model: DetectionEvent, as: 'detectionEvent' },
      ],
      limit: parseInt(limit, 10),
      order: [['created_at', 'DESC']],
    });

    res.status(200).json({
      success: true,
      data: { events },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Retrieves a single security event by ID (Verifying house isolation).
 */
const getSecurityEventById = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;

    const event = await SecurityEvent.findOne({
      where: { id, house_id: houseId },
      include: [
        { model: AIAnalysis, as: 'aiAnalysis' },
        { model: DetectionEvent, as: 'detectionEvent' },
      ],
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Security event not found or access denied.' });
    }

    res.status(200).json({
      success: true,
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Retrieves security events for a specific camera in the authorized house.
 */
const getEventsByCamera = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { cameraId } = req.params;

    // Verify camera belongs to this house
    const camera = await Camera.findOne({ where: { id: cameraId, house_id: houseId } });
    if (!camera) {
      return res.status(404).json({ success: false, message: 'Camera not found or does not belong to your house.' });
    }

    const events = await SecurityEvent.findAll({
      where: { house_id: houseId, device_id: cameraId },
      include: [{ model: AIAnalysis, as: 'aiAnalysis' }],
      order: [['created_at', 'DESC']],
      limit: 30,
    });

    res.status(200).json({
      success: true,
      data: { camera, events },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Updates the status of a security event (e.g. RESOLVED, FALSE_ALARM, INVESTIGATING).
 */
const updateSecurityEventStatus = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;
    const { status } = req.body;

    if (!['LOGGED', 'INVESTIGATING', 'CONFIRMED_THREAT', 'FALSE_ALARM', 'RESOLVED'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value.' });
    }

    const event = await SecurityEvent.findOne({ where: { id, house_id: houseId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Security event not found or access denied.' });
    }

    event.status = status;
    if (status === 'RESOLVED') {
      event.resolved_at = new Date();
    }
    await event.save();

    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('security_event_updated', {
        houseId,
        eventId: event.id,
        status: event.status,
        updatedBy: `${req.user.first_name} ${req.user.last_name}`,
      });
    }

    res.status(200).json({
      success: true,
      message: `Security event marked as ${status}.`,
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Legacy telemetry handler preserved for hardware backward compatibility.
 */
const reportSensorOrCameraCapture = async (req, res, next) => {
  return ingestDetection(req, res, next);
};

module.exports = {
  getSecurityStatus,
  setSecurityState,
  ingestDetection,
  getDetectionEvents,
  getSecurityEvents,
  getSecurityEventById,
  getEventsByCamera,
  updateSecurityEventStatus,
  reportSensorOrCameraCapture,
};

