/**
 * ============================================================================
 * VIGILIS SECURITY NOTIFICATION & EMAIL DISPATCH SERVICE
 * ============================================================================
 * Sends security alerts, concurrent login warnings, and unrecognized face
 * notifications via Google SMTP (Gmail) or standard SMTP.
 * ============================================================================
 */

let nodemailer;
try {
  nodemailer = require('nodemailer');
} catch (e) {
  nodemailer = null;
}

const getTransporter = () => {
  if (!nodemailer) return null;

  const user = process.env.GMAIL_USER || process.env.SMTP_USER;
  const pass = process.env.GMAIL_APP_PASSWORD || process.env.SMTP_PASS;

  if (!user || !pass) return null;

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: user,
      pass: pass,
    },
  });
};

/**
 * 1. Sends an urgent security alert when concurrent logins on the same account are detected.
 */
const sendConcurrentLoginAlert = async ({ email, name, ipAddress, userAgent, time = new Date() }) => {
  const subject = '🚨 [Vigilis Security Alert] Concurrent Account Login Detected';
  const htmlContent = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; border: 1px solid #1e293b; background-color: #0b1528; color: #f8fafc; border-radius: 12px;">
      <div style="text-align: center; margin-bottom: 20px;">
        <h2 style="color: #ef4444; margin: 0;">🚨 Concurrent Session Warning</h2>
        <p style="color: #94a3b8; font-size: 13px;">Vigilis Intelligent House Multi-Session Security Engine</p>
      </div>
      
      <p style="font-size: 15px;">Hello <strong>${name || 'User'}</strong>,</p>
      <p style="font-size: 14px; line-height: 1.5; color: #cbd5e1;">
        We detected a <strong>second active login session</strong> for your Vigilis account while another session was already in progress.
      </p>

      <div style="background-color: #1e293b; padding: 16px; border-radius: 8px; margin: 18px 0; border-left: 4px solid #ef4444;">
        <p style="margin: 4px 0; font-size: 13px;"><strong>Time:</strong> ${new Date(time).toUTCString()}</p>
        <p style="margin: 4px 0; font-size: 13px;"><strong>New IP Address:</strong> <code style="color: #38bdf8;">${ipAddress || 'Unknown IP'}</code></p>
        <p style="margin: 4px 0; font-size: 13px;"><strong>Device / Browser:</strong> ${userAgent || 'Mobile App / Web Client'}</p>
      </div>

      <p style="font-size: 13px; color: #fca5a5;">
        ⚠️ If you or a family member did NOT initiate this login, someone else may have access to your credentials. Please log into your app and reset your password immediately.
      </p>
      
      <hr style="border: 0; border-top: 1px solid #334155; margin: 20px 0;" />
      <p style="font-size: 11px; color: #64748b; text-align: center;">
        Vigilis Intelligent House Security • Automated Protection Guard
      </p>
    </div>
  `;

  try {
    const transporter = getTransporter();
    if (transporter) {
      await transporter.sendMail({
        from: `"Vigilis Security" <${process.env.GMAIL_USER || 'security@vigilis.com'}>`,
        to: email,
        subject: subject,
        html: htmlContent,
      });
      console.log(`📧 [EMAIL SENT] Concurrent login warning sent to ${email}`);
    } else {
      console.log(`\n================================================================`);
      console.log(`📧 [EMAIL NOTIFICATION SIMULATION]`);
      console.log(`To: ${email}`);
      console.log(`Subject: ${subject}`);
      console.log(`Details: Concurrent login from IP ${ipAddress} at ${new Date(time).toISOString()}`);
      console.log(`Tip: Configure GMAIL_USER and GMAIL_APP_PASSWORD in .env for live Google email delivery.`);
      console.log(`================================================================\n`);
    }
  } catch (error) {
    console.error(`⚠️ [EMAIL ERROR] Failed to send email to ${email}:`, error.message);
  }
};

/**
 * 2. Sends an alert when an unrecognized face is detected by the AI vision system.
 */
const sendUnrecognizedFaceAlert = async ({ email, name, houseName, cameraName, time = new Date(), riskScore }) => {
  const subject = '⚠️ [Vigilis AI Vision] Unrecognized Face / Intruder Detected';
  const htmlContent = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; border: 1px solid #1e293b; background-color: #0b1528; color: #f8fafc; border-radius: 12px;">
      <h2 style="color: #f59e0b; margin: 0; text-align: center;">⚠️ Unrecognized Face Detected</h2>
      <p style="color: #94a3b8; font-size: 13px; text-align: center;">OpenCV & Biometric Face Match Report</p>

      <p style="font-size: 15px; margin-top: 20px;">Dear <strong>${name || 'Homeowner'}</strong>,</p>
      <p style="font-size: 14px; line-height: 1.5; color: #cbd5e1;">
        The Vigilis AI Vision radar detected a person whose face <strong>does not match any registered resident</strong> for <strong>${houseName || 'your residence'}</strong>.
      </p>

      <div style="background-color: #1e293b; padding: 16px; border-radius: 8px; margin: 18px 0; border-left: 4px solid #f59e0b;">
        <p style="margin: 4px 0; font-size: 13px;"><strong>Camera Sector:</strong> ${cameraName || 'Perimeter Camera'}</p>
        <p style="margin: 4px 0; font-size: 13px;"><strong>AI Match Result:</strong> <span style="color: #ef4444; font-weight: bold;">UNKNOWN / UNRECOGNIZED</span></p>
        <p style="margin: 4px 0; font-size: 13px;"><strong>Threat Risk Score:</strong> ${riskScore || 75}%</p>
        <p style="margin: 4px 0; font-size: 13px;"><strong>Timestamp:</strong> ${new Date(time).toUTCString()}</p>
      </div>

      <p style="font-size: 13px; color: #cbd5e1;">
        An in-app notification has been dispatched to your dashboard. Please review the live camera stream or security event log in your mobile app.
      </p>
    </div>
  `;

  try {
    const transporter = getTransporter();
    if (transporter) {
      await transporter.sendMail({
        from: `"Vigilis AI Vision" <${process.env.GMAIL_USER || 'security@vigilis.com'}>`,
        to: email,
        subject: subject,
        html: htmlContent,
      });
      console.log(`📧 [EMAIL SENT] Unrecognized face alert sent to ${email}`);
    } else {
      console.log(`📧 [EMAIL SIMULATION] Unrecognized face alert dispatched to ${email} (House: ${houseName})`);
    }
  } catch (error) {
    console.error(`⚠️ [EMAIL ERROR] Failed to send email to ${email}:`, error.message);
  }
};

