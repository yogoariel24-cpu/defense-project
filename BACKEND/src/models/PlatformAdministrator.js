const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const PlatformAdministrator = sequelize.define('platform_administrators', {
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
  department: {
    type: DataTypes.STRING,
    defaultValue: 'Operations & Security',
  },
  access_level: {
    type: DataTypes.STRING,
    defaultValue: 'SUPER_ADMIN',
  },
});

module.exports = PlatformAdministrator;
