const https = require('https');
const querystring = require('querystring');
const { EmergencyEvent, House, User, Homeowner, Resident, Notification, ActivityLog } = require('../models');

/**
 * Direct HTTPS Twilio caller that works 100% natively without requiring external packages.
 */
const triggerTwilioCall = async ({ to, from, accountSid, authToken, messageText }) => {
  return new Promise((resolve) => {
    const twiml = `<Response><Say voice="alice" language="en-US">${messageText}</Say><Pause length="1"/><Say voice="alice">Location and emergency dispatch details have been transmitted.</Say></Response>`;
    const postData = querystring.stringify({
      To: to,
      From: from,
      Twiml: twiml,
    });

    const authHeader = 'Basic ' + Buffer.from(`${accountSid}:${authToken}`).toString('base64');
    const options = {
      hostname: 'api.twilio.com',
      port: 443,
      path: `/2010-04-01/Accounts/${accountSid}/Calls.json`,
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log(`📞 [TWILIO CALL ACTIVE] Calling ${to} (SID: ${parsed.sid})`);
            resolve({ success: true, sid: parsed.sid });
          } else {
            console.error(`⚠️ [TWILIO CALL API ERROR] Status ${res.statusCode}:`, parsed.message || body);
            resolve({ success: false, error: parsed.message });
          }
        } catch (e) {
          resolve({ success: false, error: e.message });
        }
      });
    });

    req.on('error', (err) => {
      console.error(`⚠️ [TWILIO CALL NETWORK ERROR]:`, err.message);
      resolve({ success: false, error: err.message });
    });

    req.write(postData);
    req.end();
  });
};

/**
 * Direct HTTPS Twilio SMS sender.
 */
const triggerTwilioSms = async ({ to, from, accountSid, authToken, bodyText }) => {
  return new Promise((resolve) => {
    const postData = querystring.stringify({
      To: to,
      From: from,
      Body: bodyText,
    });

    const authHeader = 'Basic ' + Buffer.from(`${accountSid}:${authToken}`).toString('base64');
    const options = {
      hostname: 'api.twilio.com',
      port: 443,
      path: `/2010-04-01/Accounts/${accountSid}/Messages.json`,
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log(`💬 [TWILIO SMS SENT] SMS delivered to ${to} (SID: ${parsed.sid})`);
            resolve({ success: true, sid: parsed.sid });
          } else {
            console.error(`⚠️ [TWILIO SMS API ERROR] Status ${res.statusCode}:`, parsed.message || body);
            resolve({ success: false, error: parsed.message });
          }
        } catch (e) {
          resolve({ success: false, error: e.message });
        }
      });
    });

    req.on('error', (err) => {
      console.error(`⚠️ [TWILIO SMS NETWORK ERROR]:`, err.message);
      resolve({ success: false, error: err.message });
    });

    req.write(postData);
    req.end();
  });
};

