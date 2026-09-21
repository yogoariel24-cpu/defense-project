const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const RoomPermission = sequelize.define('room_permissions', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  room_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  resident_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  can_access: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    comment: 'Determines whether this resident is allowed into this specific room',
  },
  schedule_start: {
    type: DataTypes.STRING(5),
    allowNull: true,
    comment: 'HH:MM optional schedule start (e.g. 08:00)',
  },
  schedule_end: {
    type: DataTypes.STRING(5),
    allowNull: true,
    comment: 'HH:MM optional schedule end (e.g. 18:00)',
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
});

module.exports = RoomPermission;
