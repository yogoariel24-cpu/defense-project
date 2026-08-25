const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SmartLight = sequelize.define('smart_lights', {
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
    defaultValue: 'Living Room Main Light',
  },
  is_on: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  brightness_percentage: {
    type: DataTypes.INTEGER,
    defaultValue: 75,
    validate: { min: 0, max: 100 },
  },
  mode: {
    type: DataTypes.ENUM('AUTO', 'MANUAL'),
    defaultValue: 'AUTO',
  },
  color_temp_kelvin: {
    type: DataTypes.INTEGER,
    defaultValue: 3000,
  },
  relay_pin: {
    type: DataTypes.INTEGER,
    defaultValue: 23,
    comment: 'ESP32 GPIO Pin',
  },
});

module.exports = SmartLight;
