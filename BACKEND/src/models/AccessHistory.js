const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const AccessHistory = sequelize.define('access_history', {
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
    allowNull: true,
  },
  device_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  resident_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  rfid_card_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  access_method: {
    type: DataTypes.ENUM('RFID', 'FACE_EMBEDDING', 'MANUAL_APP', 'EMERGENCY_OVERRIDE'),
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM('GRANTED', 'DENIED'),
    allowNull: false,
  },
  denial_reason: {
    type: DataTypes.STRING,
    allowNull: true,
    comment: 'e.g. UNRECOGNIZED_FACE, INACTIVE_ACCOUNT, ROOM_PERMISSION_DENIED, BLOCKED_CARD',
  },
  metadata: {
    type: DataTypes.JSON,
    allowNull: true,
    comment: 'Additional telemetry like vector match distance, UID read, etc.',
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

module.exports = AccessHistory;
