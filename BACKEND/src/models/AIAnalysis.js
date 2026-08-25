const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const AIAnalysis = sequelize.define('ai_analyses', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  security_event_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  person_detected: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  person_confidence: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0,
  },
  face_detected: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  face_confidence: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0,
  },
  matched_resident_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  face_recognition_result: {
    type: DataTypes.ENUM('AUTHORIZED', 'UNKNOWN', 'UNCERTAIN', 'NO_FACE'),
    defaultValue: 'NO_FACE',
  },
  threat_level: {
    type: DataTypes.ENUM('NORMAL', 'SUSPICIOUS', 'CONFIRMED_THREAT'),
    defaultValue: 'NORMAL',
  },
  risk_score: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0,
    comment: 'Risk percentage calculated from context, 0 to 100',
  },
  raw_details: {
    type: DataTypes.JSON,
    allowNull: true,
  },
});

module.exports = AIAnalysis;
