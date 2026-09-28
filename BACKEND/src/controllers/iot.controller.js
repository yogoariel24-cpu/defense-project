const {
  Device,
  House,
  Room,
  RoomPermission,
  RfidCard,
  Resident,
  User,
  FaceProfile,
  AccessHistory,
  SecurityEvent,
  Notification,
  Camera,
  EmergencyEvent,
} = require('../models');
const { calculateFaceDistance } = require('../services/aiVisionEngine');
const { dispatchEmergency } = require('../services/emergencyService');
const aiFacialService = require('../services/aiFacialService');

/**
 * Resolves a device by its identifier and marks it online with latest heartbeat.
 */
const resolveDevice = async (device_identifier) => {
  if (!device_identifier) return null;
  const device = await Device.findOne({
    where: { device_identifier },
    include: [{ model: Room, as: 'room' }],
  });
  if (device) {
    device.last_heartbeat_at = new Date();
    device.status = 'ONLINE';
    await device.save().catch(() => {});
  }
  return device;
};

/**
 * 1. Unified Access Request Endpoint (RFID Access Control Workflow)
 * Handles: POST /api/iot/access/request and POST /api/iot/access/rfid
 * Enforces:
 *   - Device verification & House isolation
 *   - Card existence & Active status
 *   - Resident existence & Active account
 *   - Specific Room-based authorization in this house
 *   - Optional Facial Verification requirement check
 *   - Audit logging (AccessHistory) & Security alerts (SecurityEvent)
 *   - FAIL-CLOSED principle
 */
