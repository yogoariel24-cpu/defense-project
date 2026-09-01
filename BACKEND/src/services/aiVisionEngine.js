/**
 * ============================================================================
 * VIGILIS AI VISION & MULTI-OBJECT RECOGNITION ENGINE
 * ============================================================================
 * Free, embedded Edge-AI Engine performing:
 *  1. Facial Recognition & Verification (OpenCV / FaceProfile Biometric Vector Matching)
 *  2. Multi-Class Object Recognition (Differentiating Humans, Animals, Vehicles, Packages)
 *  3. Automated False-Alarm Filtering & Threat Scoring
 * ============================================================================
 */

const { FaceProfile, SecurityEvent, AIAnalysis, House, Notification, User, Resident, ActivityLog } = require('../models');
const { dispatchEmergency } = require('./emergencyService');
const { sendUnrecognizedFaceAlert } = require('./emailService');

// Supported Object Classes in Free COCO-SSD / MobileNet AI Vision Model
const OBJECT_CLASSES = {
  HUMAN: ['person', 'human', 'pedestrian', 'intruder'],
  ANIMAL: ['dog', 'cat', 'bird', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'animal'],
  VEHICLE: ['car', 'motorcycle', 'bicycle', 'bus', 'truck', 'van'],
  PACKAGE: ['backpack', 'umbrella', 'handbag', 'suitcase', 'box', 'package'],
};

/**
 * Calculates Euclidean biometric vector distance between two face embeddings.
 */
const calculateFaceDistance = (vecA, vecB) => {
  if (!Array.isArray(vecA) || !Array.isArray(vecB) || vecA.length !== vecB.length) {
    return 1.0;
  }
  let sum = 0;
  for (let i = 0; i < vecA.length; i++) {
    sum += Math.pow(vecA[i] - vecB[i], 2);
  }
  return Math.sqrt(sum);
};

/**
 * Classifies raw detection labels into high-level categories (HUMAN, ANIMAL, VEHICLE, PACKAGE).
 */
const classifyDetectedObject = (label = 'person') => {
  const clean = label.toLowerCase().trim();
  for (const [category, synonyms] of Object.entries(OBJECT_CLASSES)) {
    if (synonyms.some((s) => clean.includes(s))) {
      return category;
    }
  }
  return 'UNKNOWN_OBJECT';
};

/**
 * Main Vision Analysis Pipeline:
 * Evaluates camera stream snapshots, runs facial comparison against registered house residents,
 * and performs multi-class object recognition.
 */
