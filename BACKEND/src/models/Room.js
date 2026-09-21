const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Room = sequelize.define('rooms', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  name: {
    type: DataTypes.STRING(100),
    allowNull: false,
    comment: 'e.g. Living Room, Master Bedroom, Server Room, Front Entrance',
  },
  room_type: {
    type: DataTypes.ENUM(
      'ENTRANCE',
      'LIVING_ROOM',
      'BEDROOM',
      'OFFICE',
      'KITCHEN',
      'STORAGE',
      'CORRIDOR',
      'OTHER'
    ),
    defaultValue: 'OTHER',
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  is_restricted: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    comment: 'If true, requires explicit room permission for any entry',
  },
});

module.exports = Room;
