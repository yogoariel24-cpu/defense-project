const { FaceProfile, SecurityEvent, AIAnalysis, House, Notification, User, Resident } = require('../models');
const { dispatchEmergency } = require('./emergencyService');

/**
 * Calculates Euclidean distance between two biometric float vectors.
 */
const calculateVectorDistance = (vecA, vecB) => {
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
 * Evaluates camera capture & sensor telemetry to perform face identification and threat analysis.
 * Pure Node.js implementation without Python dependency.
 */
const analyzeThreatAndBiometrics = async ({
  houseId,
  securityEventId,
  hasPerson = true,
  personConfidence = 0.95,
  hasFace = true,
  faceConfidence = 0.92,
  incomingEmbedding = null,
  capturedImageUrl = null,
  io = null,
}) => {
  const house = await House.findByPk(houseId);
  if (!house) throw new Error(`House '${houseId}' not found.`);

  // 1. Fetch registered face profiles for this house
  const registeredProfiles = await FaceProfile.findAll({
    where: { house_id: houseId, is_active: true },
    include: [{ model: Resident, as: 'resident', include: [{ model: User, as: 'user' }] }],
  });

  let matchResult = 'UNKNOWN';
  let matchedResidentId = null;
  let minDistance = 1.0;

  if (hasFace && incomingEmbedding) {
    for (const profile of registeredProfiles) {
      if (profile.face_embedding) {
        try {
          const registeredVec = JSON.parse(profile.face_embedding);
          const dist = calculateVectorDistance(incomingEmbedding, registeredVec);
          if (dist < minDistance) {
            minDistance = dist;
            if (dist < 0.45) { // Match threshold
              matchResult = 'AUTHORIZED';
              matchedResidentId = profile.resident_id;
            } else if (dist < 0.65) {
              matchResult = 'UNCERTAIN';
            }
          }
        } catch (e) {
          console.error('Error parsing face embedding vector:', e.message);
        }
      }
    }
  } else if (!hasFace && hasPerson) {
    matchResult = 'NO_FACE';
  }

  // 2. Compute Risk Score (0 - 100)
  let riskScore = 10;
  const isSecurityArmed = house.security_status === 'ARMED_AWAY' || house.security_status === 'ARMED_HOME';
  const currentHour = new Date().getHours();
  const isNightTime = currentHour >= 22 || currentHour <= 5;

  if (isSecurityArmed) riskScore += 35;
  if (isNightTime) riskScore += 15;
  if (hasPerson) riskScore += 15;

  if (matchResult === 'AUTHORIZED') {
    riskScore = Math.max(5, riskScore - 40);
  } else if (matchResult === 'UNKNOWN') {
    riskScore += 25;
  } else if (matchResult === 'UNCERTAIN') {
    riskScore += 15;
  }

  // 3. Classify Threat Level
  let threatLevel = 'NORMAL';
  if (riskScore >= 70 && isSecurityArmed && matchResult !== 'AUTHORIZED') {
    threatLevel = 'CONFIRMED_THREAT';
  } else if (riskScore >= 45) {
    threatLevel = 'SUSPICIOUS';
  }

  // 4. Save AI Analysis record
  const aiRecord = await AIAnalysis.create({
    security_event_id: securityEventId,
    house_id: houseId,
    person_detected: hasPerson,
    person_confidence: personConfidence,
    face_detected: hasFace,
    face_confidence: faceConfidence,
    matched_resident_id: matchedResidentId,
    face_recognition_result: matchResult,
    threat_level: threatLevel,
    risk_score: riskScore,
    raw_details: {
      isSecurityArmed,
      isNightTime,
      minVectorDistance: minDistance,
      evaluatedAt: new Date().toISOString(),
    },
  });

  // 5. Update Security Event status
  const securityEvent = await SecurityEvent.findByPk(securityEventId);
  if (securityEvent) {
    if (threatLevel === 'CONFIRMED_THREAT') {
      securityEvent.status = 'CONFIRMED_THREAT';
      securityEvent.severity = 'CRITICAL';
    } else if (threatLevel === 'SUSPICIOUS') {
      securityEvent.status = 'INVESTIGATING';
      securityEvent.severity = 'HIGH';
    }
    await securityEvent.save();
  }

  // 6. Push real-time event via WebSocket
  if (io) {
    io.to(`house_${houseId}`).emit('security_alert', {
      type: 'AI_THREAT_EVALUATION',
      securityEvent,
      aiRecord,
      threatLevel,
      riskScore,
    });
  }

  // 7. Automatic Emergency Escalation
  if (threatLevel === 'CONFIRMED_THREAT') {
    console.log(`🚨 [AI THREAT ENGINE] Confirmed Threat detected for ${houseId}! Auto-dispatching emergency...`);
    await dispatchEmergency({
      houseId,
      securityEventId,
      source: 'AUTOMATIC_AI',
      notes: `Automatic emergency dispatched: Unknown intruder detected while security status was '${house.security_status}' with risk score ${riskScore}%.`,
      io,
    });
  }

  return { aiRecord, threatLevel, riskScore, matchResult };
};

module.exports = {
  analyzeThreatAndBiometrics,
  calculateVectorDistance,
};
