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
  SmartLight,
  LightSensor,
  MotionSensor,
  Camera,
  EmergencyEvent,
} = require('../models');
const { calculateFaceDistance } = require('../services/aiVisionEngine');
const { dispatchEmergency } = require('../services/emergencyService');

/**
 * Resolves a device by its identifier and verifies its house association.
 */
const resolveDevice = async (device_identifier) => {
  if (!device_identifier) return null;
  const device = await Device.findOne({ where: { device_identifier } });
  if (device) {
    device.last_heartbeat_at = new Date();
    device.status = 'ONLINE';
    await device.save().catch(() => {});
  }
  return device;
};

/**
 * 1. RFID Access Attempt Endpoint
 * Received from RFID reader IoT device.
 * Payload: { card_uid, device_identifier, room_id?, timestamp? }
 */
const handleRfidAccessAttempt = async (req, res, next) => {
  try {
    const { card_uid, device_identifier, room_id, timestamp = new Date() } = req.body;

    if (!card_uid || !device_identifier) {
      return res.status(400).json({
        success: false,
        granted: false,
        door_unlocked: false,
        reason: 'card_uid and device_identifier are required.',
      });
    }

    // 1. Enforce Device Ownership & House Isolation
    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({
        success: false,
        granted: false,
        door_unlocked: false,
        reason: 'Device not recognized or not registered.',
      });
    }

    const houseId = device.house_id;
    const targetRoomId = room_id || device.room_id || null;

    let targetRoom = null;
    if (targetRoomId) {
      targetRoom = await Room.findOne({ where: { id: targetRoomId, house_id: houseId } });
    }

    // 2. Enforce RFID Ownership & Validity
    const formattedUid = card_uid.trim().toUpperCase();
    const card = await RfidCard.findOne({
      where: { house_id: houseId, card_uid: formattedUid },
      include: [
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }],
        },
      ],
    });

    if (!card) {
      // Unknown RFID Card
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

      return res.status(403).json({
        success: true,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Unregistered RFID card.',
      });
    }

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

      return res.status(403).json({
        success: true,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: `RFID card is ${card.status.toLowerCase()}.`,
      });
    }

    // 3. Check Resident Status & Account Active
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
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Resident account is deactivated or unauthorized.',
      });
    }

    // 4. Enforce Dynamic Room-Based Permissions from Database
    if (targetRoom && resident) {
      const roomPermission = await RoomPermission.findOne({
        where: { house_id: houseId, room_id: targetRoom.id, resident_id: resident.id },
      });

      if (roomPermission) {
        if (!roomPermission.is_active || !roomPermission.can_access) {
          await AccessHistory.create({
            house_id: houseId,
            room_id: targetRoom.id,
            device_id: device.id,
            resident_id: resident.id,
            rfid_card_id: card.id,
            access_method: 'RFID',
            status: 'DENIED',
            denial_reason: 'ROOM_PERMISSION_DENIED',
            timestamp,
          });

          return res.status(403).json({
            success: true,
            granted: false,
            status: 'DENIED',
            door_unlocked: false,
            reason: `Access to ${targetRoom.name} is restricted for this resident.`,
          });
        }
      } else if (targetRoom.is_restricted) {
        // Room is restricted and no explicit permission granted in DB
        await AccessHistory.create({
          house_id: houseId,
          room_id: targetRoom.id,
          device_id: device.id,
          resident_id: resident.id,
          rfid_card_id: card.id,
          access_method: 'RFID',
          status: 'DENIED',
          denial_reason: 'RESTRICTED_ROOM_NO_PERMISSION',
          timestamp,
        });

        return res.status(403).json({
          success: true,
          granted: false,
          status: 'DENIED',
          door_unlocked: false,
          reason: `Access to restricted room ${targetRoom.name} requires explicit permission.`,
        });
      }
    }

    // 5. Access Granted: Unlock door and record history
    card.last_used_at = new Date();
    await card.save();

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

    const residentName = resident?.user
      ? `${resident.user.first_name} ${resident.user.last_name}`
      : card.label;

    // Real-time broadcast to Flutter dashboard
    const io = req.app.get('io');
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
      granted: true,
      status: 'GRANTED',
      door_unlocked: true,
      unlock_duration_seconds: 5,
      message: `Access granted. Door unlocked for ${residentName}.`,
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
 * 2. Facial Recognition with Face Embedding Access Attempt Endpoint
 * Received from edge camera/IoT node.
 * Evaluates face embedding vector against registered resident embeddings.
 * Unlocks door if: recognized face + registered resident + authorized active account + room permission.
 * Payload: { face_embedding, device_identifier, room_id?, timestamp? }
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

    if (!Array.isArray(face_embedding)) {
      return res.status(400).json({
        success: false,
        granted: false,
        door_unlocked: false,
        reason: 'face_embedding must be a numerical vector array.',
      });
    }

    // 1. Enforce Device Ownership & House Isolation
    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({
        success: false,
        granted: false,
        door_unlocked: false,
        reason: 'Device not recognized or not registered.',
      });
    }

    const houseId = device.house_id;
    const targetRoomId = room_id || device.room_id || null;

    let targetRoom = null;
    if (targetRoomId) {
      targetRoom = await Room.findOne({ where: { id: targetRoomId, house_id: houseId } });
    }

    // 2. Query Registered Residents & Face Profiles for this House
    const activeProfiles = await FaceProfile.findAll({
      where: { house_id: houseId, is_active: true },
      include: [
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }],
        },
      ],
    });

    let matchedProfile = null;
    let minDistance = 1.0;
    const MATCH_THRESHOLD = 0.45; // Euclidean biometric distance threshold

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

    // 3. Face match evaluation
    if (!matchedProfile) {
      // Unrecognized face
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId,
        device_id: device.id,
        access_method: 'FACE_EMBEDDING',
        status: 'DENIED',
        denial_reason: 'UNRECOGNIZED_FACE',
        metadata: { minDistance, device_identifier },
        timestamp,
      });

      return res.status(403).json({
        success: true,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Unrecognized face. Access denied.',
        data: { minDistance },
      });
    }

    // 4. Resident Active Account Check
    const resident = matchedProfile.resident;
    if (!resident || !resident.is_active) {
      await AccessHistory.create({
        house_id: houseId,
        room_id: targetRoomId,
        device_id: device.id,
        resident_id: resident ? resident.id : null,
        access_method: 'FACE_EMBEDDING',
        status: 'DENIED',
        denial_reason: 'INACTIVE_ACCOUNT',
        metadata: { minDistance },
        timestamp,
      });

      return res.status(403).json({
        success: true,
        granted: false,
        status: 'DENIED',
        door_unlocked: false,
        reason: 'Resident account is deactivated.',
      });
    }

    // 5. Room-Based Permission Check
    if (targetRoom) {
      const roomPermission = await RoomPermission.findOne({
        where: { house_id: houseId, room_id: targetRoom.id, resident_id: resident.id },
      });

      if (roomPermission) {
        if (!roomPermission.is_active || !roomPermission.can_access) {
          await AccessHistory.create({
            house_id: houseId,
            room_id: targetRoom.id,
            device_id: device.id,
            resident_id: resident.id,
            access_method: 'FACE_EMBEDDING',
            status: 'DENIED',
            denial_reason: 'ROOM_PERMISSION_DENIED',
            metadata: { minDistance },
            timestamp,
          });

          return res.status(403).json({
            success: true,
            granted: false,
            status: 'DENIED',
            door_unlocked: false,
            reason: `Access to ${targetRoom.name} is restricted for this resident.`,
          });
        }
      } else if (targetRoom.is_restricted) {
        await AccessHistory.create({
          house_id: houseId,
          room_id: targetRoom.id,
          device_id: device.id,
          resident_id: resident.id,
          access_method: 'FACE_EMBEDDING',
          status: 'DENIED',
          denial_reason: 'RESTRICTED_ROOM_NO_PERMISSION',
          metadata: { minDistance },
          timestamp,
        });

        return res.status(403).json({
          success: true,
          granted: false,
          status: 'DENIED',
          door_unlocked: false,
          reason: `Access to restricted room ${targetRoom.name} requires explicit permission.`,
        });
      }
    }

    // 6. Access Granted: Unlock door and record history
    matchedProfile.last_verified_at = new Date();
    await matchedProfile.save();

    const accessLog = await AccessHistory.create({
      house_id: houseId,
      room_id: targetRoom ? targetRoom.id : null,
      device_id: device.id,
      resident_id: resident.id,
      access_method: 'FACE_EMBEDDING',
      status: 'GRANTED',
      metadata: { distance: minDistance },
      timestamp,
    });

    const residentName = resident.user
      ? `${resident.user.first_name} ${resident.user.last_name}`
      : 'Resident';

    // Real-time broadcast
    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('access_attempt', {
        houseId,
        method: 'FACE_EMBEDDING',
        status: 'GRANTED',
        residentName,
        roomName: targetRoom ? targetRoom.name : 'Main Door',
        timestamp: accessLog.timestamp,
      });
    }

    return res.status(200).json({
      success: true,
      granted: true,
      status: 'GRANTED',
      door_unlocked: true,
      unlock_duration_seconds: 5,
      message: `Face recognized: ${residentName}. Door unlocked automatically.`,
      data: {
        resident: { id: resident.id, name: residentName },
        room: targetRoom ? { id: targetRoom.id, name: targetRoom.name } : null,
        distance: minDistance,
        timestamp: accessLog.timestamp,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 3. IoT Presence / Sensor Event Ingestion Endpoint
 * Receives presence detections, motion events, or verified security alerts.
 * Architectural principle: Detection != Verified Threat.
 * Only genuine threats reach VERIFIED_THREAT status and automatically trigger the emergency response.
 * Payload: { device_identifier, event_type, room_id?, is_verified_threat?, severity?, metadata?, timestamp? }
 */
const handleIoTEvent = async (req, res, next) => {
  try {
    const {
      device_identifier,
      event_type = 'PRESENCE_DETECTED',
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
      return res.status(404).json({ success: false, message: 'Device not recognized or not registered.' });
    }

    const houseId = device.house_id;
    const house = await House.findByPk(houseId, {
      include: [{ model: require('../models').Homeowner, as: 'homeowner', include: [{ model: User, as: 'user' }] }],
    });

    if (!house) {
      return res.status(404).json({ success: false, message: 'House not found.' });
    }

    const targetRoomId = room_id || device.room_id || null;
    let targetRoom = null;
    if (targetRoomId) {
      targetRoom = await Room.findOne({ where: { id: targetRoomId, house_id: houseId } });
    }

    const isArmed = house.security_status === 'ARMED_AWAY' || house.security_status === 'ARMED_HOME';

    // Determine status: Detection != Confirmed Threat
    // A presence event alone is standard 'DETECTED' / 'LOGGED'.
    // Only genuine verified threats (e.g. system is armed and verified threat confirmed) reach VERIFIED_THREAT!
    let threatStatus = 'DETECTED';
    let isGenuineThreat = Boolean(is_verified_threat);

    if (isArmed && (event_type === 'DOOR_TAMPER' || event_type === 'INTRUSION_ALARM')) {
      isGenuineThreat = true;
    }

    let securityEvent = null;
    const io = req.app.get('io');

    if (isGenuineThreat) {
      threatStatus = 'VERIFIED_THREAT';

      // Create high-priority SecurityEvent
      securityEvent = await SecurityEvent.create({
        house_id: houseId,
        device_id: device.id,
        event_type: event_type === 'PRESENCE_DETECTED' ? 'INTRUSION_ALARM' : event_type,
        severity: severity === 'LOW' ? 'HIGH' : severity,
        description: `🚨 VERIFIED THREAT: Genuine security breach detected by ${device.name} in ${targetRoom ? targetRoom.name : 'Perimeter'} during ${house.security_status}!`,
        status: 'CONFIRMED_THREAT',
      });

      // Automated security response: Automatically dispatch emergency WITHOUT requiring homeowner manual initiation!
      dispatchEmergency({
        houseId,
        securityEventId: securityEvent.id,
        source: 'AUTOMATIC_SECURITY_SYSTEM',
        notes: `Automated response triggered: Verified threat at ${device.name} (${targetRoom ? targetRoom.name : 'Perimeter'}).`,
        io,
      }).catch((err) => console.error('Automated emergency dispatch error:', err.message));

      // In-App Notification
      const homeownerUser = house.homeowner?.user;
      await Notification.create({
        house_id: houseId,
        user_id: homeownerUser?.id || null,
        type: 'SECURITY_ALERT',
        title: '🚨 VERIFIED SECURITY THREAT',
        message: securityEvent.description,
        data: {
          security_event_id: securityEvent.id,
          threat_status: threatStatus,
          room_id: targetRoomId,
          device_identifier,
        },
      }).catch(() => {});

      // Broadcast high-priority real-time threat alert
      if (io) {
        io.to(`house_${houseId}`).emit('security_threat_alert', {
          houseId,
          securityEventId: securityEvent.id,
          threatStatus: 'VERIFIED_THREAT',
          deviceName: device.name,
          roomName: targetRoom ? targetRoom.name : 'Perimeter',
          description: securityEvent.description,
          timestamp: new Date().toISOString(),
        });
      }
    } else {
      // Normal presence or telemetry detection
      threatStatus = 'DETECTED';

      if (io) {
        io.to(`house_${houseId}`).emit('iot_detection_event', {
          houseId,
          threatStatus: 'DETECTED',
          eventType: event_type,
          deviceName: device.name,
          roomName: targetRoom ? targetRoom.name : 'Living Space',
          metadata,
          timestamp: new Date().toISOString(),
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: isGenuineThreat ? 'Verified threat registered. Automated response dispatched.' : 'IoT event recorded.',
      data: {
        threatStatus,
        isVerifiedThreat: isGenuineThreat,
        eventType: event_type,
        deviceId: device.id,
        room: targetRoom ? { id: targetRoom.id, name: targetRoom.name } : null,
        securityEvent: securityEvent ? { id: securityEvent.id, status: securityEvent.status } : null,
        timestamp,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 4. Device Heartbeat
 * Payload: { device_identifier, status, ip_address, firmware_version }
 */
const handleDeviceHeartbeat = async (req, res, next) => {
  try {
    const { device_identifier, status = 'ONLINE', ip_address, firmware_version } = req.body;
    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier is required.' });
    }

    const device = await Device.findOne({ where: { device_identifier } });
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    device.status = status;
    device.last_heartbeat_at = new Date();
    if (ip_address) device.ip_address = ip_address;
    if (firmware_version) device.firmware_version = firmware_version;
    await device.save();

    res.status(200).json({
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
 * 5. Ambient Light Sensor Telemetry Endpoint
 * Received from ambient light sensor (e.g. BH1750, LDR on ESP32).
 * Payload: { device_identifier, current_lux, timestamp? }
 */
const handleLightSensorReading = async (req, res, next) => {
  try {
    const { device_identifier, current_lux, timestamp = new Date() } = req.body;

    if (!device_identifier || current_lux === undefined) {
      return res.status(400).json({
        success: false,
        message: 'device_identifier and current_lux are required.',
      });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized or not registered.' });
    }

    const houseId = device.house_id;
    let lightSensor = await LightSensor.findOne({ where: { device_id: device.id } });
    if (!lightSensor) {
      lightSensor = await LightSensor.create({
        device_id: device.id,
        house_id: houseId,
        location_name: device.name || 'Room Light Sensor',
        current_lux: parseFloat(current_lux),
        threshold_lux: 150.0,
      });
    } else {
      lightSensor.current_lux = parseFloat(current_lux);
      lightSensor.last_reading_at = timestamp;
      await lightSensor.save();
    }

    const house = await House.findByPk(houseId);
    const houseMode = house?.light_mode || 'AUTO';
    let shouldActivateLights = false;

    if (houseMode === 'AUTO') {
      if (lightSensor.current_lux < lightSensor.threshold_lux) {
        shouldActivateLights = true;
        await SmartLight.update({ is_on: true }, { where: { house_id: houseId, mode: 'AUTO' } });
      }
    }

    // Real-time broadcast to dashboard
    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('light_sensor_telemetry', {
        houseId,
        deviceIdentifier: device_identifier,
        currentLux: lightSensor.current_lux,
        thresholdLux: lightSensor.threshold_lux,
        mode: houseMode,
        shouldActivateLights,
        timestamp,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Light reading recorded.',
      data: {
        current_lux: lightSensor.current_lux,
        threshold_lux: lightSensor.threshold_lux,
        mode: houseMode,
        should_activate_lights: shouldActivateLights,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 6. Door Lock Status Query Endpoint
 * Queried by door lock actuators / ESP32 to verify lock state.
 * Param: :device_identifier
 */
const handleGetDoorStatus = async (req, res, next) => {
  try {
    const { device_identifier } = req.params;
    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier parameter is required.' });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    const targetRoomId = device.room_id || null;
    let roomName = 'Main Entrance';
    if (targetRoomId) {
      const room = await Room.findByPk(targetRoomId);
      if (room) roomName = room.name;
    }

    return res.status(200).json({
      success: true,
      device_identifier: device.device_identifier,
      room_name: roomName,
      is_locked: true,
      auto_relock_seconds: 10,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 7. Smart Light / Relay Commanded State Endpoint
 * Queried by smart relays / ESP32 to fetch desired state.
 * Param: :device_identifier
 */
const handleGetLightState = async (req, res, next) => {
  try {
    const { device_identifier } = req.params;
    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier parameter is required.' });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    let light = await SmartLight.findOne({ where: { device_id: device.id } });
    if (!light) {
      light = await SmartLight.findOne({ where: { house_id: device.house_id } });
    }

    if (!light) {
      return res.status(404).json({ success: false, message: 'No smart light found for this device.' });
    }

    return res.status(200).json({
      success: true,
      device_identifier: device.device_identifier,
      relay_pin: light.relay_pin || 23,
      is_on: light.is_on,
      brightness_percentage: light.brightness_percentage,
      mode: light.mode,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 8. Physical Switch State Sync Endpoint
 * Received when physical wall switch or hardware toggles the relay.
 * Payload: { device_identifier, is_on, brightness_percentage?, triggered_by? }
 */
const handleLightStateSync = async (req, res, next) => {
  try {
    const { device_identifier, is_on, brightness_percentage, triggered_by = 'PHYSICAL_WALL_SWITCH' } = req.body;

    if (!device_identifier || is_on === undefined) {
      return res.status(400).json({
        success: false,
        message: 'device_identifier and is_on are required.',
      });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    let light = await SmartLight.findOne({ where: { device_id: device.id } });
    if (!light) {
      light = await SmartLight.findOne({ where: { house_id: device.house_id } });
    }

    if (!light) {
      return res.status(404).json({ success: false, message: 'No smart light entity found for this device.' });
    }

    light.is_on = Boolean(is_on);
    if (brightness_percentage !== undefined && brightness_percentage >= 0 && brightness_percentage <= 100) {
      light.brightness_percentage = brightness_percentage;
    }
    await light.save();

    // Broadcast to Flutter app
    const io = req.app.get('io');
    if (io) {
      io.to(`house_${device.house_id}`).emit('lighting_update', {
        type: 'PHYSICAL_SYNC',
        light,
        triggered_by,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Light state synchronized.',
      data: {
        device_identifier,
        is_on: light.is_on,
        brightness_percentage: light.brightness_percentage,
        mode: light.mode,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 9. Device Boot & Startup Configuration Endpoint
 * Queried by ESP32 / cameras on power-up to fetch startup settings.
 * Param: :device_identifier
 */
const handleGetDeviceConfig = async (req, res, next) => {
  try {
    const { device_identifier } = req.params;
    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier parameter is required.' });
    }

    const device = await Device.findOne({
      where: { device_identifier },
      include: [
        { model: Room, as: 'room' },
        { model: SmartLight, as: 'smartLight' },
        { model: MotionSensor, as: 'motionSensor' },
        { model: LightSensor, as: 'lightSensor' },
        { model: Camera, as: 'camera' },
      ],
    });

    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    device.status = 'ONLINE';
    device.last_heartbeat_at = new Date();
    await device.save().catch(() => {});

    const config = {};
    if (device.smartLight) {
      config.relay_pin = device.smartLight.relay_pin;
      config.is_on = device.smartLight.is_on;
      config.brightness_percentage = device.smartLight.brightness_percentage;
    }
    if (device.motionSensor) {
      config.sensitivity = device.motionSensor.sensitivity;
    }
    if (device.lightSensor) {
      config.threshold_lux = device.lightSensor.threshold_lux;
    }
    if (device.camera) {
      config.stream_url = device.camera.stream_url;
    }

    return res.status(200).json({
      success: true,
      device_identifier: device.device_identifier,
      house_id: device.house_id,
      name: device.name,
      type: device.type,
      room_name: device.room ? device.room.name : null,
      heartbeat_interval_seconds: 30,
      config,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 10. Physical Panic Button / Smoke / Gas Detector Emergency Trigger Endpoint
 * Received from wall panic button or safety detector.
 * Payload: { device_identifier, emergency_type?, notes? }
 */
const handleEmergencyTrigger = async (req, res, next) => {
  try {
    const { device_identifier, emergency_type = 'PANIC_BUTTON', notes } = req.body;

    if (!device_identifier) {
      return res.status(400).json({ success: false, message: 'device_identifier is required.' });
    }

    const device = await resolveDevice(device_identifier);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not recognized.' });
    }

    const houseId = device.house_id;
    const io = req.app.get('io');
    const emergencyNotes = notes || `Hardware trigger: ${emergency_type} activated at device ${device.name}.`;

    const emergencyEvent = await dispatchEmergency({
      houseId,
      source: 'EXTERNAL_TRIGGER',
      notes: emergencyNotes,
      io,
    });

    return res.status(200).json({
      success: true,
      emergency_id: emergencyEvent.id,
      status: emergencyEvent.status,
      message: 'Emergency alert triggered and emergency contacts notified.',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  handleRfidAccessAttempt,
  handleFaceAccessAttempt,
  handleIoTEvent,
  handleDeviceHeartbeat,
  handleLightSensorReading,
  handleGetDoorStatus,
  handleGetLightState,
  handleLightStateSync,
  handleGetDeviceConfig,
  handleEmergencyTrigger,
};