const processVisionTelemetry = async ({
  houseId,
  securityEventId,
  detectedObjectLabel = 'person',
  objectConfidence = 0.95,
  hasFace = true,
  faceConfidence = 0.92,
  incomingEmbedding = null,
  cameraName = 'Front Perimeter Camera',
  imageUrl = null,
  io = null,
}) => {
  const house = await House.findByPk(houseId, {
    include: [{ model: require('../models').Homeowner, as: 'homeowner', include: [{ model: User, as: 'user' }] }],
  });

  if (!house) throw new Error(`House '${houseId}' not found.`);

  // 1. Multi-Class Object Classification
  const objectCategory = classifyDetectedObject(detectedObjectLabel);
  const isHuman = objectCategory === 'HUMAN';
  const isAnimal = objectCategory === 'ANIMAL';
  const isVehicle = objectCategory === 'VEHICLE';

  // 2. Facial Recognition with OpenCV / Registered FaceProfiles
  const registeredProfiles = await FaceProfile.findAll({
    where: { house_id: houseId, is_active: true },
    include: [{ model: Resident, as: 'resident', include: [{ model: User, as: 'user' }] }],
  });

  let matchResult = 'NO_FACE';
  let matchedResidentId = null;
  let matchedResidentName = null;
  let minDistance = 1.0;

  if (isHuman && hasFace) {
    matchResult = 'UNKNOWN'; // Default to unknown until verified
    if (incomingEmbedding && registeredProfiles.length > 0) {
      for (const profile of registeredProfiles) {
        if (profile.face_embedding) {
          try {
            const registeredVec = JSON.parse(profile.face_embedding);
            const dist = calculateFaceDistance(incomingEmbedding, registeredVec);
            if (dist < minDistance) {
              minDistance = dist;
              if (dist < 0.45) {
                matchResult = 'AUTHORIZED';
                matchedResidentId = profile.resident_id;
                matchedResidentName = profile.resident?.user?.first_name ? `${profile.resident.user.first_name} ${profile.resident.user.last_name}` : 'Resident';
              } else if (dist < 0.65) {
                matchResult = 'UNCERTAIN';
              }
            }
          } catch (e) {
            console.error('Error parsing face vector embedding:', e.message);
          }
        }
      }
    }
  }

  // 3. Compute Risk Score & Threat Level
  let riskScore = 0;
  const isSecurityArmed = house.security_status === 'ARMED_AWAY' || house.security_status === 'ARMED_HOME';
  const currentHour = new Date().getHours();
  const isNightTime = currentHour >= 22 || currentHour <= 5;

  if (isAnimal) {
    // Animals are harmless movement -> 0% Risk, prevents false alarms
    riskScore = 5;
  } else if (isVehicle) {
    riskScore = isSecurityArmed ? 35 : 15;
  } else if (isHuman) {
    riskScore = 20;
    if (isSecurityArmed) riskScore += 40;
    if (isNightTime) riskScore += 15;

    if (matchResult === 'AUTHORIZED') {
      riskScore = 5; // Verified family member
    } else if (matchResult === 'UNKNOWN') {
      riskScore += 25; // Unknown stranger / potential intruder
    }
  }

  let threatLevel = 'NORMAL';
  if (riskScore >= 70 && isSecurityArmed && matchResult !== 'AUTHORIZED') {
    threatLevel = 'CONFIRMED_THREAT';
  } else if (riskScore >= 45) {
    threatLevel = 'SUSPICIOUS';
  }

  // 4. Save AI Analysis Record
  const aiRecord = await AIAnalysis.create({
    security_event_id: securityEventId,
    house_id: houseId,
    person_detected: isHuman,
    person_confidence: isHuman ? objectConfidence : 0,
    face_detected: hasFace,
    face_confidence: hasFace ? faceConfidence : 0,
    matched_resident_id: matchedResidentId,
    face_recognition_result: matchResult,
    threat_level: threatLevel,
    risk_score: riskScore,
    raw_details: {
      objectCategory,
      detectedObjectLabel,
      isAnimal,
      isVehicle,
      isSecurityArmed,
      isNightTime,
      minVectorDistance: minDistance,
      evaluatedAt: new Date().toISOString(),
    },
  });

  // 5. Update Security Event Record
  const securityEvent = await SecurityEvent.findByPk(securityEventId);
  if (securityEvent) {
    securityEvent.status = threatLevel === 'CONFIRMED_THREAT' ? 'CONFIRMED_THREAT' : (threatLevel === 'SUSPICIOUS' ? 'INVESTIGATING' : 'NORMAL');
    securityEvent.severity = threatLevel === 'CONFIRMED_THREAT' ? 'CRITICAL' : (threatLevel === 'SUSPICIOUS' ? 'HIGH' : 'LOW');
    securityEvent.description = isAnimal
      ? `Harmless animal movement detected (${detectedObjectLabel}). False alarm averted.`
      : (matchResult === 'AUTHORIZED'
          ? `Authorized resident verified: ${matchedResidentName}`
          : (matchResult === 'UNKNOWN'
              ? `🚨 UNRECOGNIZED PERSON DETECTED by ${cameraName}. Face does not match registered profiles.`
              : `Motion activity recorded (${detectedObjectLabel})`));
    await securityEvent.save();
  }

  // 6. Handle Unrecognized Face Notifications (In-App + Email + Socket)
  if (isHuman && matchResult === 'UNKNOWN') {
    const homeownerUser = house.homeowner?.user;
    
    // A. In-App Notification
    await Notification.create({
      house_id: houseId,
      user_id: homeownerUser?.id || null,
      type: 'SECURITY_ALERT',
      title: '⚠️ Unrecognized Face Detected',
      message: `An unknown person was detected at ${cameraName}. Risk Score: ${riskScore}%.`,
      data: {
        security_event_id: securityEventId,
        threat_level: threatLevel,
        risk_score: riskScore,
        camera_name: cameraName,
      },
    }).catch(() => {});

    // B. Send Email Alert via Google SMTP
    if (homeownerUser?.email) {
      sendUnrecognizedFaceAlert({
        email: homeownerUser.email,
        name: homeownerUser.first_name,
        houseName: house.name,
        cameraName,
        time: new Date(),
        riskScore,
      });
    }

    // C. Real-time WebSocket Alert
    if (io) {
      io.to(`house_${houseId}`).emit('unknown_face_alert', {
        houseId,
        securityEventId,
        cameraName,
        riskScore,
        threatLevel,
        message: 'Unrecognized face detected by AI Vision Radar.',
      });
    }
  }

  // 7. Automatic Emergency Escalation for Confirmed Threats
  if (threatLevel === 'CONFIRMED_THREAT') {
    console.log(`🚨 [AI THREAT ENGINE] Confirmed Intruder Detected for ${houseId}! Auto-dispatching emergency...`);
    await dispatchEmergency({
      houseId,
      securityEventId,
      source: 'AUTOMATIC_AI',
      notes: `Intruder Alert: Unknown face detected by ${cameraName} with ${riskScore}% risk score while security was ${house.security_status}.`,
      io,
    });
  }

  return {
    aiRecord,
    objectCategory,
    matchResult,
    threatLevel,
    riskScore,
  };
};

module.exports = {
  processVisionTelemetry,
  classifyDetectedObject,
  calculateFaceDistance,
};
