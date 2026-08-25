const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SecurityEvent = sequelize.define('security_events', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  device_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  event_type: {
    type: DataTypes.ENUM(
      'MOTION_DETECTED',
      'UNKNOWN_FACE',
      'KNOWN_FACE_ENTRY',
      'DOOR_OPENED',
      'INTRUSION_ALARM',
      'MANUAL_EMERGENCY',
      'SECURITY_ARMED',
      'SECURITY_DISARMED'
    ),
    allowNull: false,
  },
  severity: {
    type: DataTypes.ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
    defaultValue: 'LOW',
  },
  image_url: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  status: {
    type: DataTypes.ENUM('LOGGED', 'INVESTIGATING', 'CONFIRMED_THREAT', 'FALSE_ALARM', 'RESOLVED'),
    defaultValue: 'LOGGED',
  },
  resolved_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

module.exports = SecurityEvent;
