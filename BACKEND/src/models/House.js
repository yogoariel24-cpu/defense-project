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
  homeowner_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  security_status: {
    type: DataTypes.ENUM('DISARMED', 'ARMED_AWAY', 'ARMED_HOME', 'ALARM_TRIGGERED'),
    allowNull: false,
    defaultValue: 'DISARMED',
  },
  light_mode: {
    type: DataTypes.ENUM('AUTO', 'MANUAL'),
    allowNull: false,
    defaultValue: 'AUTO',
  },
  global_brightness: {
    type: DataTypes.INTEGER,
    defaultValue: 75,
    validate: {
      min: 0,
      max: 100,
    },
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
