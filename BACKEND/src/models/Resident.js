const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Resident = sequelize.define('residents', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  user_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  relationship_to_owner: {
    type: DataTypes.STRING,
    defaultValue: 'Family Member',
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
});

module.exports = Resident;
