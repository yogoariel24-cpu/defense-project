const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Device = sequelize.define('devices', {
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
    comment: 'Associated room in the house if assigned',
  },
  device_identifier: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    comment: 'e.g. ESP32_MAIN_01, RFID_DOOR_01, CAM_FRONT_01',
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  type: {
    type: DataTypes.ENUM(
      'ESP32',
      'ESP32_CAM',
      'MOTION_SENSOR',
      'LIGHT_SENSOR',
      'SMART_LIGHT',
      'RELAY',
      'CAMERA',
      'RFID_READER',
      'PRESENCE_SENSOR',
      'DOOR_LOCK'
    ),
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM('ONLINE', 'OFFLINE', 'ERROR'),
    allowNull: false,
    defaultValue: 'ONLINE',
  },
  ip_address: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  mac_address: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  firmware_version: {
    type: DataTypes.STRING,
    defaultValue: 'v1.0.0-vigilis',
  },
  last_heartbeat_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

module.exports = Device;
