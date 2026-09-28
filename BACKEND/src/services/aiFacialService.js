const http = require('http');
const https = require('https');
const { URL } = require('url');

/**
 * AI Facial Recognition Bridge Service
 * Connects Node.js backend to the Python AI microservice.
 */
class AIFacialService {
  constructor() {
    this.serviceUrl = process.env.AI_SERVICE_URL || 'http://localhost:5001';
  }

  /**
   * Evaluates face identity from an image against the Python AI service.
   * @param {Buffer|string} imageBufferOrBase64 - Captured frame from ESP32-CAM
   * @param {string} expectedResidentId - Target resident authorized by RFID
   * @returns {Promise<{recognized: boolean, residentId: string|null, confidence: number, reason?: string}>}
   */
  async verifyFace(imageBufferOrBase64, expectedResidentId = null) {
    if (!imageBufferOrBase64) {
      return {
        recognized: false,
        residentId: null,
        confidence: 0,
        reason: 'No image provided for facial verification.',
      };
    }

    try {
      const payload = JSON.stringify({
        image: typeof imageBufferOrBase64 === 'string'
          ? imageBufferOrBase64
          : imageBufferOrBase64.toString('base64'),
        expectedResidentId,
      });

      const url = new URL(`${this.serviceUrl}/recognize`);
      const isHttps = url.protocol === 'https:';
      const client = isHttps ? https : http;

      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
        timeout: 6000, // 6 second timeout
      };

      const result = await new Promise((resolve) => {
        const req = client.request(options, (res) => {
          let body = '';
          res.on('data', (chunk) => (body += chunk));
          res.on('end', () => {
            try {
              const parsed = JSON.parse(body);
              resolve({ statusCode: res.statusCode, data: parsed });
            } catch (e) {
              resolve({ statusCode: res.statusCode, data: null });
            }
          });
        });

        req.on('error', (err) => {
          resolve({ error: err.message });
        });

        req.on('timeout', () => {
          req.destroy();
          resolve({ error: 'AI Facial Service Timeout' });
        });

        req.write(payload);
        req.end();
      });

      if (result.error || !result.data) {
        console.warn(`⚠️ [AI Face Service]: Python service unavailable (${result.error || 'bad response'}). Failing closed.`);
        return {
          recognized: false,
          residentId: null,
          confidence: 0,
          reason: 'AI facial service unavailable or timed out (Fail-closed).',
        };
      }

      const { recognized, residentId, confidence, reason } = result.data;

      // Strict validation: Must be recognized AND have confidence >= 0.70
      if (recognized && confidence >= 0.70) {
        return {
          recognized: true,
          residentId: residentId || expectedResidentId,
          confidence,
        };
      }

      return {
        recognized: false,
        residentId: null,
        confidence: confidence || 0,
        reason: reason || 'Face not recognized with sufficient confidence threshold.',
      };
    } catch (err) {
      console.error('❌ [AI Facial Service Error]:', err.message);
      // ALWAYS FAIL CLOSED
      return {
        recognized: false,
        residentId: null,
        confidence: 0,
        reason: `AI exception: ${err.message}`,
      };
    }
  }

  /**
   * Enrolls a resident's facial profile in the AI microservice.
   */
  async enrollFace(residentId, imageBufferOrBase64, name = 'Resident') {
    try {
      const payload = JSON.stringify({
        residentId,
        name,
        image: typeof imageBufferOrBase64 === 'string'
          ? imageBufferOrBase64
          : imageBufferOrBase64.toString('base64'),
      });

      const url = new URL(`${this.serviceUrl}/register`);
      const isHttps = url.protocol === 'https:';
      const client = isHttps ? https : http;

      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
        timeout: 8000,
      };

      return new Promise((resolve) => {
        const req = client.request(options, (res) => {
          let body = '';
          res.on('data', (chunk) => (body += chunk));
          res.on('end', () => {
            try {
              resolve(JSON.parse(body));
            } catch (_) {
              resolve({ success: false, message: 'Invalid response from AI service.' });
            }
          });
        });

        req.on('error', (e) => resolve({ success: false, message: e.message }));
        req.write(payload);
        req.end();
      });
    } catch (e) {
      return { success: false, message: e.message };
    }
  }
}

module.exports = new AIFacialService();
