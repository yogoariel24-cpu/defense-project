const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const LightSensor = sequelize.define('light_sensors', {
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
    defaultValue: 'Outdoor Yard / Living Room',
  },
  current_lux: {
    type: DataTypes.FLOAT,
    defaultValue: 350.0,
  },
  threshold_lux: {
    type: DataTypes.FLOAT,
    defaultValue: 150.0,
    comment: 'When current_lux drops below threshold_lux, lights increase',
  },
  last_reading_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

module.exports = LightSensor;