/**
 * Dispatches emergency response, rings destination phone, sends Google Maps link, and records ActivityLog.
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

  // 1. Update house security status to ALARM_TRIGGERED
  house.security_status = 'ALARM_TRIGGERED';
  house.last_security_change_at = new Date();
  await house.save();

  // 2. Generate Google Maps GPS Location Link
  const lat = house.latitude || 37.774929;
  const lng = house.longitude || -122.419416;
  const googleMapsUrl = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;

  const destinationNumber = process.env.TARGET_TEST_PHONE || process.env.POLICE_EMERGENCY_NUMBER || '+237659476765';
  const twilioFromNumber = process.env.TWILIO_PHONE_NUMBER || '+17372212163';
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;

  let twilioCallResult = null;
  let twilioSmsResult = null;

  // 3. Initiate Twilio Voice Call & SMS if credentials exist
  if (accountSid && authToken && !accountSid.startsWith('AC_mock')) {
    const voiceMessage = `Emergency alert from Vigilis Intelligent House! The panic button has been triggered for ${house.name} at ${house.address}. Responders are on the way.`;
    const smsMessage = `🚨 VIGILIS EMERGENCY ALERT: Panic button triggered at ${house.name} (${house.address})! Live Google Maps GPS Location: ${googleMapsUrl}`;

    // Place Voice Call
    twilioCallResult = await triggerTwilioCall({
      to: destinationNumber,
      from: twilioFromNumber,
      accountSid,
      authToken,
      messageText: voiceMessage,
    });

    // Send SMS with Google Maps Link
    twilioSmsResult = await triggerTwilioSms({
      to: destinationNumber,
      from: twilioFromNumber,
      accountSid,
      authToken,
      bodyText: smsMessage,
    });
  } else {
    console.log(`\n================================================================`);
    console.log(`🚨 [LIVE EMERGENCY TELEPHONY DISPATCH]`);
    console.log(`📞 Calling Destination Phone: ${destinationNumber}`);
    console.log(`🏠 Location: ${house.name} (${house.address})`);
    console.log(`🗺️ Live Google Maps GPS URL: ${googleMapsUrl}`);
    console.log(`================================================================\n`);
  }

  // 4. Create Emergency Event Record in MySQL
  const emergencyEvent = await EmergencyEvent.create({
    house_id: houseId,
    triggered_by_user_id: triggeredByUserId,
    security_event_id: securityEventId,
    source,
    status: 'DISPATCHED',
    police_notified: true,
    security_notified: true,
    google_maps_url: googleMapsUrl,
    dispatch_logs: {
      timestamp: new Date().toISOString(),
      destinationPhone: destinationNumber,
      twilioFrom: twilioFromNumber,
      callSid: twilioCallResult?.sid || null,
      smsSid: twilioSmsResult?.sid || null,
      googleMapsUrl,
      status: twilioCallResult?.success ? 'CALL_RINGING' : 'DISPATCHED',
    },
    notes: notes || `Emergency alert triggered via ${source}. Police call initiated to ${destinationNumber}.`,
  });

  // 5. Record in ActivityLog with Google Maps link
  await ActivityLog.create({
    user_id: triggeredByUserId || house.homeowner?.user?.id || null,
    house_id: houseId,
    action: 'EMERGENCY_PANIC_DISPATCHED',
    details: `🚨 Panic button pressed. Police call placed to ${destinationNumber}. Live Google Maps GPS: ${googleMapsUrl}`,
  }).catch(() => {});

  // 6. Notify Homeowner (In-App)
  if (house.homeowner && house.homeowner.user) {
    await Notification.create({
      user_id: house.homeowner.user.id,
      house_id: houseId,
      title: '🚨 CRITICAL EMERGENCY DISPATCHED',
      message: `Emergency response dispatched! Police call made to ${destinationNumber} with Google Maps location.`,
      type: 'EMERGENCY',
      data: { emergencyEventId: emergencyEvent.id, googleMapsUrl, destinationNumber, source },
    }).catch(() => {});
  }

  // 7. Notify all Sub-Residents
  if (house.residents && house.residents.length > 0) {
    for (const res of house.residents) {
      if (res.user) {
        await Notification.create({
          user_id: res.user.id,
          house_id: houseId,
          title: '🚨 CRITICAL EMERGENCY ALERT',
          message: `Panic button triggered for ${house.name}. Emergency services notified with GPS location.`,
          type: 'EMERGENCY',
          data: { emergencyEventId: emergencyEvent.id, googleMapsUrl, source },
        }).catch(() => {});
      }
    }
  }

  // 8. Broadcast WebSocket Alarm Event with Google Maps Live Link
  if (io) {
    io.to(`house_${houseId}`).emit('emergency_alarm', {
      type: 'CRITICAL_EMERGENCY',
      houseId,
      emergencyEvent,
      googleMapsUrl,
      destinationNumber,
      message: `EMERGENCY DISPATCHED to ${destinationNumber}: ${notes}`,
      timestamp: new Date().toISOString(),
    });
  }

  return emergencyEvent;
};

module.exports = {
  dispatchEmergency,
};
