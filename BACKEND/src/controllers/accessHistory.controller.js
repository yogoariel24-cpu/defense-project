const { AccessHistory, Room, Resident, User, RfidCard, Device } = require('../models');

/**
 * Get access history for the authenticated house with filtering.
 */
const getHouseAccessHistory = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { room_id, resident_id, access_method, status, limit = 50, page = 1 } = req.query;

    const where = {};
    if (houseId) where.house_id = houseId;
    if (room_id) where.room_id = room_id;
    if (resident_id) where.resident_id = resident_id;
    if (access_method) where.access_method = access_method;
    if (status) where.status = status;

    const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 50));
    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const offset = (parsedPage - 1) * parsedLimit;

    const { count, rows: logs } = await AccessHistory.findAndCountAll({
      where,
      limit: parsedLimit,
      offset,
      order: [['timestamp', 'DESC']],
      include: [
        { model: Room, as: 'room', attributes: ['id', 'name', 'room_type'] },
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }],
        },
        { model: RfidCard, as: 'rfidCard', attributes: ['id', 'card_uid', 'label', 'status'] },
        { model: Device, as: 'device', attributes: ['id', 'device_identifier', 'name', 'type'] },
      ],
    });

    res.status(200).json({
      success: true,
      data: {
        total: count,
        page: parsedPage,
        limit: parsedLimit,
        logs,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getHouseAccessHistory,
};
