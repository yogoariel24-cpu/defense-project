const { Room, RoomPermission, Device, Resident, User } = require('../models');

/**
 * Get all rooms for the authenticated house.
 */
const getHouseRooms = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const rooms = await Room.findAll({
      where: { house_id: houseId },
      include: [
        {
          model: Device,
          as: 'devices',
          attributes: ['id', 'device_identifier', 'name', 'type', 'status'],
        },
        {
          model: RoomPermission,
          as: 'permissions',
          include: [
            {
              model: Resident,
              as: 'resident',
              include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }],
            },
          ],
        },
      ],
      order: [['created_at', 'ASC']],
    });

    res.status(200).json({ success: true, data: { rooms } });
  } catch (error) {
    next(error);
  }
};

/**
 * Create a new room in the house.
 */
const createRoom = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { name, room_type = 'OTHER', description = '', is_restricted = false } = req.body;

    if (!name) {
      return res.status(400).json({ success: false, message: 'Room name is required.' });
    }

    const room = await Room.create({
      house_id: houseId,
      name,
      room_type,
      description,
      is_restricted: Boolean(is_restricted),
    });

    // Automatically create default permissions for existing residents
    const residents = await Resident.findAll({ where: { house_id: houseId } });
    for (const resItem of residents) {
      await RoomPermission.create({
        house_id: houseId,
        room_id: room.id,
        resident_id: resItem.id,
        can_access: !is_restricted, // Default access granted if room is not restricted
      });
    }

    res.status(201).json({ success: true, message: 'Room created successfully.', data: { room } });
  } catch (error) {
    next(error);
  }
};

/**
 * Update an existing room.
 */
const updateRoom = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;
    const { name, room_type, description, is_restricted } = req.body;

    const room = await Room.findOne({ where: { id, house_id: houseId } });
    if (!room) {
      return res.status(404).json({ success: false, message: 'Room not found or access denied.' });
    }

    if (name !== undefined) room.name = name;
    if (room_type !== undefined) room.room_type = room_type;
    if (description !== undefined) room.description = description;
    if (is_restricted !== undefined) room.is_restricted = Boolean(is_restricted);

    await room.save();

    res.status(200).json({ success: true, message: 'Room updated successfully.', data: { room } });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete a room.
 */
const deleteRoom = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;

    const room = await Room.findOne({ where: { id, house_id: houseId } });
    if (!room) {
      return res.status(404).json({ success: false, message: 'Room not found or access denied.' });
    }

    await room.destroy();

    res.status(200).json({ success: true, message: 'Room deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

/**
 * Get permissions for a specific room.
 */
const getRoomPermissions = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { id } = req.params;

    const room = await Room.findOne({ where: { id, house_id: houseId } });
    if (!room) {
      return res.status(404).json({ success: false, message: 'Room not found.' });
    }

    const permissions = await RoomPermission.findAll({
      where: { room_id: id, house_id: houseId },
      include: [
        {
          model: Resident,
          as: 'resident',
          include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }],
        },
      ],
    });

    res.status(200).json({ success: true, data: { room, permissions } });
  } catch (error) {
    next(error);
  }
};

/**
 * Set or update a resident's permission for a room.
 */
const setRoomPermission = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { roomId, residentId } = req.params;
    const { can_access, schedule_start, schedule_end, is_active } = req.body;

    // Verify room belongs to house
    const room = await Room.findOne({ where: { id: roomId, house_id: houseId } });
    if (!room) {
      return res.status(404).json({ success: false, message: 'Room not found.' });
    }

    // Verify resident belongs to house
    const resident = await Resident.findOne({ where: { id: residentId, house_id: houseId } });
    if (!resident) {
      return res.status(404).json({ success: false, message: 'Resident not found in this house.' });
    }

    let perm = await RoomPermission.findOne({
      where: { room_id: roomId, resident_id: residentId, house_id: houseId },
    });

    if (perm) {
      if (can_access !== undefined) perm.can_access = Boolean(can_access);
      if (schedule_start !== undefined) perm.schedule_start = schedule_start;
      if (schedule_end !== undefined) perm.schedule_end = schedule_end;
      if (is_active !== undefined) perm.is_active = Boolean(is_active);
      await perm.save();
    } else {
      perm = await RoomPermission.create({
        house_id: houseId,
        room_id: roomId,
        resident_id: residentId,
        can_access: can_access !== undefined ? Boolean(can_access) : true,
        schedule_start: schedule_start || null,
        schedule_end: schedule_end || null,
        is_active: is_active !== undefined ? Boolean(is_active) : true,
      });
    }

    res.status(200).json({ success: true, message: 'Room permission updated successfully.', data: { permission: perm } });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all room permissions for a specific resident.
 */
const getResidentRoomPermissions = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { residentId } = req.params;

    const permissions = await RoomPermission.findAll({
      where: { resident_id: residentId, house_id: houseId },
      include: [{ model: Room, as: 'room' }],
    });

    res.status(200).json({ success: true, data: { permissions } });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getHouseRooms,
  createRoom,
  updateRoom,
  deleteRoom,
  getRoomPermissions,
  setRoomPermission,
  getResidentRoomPermissions,
};
