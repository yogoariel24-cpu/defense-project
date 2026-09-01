const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Homeowner = sequelize.define('homeowners', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  user_id: {
    type: DataTypes.UUID,
    allowNull: false,
    unique: true,
  },
  billing_address: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  emergency_phone: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  preferred_language: {
    type: DataTypes.STRING,
    defaultValue: 'en',
  },
  subscription_plan: {
    type: DataTypes.STRING,
    defaultValue: 'STANDARD',
  },
  payment_status: {
    type: DataTypes.ENUM('PENDING', 'SUBMITTED', 'APPROVED', 'REJECTED'),
    defaultValue: 'PENDING',
  },
  payment_method: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  payment_reference: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  payment_amount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 49.99,
  },
  payment_date: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  rejection_reason: {
    type: DataTypes.STRING,
    allowNull: true,
  },
});

module.exports = Homeowner;
