const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const User = sequelize.define('users', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    validate: {
      isEmail: true,
    },
  },
  password_hash: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  first_name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  last_name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  phone_number: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  role: {
    type: DataTypes.ENUM('PLATFORM_ADMIN', 'HOMEOWNER', 'RESIDENT'),
    allowNull: false,
    defaultValue: 'RESIDENT',
  },
  status: {
    type: DataTypes.ENUM('ACTIVE', 'SUSPENDED', 'PENDING'),
    allowNull: false,
    defaultValue: 'ACTIVE',
  },
  profile_image_url: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  last_login_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

module.exports = User;
