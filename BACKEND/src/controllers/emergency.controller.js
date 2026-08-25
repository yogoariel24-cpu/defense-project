const { EmergencyEvent, House, User } = require('../models');
const { dispatchEmergency } = require('../services/emergencyService');

const triggerManualEmergency = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { notes } = req.body;

    const io = req.app.get('io');
    const emergencyEvent = await dispatchEmergency({
      houseId,
      triggeredByUserId: req.user.id,
      source: 'MANUAL_BUTTON',
      notes: notes || `Manual panic button pressed by user ${req.user.first_name} ${req.user.last_name}.`,
      io,
    });

    res.status(201).json({
      success: true,
      message: '🚨 Emergency dispatched immediately to police and emergency contacts.',
      data: { emergencyEvent },
    });
  } catch (error) {
    next(error);
  }
};

const getEmergencyHistory = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const events = await EmergencyEvent.findAll({
      where: { house_id: houseId },
      include: [{ model: User, as: 'triggeredBy', attributes: ['id', 'first_name', 'last_name', 'email'] }],
      order: [['created_at', 'DESC']],
    });

    res.status(200).json({ success: true, data: { emergencyEvents: events } });
  } catch (error) {
    next(error);
  }
};

const resolveEmergency = async (req, res, next) => {
  try {
    const { emergencyId } = req.params;
    const houseId = req.targetHouseId;

    const emergencyEvent = await EmergencyEvent.findOne({ where: { id: emergencyId, house_id: houseId } });
    if (!emergencyEvent) return res.status(404).json({ success: false, message: 'Emergency event not found.' });

    emergencyEvent.status = 'RESOLVED';
    emergencyEvent.resolved_at = new Date();
    await emergencyEvent.save();

    // Reset house security status to DISARMED
    const house = await House.findByPk(houseId);
    if (house && house.security_status === 'ALARM_TRIGGERED') {
      house.security_status = 'DISARMED';
      await house.save();
    }

    res.status(200).json({ success: true, message: 'Emergency resolved and alarm cleared.', data: { emergencyEvent } });
  } catch (error) {
    next(error);
  }
};

module.exports = { triggerManualEmergency, getEmergencyHistory, resolveEmergency };
