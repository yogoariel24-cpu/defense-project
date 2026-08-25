const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Camera = sequelize.define('cameras', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  device_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  location_name: {
    type: DataTypes.STRING,
    defaultValue: 'Front Entrance',
  },
  stream_url: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'http://192.168.1.100:81/stream',
  },
  resolution: {
    type: DataTypes.STRING,
    defaultValue: '1080p',
  },
  is_recording: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  is_ai_enabled: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  last_snapshot_url: {
    type: DataTypes.STRING,
    allowNull: true,
  },
});

module.exports = Camera;
