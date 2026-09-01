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

module.exports = {
  sendConcurrentLoginAlert,
  sendUnrecognizedFaceAlert,
};
