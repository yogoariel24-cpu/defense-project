const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const DeviceOrder = sequelize.define('device_orders', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  homeowner_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  device_type: {
    type: DataTypes.ENUM('CAMERA', 'SMART_LIGHT', 'MOTION_SENSOR', 'ALARM_HUB'),
    allowNull: false,
  },
  device_name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  unit_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  quantity: {
    type: DataTypes.INTEGER,
    defaultValue: 1,
  },
  total_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  payment_method: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  payment_reference: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  payment_status: {
    type: DataTypes.ENUM('PENDING', 'SUBMITTED', 'APPROVED', 'REJECTED'),
    defaultValue: 'SUBMITTED',
  },
  provision_status: {
    type: DataTypes.ENUM('ORDERED', 'PROVISIONED', 'CANCELLED'),
    defaultValue: 'ORDERED',
  },
  rejection_reason: {
    type: DataTypes.STRING,
    allowNull: true,
  },
});

module.exports = DeviceOrder;
