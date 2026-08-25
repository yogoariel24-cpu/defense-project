const { SmartLight, LightSensor, House } = require('../models');

const getLightingStatus = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const house = await House.findByPk(houseId, {
      attributes: ['id', 'light_mode', 'global_brightness'],
    });

    const lights = await SmartLight.findAll({ where: { house_id: houseId } });
    const sensors = await LightSensor.findAll({ where: { house_id: houseId } });

    res.status(200).json({
      success: true,
      data: {
        houseMode: house?.light_mode || 'AUTO',
        globalBrightness: house?.global_brightness || 75,
        lights,
        sensors,
      },
    });
  } catch (error) {
    next(error);
  }
};

const setLightMode = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { mode } = req.body; // 'AUTO' or 'MANUAL'

    if (!['AUTO', 'MANUAL'].includes(mode)) {
      return res.status(400).json({ success: false, message: 'Mode must be AUTO or MANUAL.' });
    }

    const house = await House.findByPk(houseId);
    if (!house) return res.status(404).json({ success: false, message: 'House not found.' });

    house.light_mode = mode;
    await house.save();

    await SmartLight.update({ mode }, { where: { house_id: houseId } });

    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('lighting_update', {
        type: 'MODE_CHANGED',
        mode,
      });
    }

    res.status(200).json({ success: true, message: `Lighting mode switched to ${mode}.`, data: { mode } });
  } catch (error) {
    next(error);
  }
};

const setBrightness = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { light_id, brightness_percentage, is_on } = req.body;

    if (brightness_percentage !== undefined && (brightness_percentage < 0 || brightness_percentage > 100)) {
      return res.status(400).json({ success: false, message: 'Brightness must be between 0 and 100.' });
    }

    let updatedLights = [];
    if (light_id) {
      const light = await SmartLight.findOne({ where: { id: light_id, house_id: houseId } });
      if (!light) return res.status(404).json({ success: false, message: 'Smart light not found in house.' });

      if (brightness_percentage !== undefined) light.brightness_percentage = brightness_percentage;
      if (is_on !== undefined) light.is_on = is_on;
      light.mode = 'MANUAL';
      await light.save();
      updatedLights.push(light);
    } else {
      // Global brightness update
      const house = await House.findByPk(houseId);
      if (house && brightness_percentage !== undefined) {
        house.global_brightness = brightness_percentage;
        house.light_mode = 'MANUAL';
        await house.save();
      }

      await SmartLight.update(
        {
          brightness_percentage: brightness_percentage ?? 75,
          is_on: is_on ?? true,
          mode: 'MANUAL',
        },
        { where: { house_id: houseId } }
      );

      updatedLights = await SmartLight.findAll({ where: { house_id: houseId } });
    }

    const io = req.app.get('io');
    if (io) {
      io.to(`house_${houseId}`).emit('lighting_update', {
        type: 'BRIGHTNESS_UPDATED',
        lights: updatedLights,
        brightness_percentage,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Lighting adjusted successfully.',
      data: { lights: updatedLights },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getLightingStatus, setLightMode, setBrightness };
