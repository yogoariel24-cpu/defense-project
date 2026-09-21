const { RfidCard, Resident, User } = require('../models');

/**
 * Get all RFID cards for the authenticated house.
 */
const getHouseRfidCards = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const cards = await RfidCard.findAll({
      where: { house_id: houseId },
      include: [
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }],
        },
      ],
      order: [['created_at', 'DESC']],
    });

    res.status(200).json({ success: true, data: { cards } });
  } catch (error) {
    next(error);
  }
};

/**
 * Register a new RFID card for the house.
 */
const registerRfidCard = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { card_uid, label = 'Keycard', resident_id = null } = req.body;

    if (!card_uid) {
      return res.status(400).json({ success: false, message: 'card_uid is required.' });
    }

    // Check if card UID already registered in this house
    const existing = await RfidCard.findOne({ where: { house_id: houseId, card_uid } });
    if (existing) {
      return res.status(409).json({ success: false, message: 'An RFID card with this UID already exists in this house.' });
    }

    // If resident_id provided, verify resident belongs to this house
    if (resident_id) {
      const resCheck = await Resident.findOne({ where: { id: resident_id, house_id: houseId } });
      if (!resCheck) {
        return res.status(404).json({ success: false, message: 'Resident does not belong to this house.' });
      }
    }

    const card = await RfidCard.create({
      house_id: houseId,
      card_uid: card_uid.trim().toUpperCase(),
      label: label.trim(),
      resident_id: resident_id || null,
      status: 'ACTIVE',
    });

    res.status(201).json({ success: true, message: 'RFID card registered successfully.', data: { card } });
  } catch (error) {
    next(error);
  }
};

/**
 * Update an existing RFID card (change label, assign resident, toggle status).
 */
const updateRfidCard = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;
    const { label, resident_id, status } = req.body;

    const card = await RfidCard.findOne({ where: { id, house_id: houseId } });
    if (!card) {
      return res.status(404).json({ success: false, message: 'RFID card not found or access denied.' });
    }

    if (label !== undefined) card.label = label.trim();
    if (status !== undefined) {
      if (!['ACTIVE', 'BLOCKED', 'REVOKED'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status. Choose ACTIVE, BLOCKED, or REVOKED.' });
      }
      card.status = status;
    }

    if (resident_id !== undefined) {
      if (resident_id === null || resident_id === '') {
        card.resident_id = null;
      } else {
        const resCheck = await Resident.findOne({ where: { id: resident_id, house_id: houseId } });
        if (!resCheck) {
          return res.status(404).json({ success: false, message: 'Resident does not belong to this house.' });
        }
        card.resident_id = resident_id;
      }
    }

    await card.save();

    res.status(200).json({ success: true, message: 'RFID card updated successfully.', data: { card } });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete an RFID card from the house.
 */
const deleteRfidCard = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;

    const card = await RfidCard.findOne({ where: { id, house_id: houseId } });
    if (!card) {
      return res.status(404).json({ success: false, message: 'RFID card not found or access denied.' });
    }

    await card.destroy();

    res.status(200).json({ success: true, message: 'RFID card deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getHouseRfidCards,
  registerRfidCard,
  updateRfidCard,
  deleteRfidCard,
};
