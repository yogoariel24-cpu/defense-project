const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const House = sequelize.define('houses', {
  id: {
    type: DataTypes.STRING(32),
    primaryKey: true,
    comment: 'e.g. HOUSE_001',
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  address: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  latitude: {
    type: DataTypes.DECIMAL(10, 8),
    defaultValue: 37.774929,
  },
  longitude: {
    type: DataTypes.DECIMAL(11, 8),
    defaultValue: -122.419416,
  },
  homeowner_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  security_status: {
    type: DataTypes.ENUM('DISARMED', 'ARMED_AWAY', 'ARMED_HOME', 'ALARM_TRIGGERED'),
    allowNull: false,
    defaultValue: 'DISARMED',
  },
  access_control_mode: {
    type: DataTypes.ENUM('NORMAL', 'STRICT_BIOMETRIC', 'LOCKDOWN'),
    allowNull: false,
    defaultValue: 'NORMAL',
  },
  require_face_verification: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  door_open_duration_seconds: {
    type: DataTypes.INTEGER,
    defaultValue: 5,
  },
  light_mode: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  global_brightness: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  emergency_contact_police: {
    type: DataTypes.STRING,
    defaultValue: '911',
  },
  emergency_contact_security: {
    type: DataTypes.STRING,
    defaultValue: '+1-800-VIGILIS',
  },
  last_security_change_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

module.exports = House;
