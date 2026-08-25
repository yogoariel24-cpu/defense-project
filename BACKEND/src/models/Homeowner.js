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
});

module.exports = Homeowner;
