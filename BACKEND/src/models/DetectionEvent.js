const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const DetectionEvent = sequelize.define('detection_events', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  camera_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  security_event_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  object_type: {
    type: DataTypes.STRING,
    allowNull: false,
    comment: 'person, vehicle, animal, package, etc.',
  },
  class_name: {
    type: DataTypes.STRING,
    allowNull: true,
    comment: 'Specific YOLO class name (e.g. car, truck, person, dog)',
  },
  confidence: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0,
  },
  bounding_box: {
    type: DataTypes.JSON,
    allowNull: true,
    comment: 'Coordinates {x, y, w, h} or [x1, y1, x2, y2]',
  },
  has_face: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  face_confidence: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0,
  },
  status: {
    type: DataTypes.ENUM('DETECTED', 'ANALYZING', 'NORMAL', 'SUSPICIOUS', 'VERIFIED_THREAT', 'RESOLVED'),
    defaultValue: 'DETECTED',
  },
  image_url: {
    type: DataTypes.TEXT('long'),
    allowNull: true,
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

module.exports = DetectionEvent;
