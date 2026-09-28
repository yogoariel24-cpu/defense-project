const { Camera, Device, Room } = require('../models');

/**
 * Camera Management Controller
 * Handles viewing, adding, updating, toggling, and removing cameras.
 * Enforces strict multi-house isolation via req.houseId.
 */

// 1. List all cameras for the authenticated house
const getHouseCameras = async (req, res, next) => {
  try {
    const houseId = req.houseId;

    const cameras = await Camera.findAll({
      where: { house_id: houseId },
      include: [
        { model: Device, as: 'device', attributes: ['id', 'device_identifier', 'name', 'status', 'ip_address'] },
        { model: Room, as: 'room', attributes: ['id', 'name'] },
      ],
      order: [['created_at', 'DESC']],
    });

    return res.status(200).json({
      success: true,
      count: cameras.length,
      data: { cameras },
    });
  } catch (error) {
    next(error);
  }
};

// 2. Add a new camera to the house
const addCamera = async (req, res, next) => {
  try {
    const houseId = req.houseId;
    const {
      name = 'Security Camera',
      location_name = 'Entrance Area',
      stream_url,
      resolution = '1080p',
      room_id,
      device_identifier,
      is_ai_enabled = true,
    } = req.body;

    const identifier = device_identifier || `CAM_${Date.now().toString(36).toUpperCase()}`;

    // Create backing Device record
    const device = await Device.create({
      house_id: houseId,
      room_id: room_id || null,
      device_identifier: identifier,
      name,
      type: 'CAMERA',
      status: 'ONLINE',
    });

    // Create Camera record
    const camera = await Camera.create({
      device_id: device.id,
      house_id: houseId,
      room_id: room_id || null,
      location_name,
      stream_url: stream_url || 'http://192.168.1.150:81/stream',
      resolution,
      is_ai_enabled: is_ai_enabled !== false,
      is_active: true,
    });

    return res.status(201).json({
      success: true,
      message: 'Camera added successfully.',
      data: { camera, device },
    });
  } catch (error) {
    next(error);
  }
};

// 3. Update camera details
const updateCamera = async (req, res, next) => {
  try {
    const houseId = req.houseId;
    const { id } = req.params;
    const { location_name, stream_url, resolution, is_ai_enabled, room_id, name } = req.body;

    const camera = await Camera.findOne({
      where: { id, house_id: houseId },
      include: [{ model: Device, as: 'device' }],
    });

    if (!camera) {
      return res.status(404).json({ success: false, message: 'Camera not found in your house.' });
    }

    if (location_name !== undefined) camera.location_name = location_name;
    if (stream_url !== undefined) camera.stream_url = stream_url;
    if (resolution !== undefined) camera.resolution = resolution;
    if (is_ai_enabled !== undefined) camera.is_ai_enabled = is_ai_enabled;
    if (room_id !== undefined) camera.room_id = room_id;

    await camera.save();

    if (name && camera.device) {
      camera.device.name = name;
      await camera.device.save();
    }

    return res.status(200).json({
      success: true,
      message: 'Camera updated successfully.',
      data: { camera },
    });
  } catch (error) {
    next(error);
  }
};

// 4. Toggle camera activation (Activate / Deactivate)
const toggleCameraStatus = async (req, res, next) => {
  try {
    const houseId = req.houseId;
    const { id } = req.params;
    const { is_active } = req.body;

    const camera = await Camera.findOne({
      where: { id, house_id: houseId },
      include: [{ model: Device, as: 'device' }],
    });

    if (!camera) {
      return res.status(404).json({ success: false, message: 'Camera not found in your house.' });
    }

    camera.is_active = is_active !== undefined ? is_active : !camera.is_active;
    await camera.save();

    if (camera.device) {
      camera.device.status = camera.is_active ? 'ONLINE' : 'OFFLINE';
      await camera.device.save();
    }

    return res.status(200).json({
      success: true,
      message: `Camera ${camera.is_active ? 'activated' : 'deactivated'} successfully.`,
      data: { is_active: camera.is_active, status: camera.device?.status },
    });
  } catch (error) {
    next(error);
  }
};

// 5. Delete camera
const deleteCamera = async (req, res, next) => {
  try {
    const houseId = req.houseId;
    const { id } = req.params;

    const camera = await Camera.findOne({
      where: { id, house_id: houseId },
      include: [{ model: Device, as: 'device' }],
    });

    if (!camera) {
      return res.status(404).json({ success: false, message: 'Camera not found in your house.' });
    }

    const deviceId = camera.device_id;
    await camera.destroy();
    if (deviceId) {
      await Device.destroy({ where: { id: deviceId, house_id: houseId } }).catch(() => {});
    }

    return res.status(200).json({
      success: true,
      message: 'Camera removed successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// 6. Get camera live status
const getCameraStatus = async (req, res, next) => {
  try {
    const houseId = req.houseId;
    const { id } = req.params;

    const camera = await Camera.findOne({
      where: { id, house_id: houseId },
      include: [{ model: Device, as: 'device' }],
    });

    if (!camera) {
      return res.status(404).json({ success: false, message: 'Camera not found.' });
    }

    return res.status(200).json({
      success: true,
      data: {
        id: camera.id,
        location_name: camera.location_name,
        stream_url: camera.stream_url,
        is_active: camera.is_active,
        is_ai_enabled: camera.is_ai_enabled,
        device_status: camera.device?.status || 'OFFLINE',
        last_heartbeat: camera.device?.last_heartbeat_at,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getHouseCameras,
  addCamera,
  updateCamera,
  toggleCameraStatus,
  deleteCamera,
  getCameraStatus,
};
