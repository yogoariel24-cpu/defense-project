const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const FaceProfile = sequelize.define('face_profiles', {
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
  photo_url: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  face_embedding: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: 'JSON serialized 128-d or 512-d biometric float vector',
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  last_verified_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

module.exports = FaceProfile;