/**
 * 3. Sends an urgent priority emergency email to the Police and Emergency Dispatch
 * containing the exact location of the house with Google Maps link, GPS coordinates,
 * residence info, and incident details when the panic button is triggered.
 */
const sendPoliceEmergencyEmail = async ({
  policeEmail = process.env.POLICE_EMERGENCY_EMAIL || 'police.dispatch@vigilis-emergency.gov',
  houseName,
  houseAddress,
  houseId,
  latitude = 37.774929,
  longitude = -122.419416,
  googleMapsUrl,
  googleMapsDirectionsUrl,
  triggeredByName = 'Resident',
  source = 'MANUAL_PANIC_BUTTON',
  notes = '',
  time = new Date(),
  homeownerPhone = 'N/A',
}) => {
  const mapsSearchUrl = googleMapsUrl || `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
  const directionsUrl = googleMapsDirectionsUrl || `https://www.google.com/maps/dir/?api=1&destination=${latitude},${longitude}`;
  const timestampStr = new Date(time).toUTCString();

  const subject = `🚨 [URGENT POLICE DISPATCH] Panic Alarm Triggered: ${houseName} (${houseAddress})`;

  const textBody = `
================================================================================
🚨 URGENT POLICE DISPATCH NOTIFICATION - VIGILIS SECURITY SYSTEM
================================================================================
A panic emergency button has been triggered at a monitored residence. Immediate response requested.

LOCATION DETAILS:
- Residence: ${houseName}
- House ID: ${houseId}
- Address: ${houseAddress}
- GPS Coordinates: Latitude ${latitude}, Longitude ${longitude}

GOOGLE MAPS LIVE LOCATION LINKS:
- View on Google Maps: ${mapsSearchUrl}
- Driving Directions: ${directionsUrl}

INCIDENT INFORMATION:
- Triggered By: ${triggeredByName}
- Trigger Method: ${source}
- Timestamp: ${timestampStr}
- Emergency Contact: ${homeownerPhone}
- Incident Notes: ${notes || 'Panic button triggered from monitored access controller / mobile application.'}

================================================================================
Vigilis Intelligent Home Access Control and Security System
================================================================================
  `.trim();

  const htmlContent = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 680px; margin: 0 auto; padding: 24px; background-color: #070e1b; color: #f8fafc; border-radius: 14px; border: 2px solid #ef4444;">
      
      <!-- Critical Banner -->
      <div style="background: linear-gradient(135deg, #ef4444, #b91c1c); padding: 18px 22px; border-radius: 10px; text-align: center; margin-bottom: 24px;">
        <h1 style="color: #ffffff; font-size: 22px; font-weight: 900; margin: 0; letter-spacing: 0.5px;">
          🚨 CRITICAL POLICE DISPATCH REQUESTED
        </h1>
        <p style="color: #fecaca; font-size: 13px; margin: 6px 0 0 0; font-weight: 600;">
          PANIC BUTTON TRIGGERED • IMMEDIATE RESPONSE REQUIRED
        </p>
      </div>

      <p style="font-size: 15px; line-height: 1.5; color: #cbd5e1; margin-bottom: 20px;">
        Attention <strong>Emergency Dispatch / Police Department</strong>,
      </p>
      <p style="font-size: 14px; line-height: 1.6; color: #94a3b8;">
        An emergency panic alarm was triggered by an occupant at the monitored residence below. The location coordinates and Google Maps route have been verified by the Vigilis Security Engine.
      </p>

      <!-- House & Location Card -->
      <div style="background-color: #0d1829; border: 1px solid #1e293b; border-left: 5px solid #ef4444; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
        <h3 style="color: #f8fafc; margin: 0 0 12px 0; font-size: 16px; border-bottom: 1px solid #1e293b; padding-bottom: 8px;">
          📍 Residence & Geographic Location
        </h3>
        <table style="width: 100%; border-collapse: collapse; font-size: 13px; color: #cbd5e1;">
          <tr>
            <td style="padding: 6px 0; width: 140px; color: #94a3b8; font-weight: bold;">Residence Name:</td>
            <td style="padding: 6px 0; font-weight: 700; color: #ffffff;">${houseName}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">Physical Address:</td>
            <td style="padding: 6px 0; color: #38bdf8; font-weight: 600;">${houseAddress}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">House System ID:</td>
            <td style="padding: 6px 0; font-family: monospace; color: #94a3b8;">${houseId}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">GPS Coordinates:</td>
            <td style="padding: 6px 0; font-family: monospace; color: #4ade80; font-weight: bold;">
              ${latitude}, ${longitude}
            </td>
          </tr>
        </table>
      </div>

      <!-- Prominent Google Maps Action Buttons -->
      <div style="text-align: center; margin: 26px 0;">
        <a href="${mapsSearchUrl}" target="_blank" style="display: inline-block; background-color: #ef4444; color: #ffffff; text-decoration: none; font-weight: 800; font-size: 15px; padding: 14px 28px; border-radius: 8px; margin: 6px; box-shadow: 0 4px 14px rgba(239, 68, 68, 0.4);">
          📍 OPEN LIVE LOCATION ON GOOGLE MAPS
        </a>
        <a href="${directionsUrl}" target="_blank" style="display: inline-block; background-color: #0284c7; color: #ffffff; text-decoration: none; font-weight: 800; font-size: 15px; padding: 14px 28px; border-radius: 8px; margin: 6px; box-shadow: 0 4px 14px rgba(2, 132, 199, 0.4);">
          🚗 GET DRIVING DIRECTIONS
        </a>
      </div>

      <!-- Incident Metadata Box -->
      <div style="background-color: #0d1829; border: 1px solid #1e293b; border-left: 5px solid #0284c7; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
        <h3 style="color: #f8fafc; margin: 0 0 12px 0; font-size: 16px; border-bottom: 1px solid #1e293b; padding-bottom: 8px;">
          ⏱️ Incident & Trigger Information
        </h3>
        <table style="width: 100%; border-collapse: collapse; font-size: 13px; color: #cbd5e1;">
          <tr>
            <td style="padding: 6px 0; width: 140px; color: #94a3b8; font-weight: bold;">Triggered By:</td>
            <td style="padding: 6px 0; font-weight: 600; color: #f8fafc;">${triggeredByName}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">Trigger Method:</td>
            <td style="padding: 6px 0; color: #facc15; font-weight: 600;">${source}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">Alert Timestamp:</td>
            <td style="padding: 6px 0; color: #cbd5e1;">${timestampStr}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">Occupant Phone:</td>
            <td style="padding: 6px 0; color: #38bdf8; font-weight: bold;">${homeownerPhone}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94a3b8; font-weight: bold;">Notes:</td>
            <td style="padding: 6px 0; color: #cbd5e1;">${notes || 'Panic button manually pressed. Occupant requests immediate assistance.'}</td>
          </tr>
        </table>
      </div>

      <p style="font-size: 12px; color: #94a3b8; line-height: 1.5; margin-top: 24px;">
        Direct Map URL: <a href="${mapsSearchUrl}" style="color: #38bdf8; word-break: break-all;">${mapsSearchUrl}</a>
      </p>

      <hr style="border: 0; border-top: 1px solid #1e293b; margin: 24px 0;" />
      <p style="font-size: 11px; color: #64748b; text-align: center; margin: 0;">
        Vigilis Intelligent Home Access Control & Security System • Automated Emergency Telephony & Email Dispatch
      </p>
    </div>
  `;

  try {
    const transporter = getTransporter();
    if (transporter) {
      const info = await transporter.sendMail({
        from: `"Vigilis Emergency Dispatch" <${process.env.GMAIL_USER || 'dispatch@vigilis.com'}>`,
        to: policeEmail,
        subject: subject,
        text: textBody,
        html: htmlContent,
      });
      console.log(`🚨 [POLICE EMAIL DELIVERED] Emergency dispatch email sent to police (${policeEmail}) - MessageId: ${info.messageId}`);
      return { success: true, messageId: info.messageId, delivered: true };
    } else {
      console.log(`\n================================================================`);
      console.log(`🚨 [POLICE EMERGENCY EMAIL DISPATCH - SIMULATION MODE]`);
      console.log(`To: ${policeEmail}`);
      console.log(`Subject: ${subject}`);
      console.log(`🏠 Residence: ${houseName} (${houseAddress})`);
      console.log(`📍 GPS Coordinates: ${latitude}, ${longitude}`);
      console.log(`🗺️ Live Google Maps URL: ${mapsSearchUrl}`);
      console.log(`🚗 Driving Directions URL: ${directionsUrl}`);
      console.log(`👤 Triggered by: ${triggeredByName} via ${source}`);
      console.log(`📞 Homeowner Phone: ${homeownerPhone}`);
      console.log(`ℹ️ Tip: Set GMAIL_USER & GMAIL_APP_PASSWORD in .env for live SMTP delivery.`);
      console.log(`================================================================\n`);
      return { success: true, delivered: false, simulated: true, mapsSearchUrl };
    }
  } catch (error) {
    console.error(`⚠️ [POLICE EMAIL ERROR] Failed to send emergency email to ${policeEmail}:`, error.message);
    return { success: false, error: error.message };
  }
};

module.exports = {
  sendConcurrentLoginAlert,
  sendUnrecognizedFaceAlert,
  sendPoliceEmergencyEmail,
};

