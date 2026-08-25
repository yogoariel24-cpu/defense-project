const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Permission = sequelize.define('permissions', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  resident_id: {
    type: DataTypes.UUID,
    allowNull: false,
    unique: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  can_control_lights: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  can_view_cameras: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  can_arm_security: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  can_disarm_security: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  can_trigger_emergency: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  can_manage_devices: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
});

module.exports = Permission;
