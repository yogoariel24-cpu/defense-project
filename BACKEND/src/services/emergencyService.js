const { EmergencyEvent, House, User, Homeowner, Resident, Notification } = require('../models');

/**
 * Dispatches an emergency response (police, security services, SMS/Voice notifications to users).
 */
const dispatchEmergency = async ({
  houseId,
  triggeredByUserId = null,
  securityEventId = null,
  source = 'MANUAL_BUTTON',
  notes = '',
  io = null,
}) => {
  const house = await House.findByPk(houseId, {
    include: [
      { model: Homeowner, as: 'homeowner', include: [{ model: User, as: 'user' }] },
      { model: Resident, as: 'residents', include: [{ model: User, as: 'user' }] },
    ],
  });

  if (!house) throw new Error(`House '${houseId}' not found for emergency dispatch.`);

  // Update house security status to ALARM_TRIGGERED
  house.security_status = 'ALARM_TRIGGERED';
  house.last_security_change_at = new Date();
  await house.save();

  // Simulated Dispatch Logs (Twilio / External API)
  const dispatchLogs = {
    timestamp: new Date().toISOString(),
    policeContact: house.emergency_contact_police || '911',
    securityContact: house.emergency_contact_security || '+1-800-VIGILIS',
    homeownerPhone: house.homeowner?.user?.phone_number || 'N/A',
    smsDispatched: true,
    voiceCallDispatched: true,
    provider: 'Vigilis Emergency Gateway (Twilio Compatible)',
    deliveryStatus: 'SENT',
  };

  // Create Emergency Event Record
  const emergencyEvent = await EmergencyEvent.create({
    house_id: houseId,
    triggered_by_user_id: triggeredByUserId,
    security_event_id: securityEventId,
    source,
    status: 'DISPATCHED',
    police_notified: true,
    security_notified: true,
    dispatch_logs: dispatchLogs,
    notes: notes || `Emergency alert triggered via ${source}.`,
  });

  // Notify Homeowner
  if (house.homeowner && house.homeowner.user) {
    await Notification.create({
      user_id: house.homeowner.user.id,
      house_id: houseId,
      title: '🚨 CRITICAL EMERGENCY ALERT',
      message: `Emergency response dispatched for ${house.name}! Source: ${source}. Police & Security notified.`,
      type: 'EMERGENCY',
      metadata: { emergencyEventId: emergencyEvent.id, source },
    });
  }

  // Notify all Residents
  if (house.residents && house.residents.length > 0) {
    for (const res of house.residents) {
      if (res.user) {
        await Notification.create({
          user_id: res.user.id,
          house_id: houseId,
          title: '🚨 CRITICAL EMERGENCY ALERT',
          message: `Emergency triggered for your house. Seek safe area. Emergency services dispatched.`,
          type: 'EMERGENCY',
          metadata: { emergencyEventId: emergencyEvent.id, source },
        });
      }
    }
  }

  // Broadcast WebSocket Alarm Event
  if (io) {
    io.to(`house_${houseId}`).emit('emergency_alarm', {
      type: 'CRITICAL_EMERGENCY',
      houseId,
      emergencyEvent,
      message: `EMERGENCY DISPATCHED: ${notes}`,
      timestamp: new Date().toISOString(),
    });
  }

  console.log(`📡 [EMERGENCY DISPATCH] Emergency processed for House ${houseId}. Status: DISPATCHED.`);
  return emergencyEvent;
};

module.exports = {
  dispatchEmergency,
};
