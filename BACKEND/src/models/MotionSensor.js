const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const MotionSensor = sequelize.define('motion_sensors', {
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
    defaultValue: 'Driveway / Porch',
  },
  sensitivity: {
    type: DataTypes.INTEGER,
    defaultValue: 80,
    validate: { min: 1, max: 100 },
  },
  is_motion_detected: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  last_motion_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

module.exports = MotionSensor;
