const { Device, Camera, MotionSensor, LightSensor, SmartLight } = require('../models');

const getHouseDevices = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const devices = await Device.findAll({
      where: { house_id: houseId },
      include: [
        { model: Camera, as: 'camera' },
        { model: MotionSensor, as: 'motionSensor' },
        { model: LightSensor, as: 'lightSensor' },
        { model: SmartLight, as: 'smartLight' },
      ],
      order: [['created_at', 'ASC']],
    });

    res.status(200).json({ success: true, data: { devices } });
  } catch (error) {
    next(error);
  }
};

const registerDevice = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { device_identifier, name, type, ip_address, mac_address, specific_config } = req.body;

    if (!device_identifier || !name || !type) {
      return res.status(400).json({ success: false, message: 'Please provide identifier, name and type.' });
    }

    const device = await Device.create({
      house_id: houseId,
      device_identifier,
      name,
      type,
      ip_address: ip_address || '192.168.1.50',
      mac_address: mac_address || 'AA:BB:CC:DD:EE:FF',
      status: 'ONLINE',
    });

    // Create corresponding sub-entity based on type
    if (type === 'CAMERA' || type === 'ESP32_CAM') {
      await Camera.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config?.location_name || name,
        stream_url: specific_config?.stream_url || `http://${device.ip_address}:81/stream`,
      });
    } else if (type === 'MOTION_SENSOR') {
      await MotionSensor.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config?.location_name || name,
        sensitivity: specific_config?.sensitivity || 80,
      });
    } else if (type === 'LIGHT_SENSOR') {
      await LightSensor.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config?.location_name || name,
        threshold_lux: specific_config?.threshold_lux || 150.0,
      });
    } else if (type === 'SMART_LIGHT') {
      await SmartLight.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config?.location_name || name,
        relay_pin: specific_config?.relay_pin || 23,
      });
    }

    res.status(201).json({ success: true, message: 'Device registered successfully.', data: { device } });
  } catch (error) {
    next(error);
  }
};

const sendHeartbeat = async (req, res, next) => {
  try {
    const { device_identifier, status = 'ONLINE' } = req.body;
    const device = await Device.findOne({ where: { device_identifier } });
    if (!device) return res.status(404).json({ success: false, message: 'Device not recognized.' });

    device.status = status;
    device.last_heartbeat_at = new Date();
    await device.save();

    res.status(200).json({ success: true, message: 'Heartbeat acknowledged.' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getHouseDevices, registerDevice, sendHeartbeat };