const handleAccessRequest = async (req, res, next) => {
  try {
    const card_uid = req.body.cardUid || req.body.card_uid;
    const device_identifier = req.body.deviceId || req.body.device_identifier;
    const room_id = req.body.roomId || req.body.room_id;
    const timestamp = req.body.timestamp || new Date();

    if (!card_uid || !device_identifier) {
      return res.status(400).json({
        success: false,
        authorized: false,
        granted: false,
        door_unlocked: false,
        reason: 'cardUid and deviceId are required.',
      });
    }

    // Step 1: Resolve Device & Enforce House Isolation
    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({
        success: false,
        authorized: false,
        granted: false,
        door_unlocked: false,
        reason: 'Device not recognized or not registered.',
      });
    }

    const houseId = device.house_id;
    const house = await House.findByPk(houseId);
    const targetRoomId = room_id || device.room_id || null;

    let targetRoom = null;
    if (targetRoomId) {
      targetRoom = await Room.findOne({ where: { id: targetRoomId, house_id: houseId } });
    }

    const formattedUid = card_uid.trim().toUpperCase();

    // Step 2: Query RFID Card for this House
    const card = await RfidCard.findOne({
      where: { house_id: houseId, card_uid: formattedUid },
      include: [
        {
          model: Resident,
          as: 'resident',
          include: [
            { model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] },
            { model: FaceProfile, as: 'faceProfile' },
          ],
        },
      ],
    });

    const io = req.app.get('io');

    // Case 2A: Unknown RFID Card -> FAIL CLOSED
    if (!card) {
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId,
        device_id: device.id,
        access_method: 'RFID',
        status: 'DENIED',
        denial_reason: 'UNREGISTERED_CARD',
        metadata: { card_uid: formattedUid, device_identifier },
        timestamp,
      });

      await SecurityEvent.create({
        house_id: houseId,
        device_id: device.id,
        event_type: 'UNKNOWN_CARD_ATTEMPT',
        severity: 'MEDIUM',
        description: `Unauthorized access attempt with unknown RFID card [${formattedUid}] at ${device.name}.`,
        metadata: { card_uid: formattedUid, device_identifier },
        timestamp,
      });

      if (io) {
        io.to(`house_${houseId}`).emit('access_attempt', {
          houseId,
          method: 'RFID',
          status: 'DENIED',
          cardUid: formattedUid,
          reason: 'Unregistered RFID card',
          roomName: targetRoom ? targetRoom.name : 'Entrance',
          timestamp,
        });
      }

      return res.status(403).json({
        success: true,
        authorized: false,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Unregistered RFID card.',
      });
    }

    // Case 2B: Inactive / Disabled RFID Card -> FAIL CLOSED
    if (card.status !== 'ACTIVE') {
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId,
        device_id: device.id,
        resident_id: card.resident_id,
        rfid_card_id: card.id,
        access_method: 'RFID',
        status: 'DENIED',
        denial_reason: `CARD_${card.status}`,
        metadata: { card_uid: formattedUid, card_status: card.status },
        timestamp,
      });

      await SecurityEvent.create({
        house_id: houseId,
        device_id: device.id,
        resident_id: card.resident_id,
        event_type: 'DISABLED_CARD_ATTEMPT',
        severity: 'MEDIUM',
        description: `Access attempt using deactivated card [${card.label || formattedUid}] at ${device.name}.`,
        timestamp,
      });

      if (io) {
        io.to(`house_${houseId}`).emit('access_attempt', {
          houseId,
          method: 'RFID',
          status: 'DENIED',
          cardUid: formattedUid,
          reason: `Card is ${card.status.toLowerCase()}`,
          roomName: targetRoom ? targetRoom.name : 'Entrance',
          timestamp,
        });
      }

      return res.status(403).json({
        success: true,
        authorized: false,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: `RFID card is ${card.status.toLowerCase()}.`,
      });
    }

    // Step 3: Check Resident Account Validity
    const resident = card.resident;
    if (card.resident_id && (!resident || !resident.is_active)) {
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId,
        device_id: device.id,
        resident_id: card.resident_id,
        rfid_card_id: card.id,
        access_method: 'RFID',
        status: 'DENIED',
        denial_reason: 'INACTIVE_ACCOUNT',
        timestamp,
      });

      return res.status(403).json({
        success: true,
        authorized: false,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Resident account is deactivated or unauthorized.',
      });
    }

    // Step 4: Room-Based Access Authorization
    if (targetRoom && resident) {
      const roomPermission = await RoomPermission.findOne({
        where: { house_id: houseId, room_id: targetRoom.id, resident_id: resident.id },
      });

      let roomAllowed = true;
      let denyReason = null;

      if (roomPermission) {
        if (!roomPermission.is_active || !roomPermission.can_access) {
          roomAllowed = false;
          denyReason = 'ROOM_PERMISSION_DENIED';
        }
      } else if (targetRoom.is_restricted) {
        roomAllowed = false;
        denyReason = 'RESTRICTED_ROOM_NO_PERMISSION';
      }

      if (!roomAllowed) {
        await AccessHistory.create({
          house_id: houseId,
          room_id: targetRoom.id,
          device_id: device.id,
          resident_id: resident.id,
          rfid_card_id: card.id,
          access_method: 'RFID',
          status: 'DENIED',
          denial_reason: denyReason,
          timestamp,
        });

        await SecurityEvent.create({
          house_id: houseId,
          device_id: device.id,
          resident_id: resident.id,
          event_type: 'UNAUTHORIZED_ROOM_ACCESS',
          severity: 'LOW',
          description: `Resident ${resident.user ? resident.user.first_name : ''} denied entry to restricted room [${targetRoom.name}].`,
          timestamp,
        });

        if (io) {
          io.to(`house_${houseId}`).emit('access_attempt', {
            houseId,
            method: 'RFID',
            status: 'DENIED',
            cardUid: formattedUid,
            reason: `Restricted room: ${targetRoom.name}`,
            roomName: targetRoom.name,
            timestamp,
          });
        }

        return res.status(403).json({
          success: true,
          authorized: false,
          granted: false,
          status: 'DENIED',
          door_unlocked: false,
          reason: `Access to ${targetRoom.name} is restricted for this resident.`,
        });
      }
    }

    const residentName = resident?.user
      ? `${resident.user.first_name} ${resident.user.last_name}`
      : (card.label || 'Authorized Resident');

    // Step 5: Check if Facial Verification is required
    const requiresFace = (house && house.require_face_verification) ||
                         (resident && resident.faceProfile && resident.faceProfile.is_active && house?.access_control_mode === 'STRICT_BIOMETRIC');

    if (requiresFace) {
      return res.status(200).json({
        success: true,
        authorized: true,
        granted: false,
        requiresFaceVerification: true,
        residentId: resident ? resident.id : null,
        residentName,
        cardId: card.id,
        roomId: targetRoom ? targetRoom.id : null,
        deviceId: device.id,
        message: 'RFID verified. Facial verification required before door opens.',
      });
    }

    // Step 6: Final Access Granted (Direct RFID or Face not strictly required)
    card.last_used_at = new Date();
    await card.save();

    const unlockDuration = house?.door_open_duration_seconds || 5;

    const accessLog = await AccessHistory.create({
      house_id: houseId,
      room_id: targetRoom ? targetRoom.id : null,
      device_id: device.id,
      resident_id: resident ? resident.id : null,
      rfid_card_id: card.id,
      access_method: 'RFID',
      status: 'GRANTED',
      timestamp,
    });

    if (io) {
      io.to(`house_${houseId}`).emit('access_attempt', {
        houseId,
        method: 'RFID',
        status: 'GRANTED',
        cardUid: formattedUid,
        cardLabel: card.label,
        residentName,
        roomName: targetRoom ? targetRoom.name : 'Main Door',
        timestamp: accessLog.timestamp,
      });
    }

    return res.status(200).json({
      success: true,
      authorized: true,
      granted: true,
      status: 'GRANTED',
      door_unlocked: true,
      unlock_duration_seconds: unlockDuration,
      message: `Access granted. Welcome ${residentName}.`,
      data: {
        resident: resident ? { id: resident.id, name: residentName } : null,
        room: targetRoom ? { id: targetRoom.id, name: targetRoom.name } : null,
        card: { id: card.id, uid: card.card_uid, label: card.label },
        timestamp: accessLog.timestamp,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Alias for backward compatibility with ESP32 /access/rfid
 */
const handleRfidAccessAttempt = handleAccessRequest;

/**
 * 2. Facial Verification Final Decision Endpoint
 * Received from ESP32-CAM or Node.js workflow after RFID authorization.
 * Payload: { image (base64 or file), expectedResidentId, deviceId/device_identifier, roomId/room_id }
 */
const handleFaceVerification = async (req, res, next) => {
  try {
    const {
      image,
      imageBase64,
      image_base64,
      expectedResidentId,
      residentId,
      deviceId,
      device_identifier,
      roomId,
      room_id,
      timestamp = new Date(),
    } = req.body;

    const imgData = image || imageBase64 || image_base64;
    const targetResidentId = expectedResidentId || residentId;
    const devId = deviceId || device_identifier;
    const targetRoomId = roomId || room_id;

    if (!imgData) {
      return res.status(400).json({
        success: false,
        authorized: false,
        granted: false,
        door_unlocked: false,
        reason: 'Image data is required for facial verification.',
      });
    }

    const device = await resolveDevice(devId);
    if (!device) {
      return res.status(404).json({
        success: false,
        authorized: false,
        granted: false,
        door_unlocked: false,
        reason: 'Device not recognized.',
      });
    }

    const houseId = device.house_id;
    const house = await House.findByPk(houseId);

    // Call Python AI Facial Recognition Microservice
    const aiResult = await aiFacialService.verifyFace(imgData, targetResidentId);
    const io = req.app.get('io');

    // Case 2A: Face Not Recognized or Mismatched -> FAIL CLOSED
    if (!aiResult.recognized || (targetResidentId && aiResult.residentId !== targetResidentId)) {
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId || null,
        device_id: device.id,
        resident_id: targetResidentId || null,
        access_method: 'FACIAL_RECOGNITION',
        status: 'DENIED',
        denial_reason: 'FACIAL_VERIFICATION_FAILED',
        metadata: { confidence: aiResult.confidence, reason: aiResult.reason },
        timestamp,
      });

      await SecurityEvent.create({
        house_id: houseId,
        device_id: device.id,
        resident_id: targetResidentId || null,
        event_type: 'FACIAL_VERIFICATION_FAILURE',
        severity: 'MEDIUM',
        description: `Facial verification failed at ${device.name}. Face did not match authorized resident.`,
        metadata: { confidence: aiResult.confidence },
        timestamp,
      });

      if (io) {
        io.to(`house_${houseId}`).emit('access_attempt', {
          houseId,
          method: 'FACIAL_RECOGNITION',
          status: 'DENIED',
          reason: 'Facial verification failed',
          timestamp,
        });
      }

      return res.status(403).json({
        success: true,
        authorized: false,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        confidence: aiResult.confidence,
        reason: aiResult.reason || 'Facial verification failed. Door remains closed.',
      });
    }

    // Case 2B: Facial Match Confirmed -> ACCESS GRANTED
    const resident = await Resident.findOne({
      where: { id: targetResidentId || aiResult.residentId, house_id: houseId },
      include: [{ model: User, as: 'user', attributes: ['first_name', 'last_name'] }],
    });

    const residentName = resident?.user
      ? `${resident.user.first_name} ${resident.user.last_name}`
      : 'Authorized Resident';

    const accessLog = await AccessHistory.create({
      house_id: houseId,
      room_id: targetRoomId || null,
      device_id: device.id,
      resident_id: resident ? resident.id : null,
      access_method: 'FACIAL_RECOGNITION',
      status: 'GRANTED',
      metadata: { confidence: aiResult.confidence },
      timestamp,
    });

    const unlockDuration = house?.door_open_duration_seconds || 5;

    if (io) {
      io.to(`house_${houseId}`).emit('access_attempt', {
        houseId,
        method: 'FACIAL_RECOGNITION',
        status: 'GRANTED',
        residentName,
        confidence: aiResult.confidence,
        timestamp: accessLog.timestamp,
      });
    }

    return res.status(200).json({
      success: true,
      authorized: true,
      granted: true,
      status: 'GRANTED',
      door_unlocked: true,
      unlock_duration_seconds: unlockDuration,
      confidence: aiResult.confidence,
      residentName,
      message: `Facial verification confirmed for ${residentName}. Access granted.`,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 3. Direct Face Embedding Access Attempt Endpoint (Mathematical Vector from edge)
 */
const handleFaceAccessAttempt = async (req, res, next) => {
  try {
    const { face_embedding, device_identifier, room_id, timestamp = new Date() } = req.body;

    if (!face_embedding || !device_identifier) {
      return res.status(400).json({
        success: false,
        granted: false,
        door_unlocked: false,
        reason: 'face_embedding vector and device_identifier are required.',
      });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, reason: 'Device not recognized.' });
    }

    const houseId = device.house_id;
    const targetRoomId = room_id || device.room_id || null;

    const activeProfiles = await FaceProfile.findAll({
      where: { house_id: houseId, is_active: true },
      include: [
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name'] }],
        },
      ],
    });

    let matchedProfile = null;
    let minDistance = 1.0;
    const MATCH_THRESHOLD = 0.45;

    for (const profile of activeProfiles) {
      if (profile.face_embedding) {
        try {
          const registeredVec = typeof profile.face_embedding === 'string'
            ? JSON.parse(profile.face_embedding)
            : profile.face_embedding;

          const dist = calculateFaceDistance(face_embedding, registeredVec);
          if (dist < minDistance) {
            minDistance = dist;
            if (dist <= MATCH_THRESHOLD) {
              matchedProfile = profile;
            }
          }
        } catch (_) {}
      }
    }

    if (!matchedProfile || !matchedProfile.resident || !matchedProfile.resident.is_active) {
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId,
        device_id: device.id,
        access_method: 'FACE_EMBEDDING',
        status: 'DENIED',
        denial_reason: 'UNRECOGNIZED_FACE',
        metadata: { minDistance },
        timestamp,
      });

      return res.status(403).json({
        success: true,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Unrecognized face. Access denied.',
      });
    }

    const resident = matchedProfile.resident;
    const residentName = resident.user ? `${resident.user.first_name} ${resident.user.last_name}` : 'Resident';

    matchedProfile.last_verified_at = new Date();
    await matchedProfile.save();

    await AccessHistory.create({
      house_id: houseId,
      room_id: targetRoomId,
      device_id: device.id,
      resident_id: resident.id,
      access_method: 'FACE_EMBEDDING',
      status: 'GRANTED',
      metadata: { distance: minDistance },
      timestamp,
    });

    return res.status(200).json({
      success: true,
      granted: true,
      status: 'GRANTED',
      door_unlocked: true,
      unlock_duration_seconds: 5,
      message: `Face recognized: ${residentName}. Access granted.`,
      data: { resident: { id: resident.id, name: residentName }, distance: minDistance },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 4. General Security & Presence Event Ingestion
 */
const handleIoTEvent = async (req, res, next) => {
  try {
    const {
      device_identifier,
      event_type = 'SECURITY_ALERT',
      room_id,
      is_verified_threat = false,
      severity = 'LOW',
      metadata = {},
      timestamp = new Date(),
    } = req.body;

    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier is required.' });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    const houseId = device.house_id;
    const house = await House.findByPk(houseId);

    const securityEvent = await SecurityEvent.create({
      house_id: houseId,
      device_id: device.id,
      room_id: room_id || device.room_id || null,
      event_type,
      severity: is_verified_threat ? 'CRITICAL' : severity,
      description: `Security event [${event_type}] captured by ${device.name}.`,
      metadata: { ...metadata, device_identifier },
      timestamp,
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('security_alert', {
        houseId,
        event: securityEvent,
      });
    }

    return res.status(200).json({
      success: true,
      event_id: securityEvent.id,
      message: 'Security event recorded.',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 5. Device Heartbeat
 */
const handleDeviceHeartbeat = async (req, res, next) => {
  try {
    const { device_identifier, status = 'ONLINE', ip_address, firmware_version } = req.body;

    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier is required.' });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    device.status = status;
    device.last_heartbeat_at = new Date();
    if (ip_address) device.ip_address = ip_address;
    if (firmware_version) device.firmware_version = firmware_version;
    await device.save();

    return res.status(200).json({
      success: true,
      message: 'Heartbeat acknowledged.',
      data: {
        device_identifier,
        status: device.status,
        last_heartbeat_at: device.last_heartbeat_at,
        server_time: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 6. Door Status Query
 */
const handleGetDoorStatus = async (req, res, next) => {
  try {
    const { device_identifier } = req.params;
    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    return res.status(200).json({
      success: true,
      device_identifier: device.device_identifier,
      is_locked: true,
      door_state: 'CLOSED',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 7. Device Startup Configuration
 */
const handleGetDeviceConfig = async (req, res, next) => {
  try {
    const { device_identifier } = req.params;
    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    const house = await House.findByPk(device.house_id);

    return res.status(200).json({
      success: true,
      device_identifier: device.device_identifier,
      house_id: device.house_id,
      name: device.name,
      type: device.type,
      servo_open_duration: house?.door_open_duration_seconds || 5,
      require_face_verification: house?.require_face_verification || false,
      security_status: house?.security_status || 'DISARMED',
      heartbeat_interval_seconds: 30,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 8. Emergency Panic Trigger
 */
const handleEmergencyTrigger = async (req, res, next) => {
  try {
    const { device_identifier, emergency_type = 'PANIC_BUTTON', notes } = req.body;
    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    const emergencyEvent = await dispatchEmergency({
      houseId: device.house_id,
      source: 'HARDWARE_TRIGGER',
      notes: notes || `Hardware panic triggered by ${device.name}.`,
      io: req.app.get('io'),
    });

    return res.status(200).json({
      success: true,
      emergency_id: emergencyEvent.id,
      status: emergencyEvent.status,
      message: 'Emergency alert dispatched to authorities.',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  handleAccessRequest,
  handleRfidAccessAttempt,
  handleFaceVerification,
  handleFaceAccessAttempt,
  handleIoTEvent,
  handleDeviceHeartbeat,
  handleGetDoorStatus,
  handleGetDeviceConfig,
  handleEmergencyTrigger,
};
