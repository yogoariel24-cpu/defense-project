const { Device, LightSensor, SmartLight, MotionSensor, Camera } = require('../models');

/**
 * Simulates real-time IoT hardware readings (LDR light values, ESP32 heartbeats, auto-dimming).
 */
const runIoTSimulationStep = async (io = null) => {
  try {
    const devices = await Device.findAll({ where: { status: 'ONLINE' } });
    for (const dev of devices) {
      dev.last_heartbeat_at = new Date();
      await dev.save();
    }

    // Auto-adjust lighting based on LDR sensors for houses in AUTO mode
    const lightSensors = await LightSensor.findAll();
    for (const sensor of lightSensors) {
      // Simulate slight ambient light fluctuation
      const variation = (Math.random() - 0.5) * 20;
      const newLux = Math.max(10, Math.min(800, Math.round(sensor.current_lux + variation)));
      sensor.current_lux = newLux;
      sensor.last_reading_at = new Date();
      await sensor.save();

      // Find matching SmartLights in AUTO mode in this house
      const autoLights = await SmartLight.findAll({
        where: { house_id: sensor.house_id, mode: 'AUTO' },
      });

      for (const light of autoLights) {
        // Closed-loop control: Less ambient lux -> higher lamp brightness
        let targetBrightness = 0;
        if (newLux < sensor.threshold_lux) {
          const ratio = (sensor.threshold_lux - newLux) / sensor.threshold_lux;
          targetBrightness = Math.min(100, Math.max(20, Math.round(ratio * 100)));
        } else {
          targetBrightness = 15; // Ambient standby
        }

        if (light.brightness_percentage !== targetBrightness) {
          light.brightness_percentage = targetBrightness;
          light.is_on = targetBrightness > 0;
          await light.save();

          if (io) {
            io.to(`house_${sensor.house_id}`).emit('device_telemetry', {
              type: 'LIGHT_AUTO_ADJUSTED',
              lightId: light.id,
              currentLux: newLux,
              thresholdLux: sensor.threshold_lux,
              brightness: targetBrightness,
            });
          }
        }
      }
    }
  } catch (err) {
    console.error('IoT Simulator Error:', err.message);
  }
};

module.exports = {
  runIoTSimulationStep,
};
