const { House, Homeowner, Resident, Device, Camera, SmartLight, LightSensor, MotionSensor, User, SecurityEvent } = require('../models');

const getHouseDetails = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const house = await House.findByPk(houseId, {
      include: [
        { model: Homeowner, as: 'homeowner', include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email', 'phone_number'] }] },
        { model: Resident, as: 'residents', include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }] },
        { model: Device, as: 'devices' },
        { model: SmartLight, as: 'smartLights' },
        { model: LightSensor, as: 'lightSensors' },
        { model: MotionSensor, as: 'motionSensors' },
        { model: Camera, as: 'cameras' },
      ],
    });

    if (!house) {
      return res.status(404).json({ success: false, message: 'House not found.' });
    }

    res.status(200).json({ success: true, data: { house } });
  } catch (error) {
    next(error);
  }
};

const updateHouseSettings = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { name, address, emergency_contact_police, emergency_contact_security } = req.body;

    const house = await House.findByPk(houseId);
    if (!house) return res.status(404).json({ success: false, message: 'House not found.' });

    if (name) house.name = name;
    if (address) house.address = address;
    if (emergency_contact_police) house.emergency_contact_police = emergency_contact_police;
    if (emergency_contact_security) house.emergency_contact_security = emergency_contact_security;

    await house.save();
    res.status(200).json({ success: true, message: 'House settings updated.', data: { house } });
  } catch (error) {
    next(error);
  }
};

module.exports = { getHouseDetails, updateHouseSettings };
