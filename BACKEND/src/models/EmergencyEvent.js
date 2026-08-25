const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const EmergencyEvent = sequelize.define('emergency_events', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  triggered_by_user_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  security_event_id: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  source: {
    type: DataTypes.ENUM('AUTOMATIC_AI', 'MANUAL_BUTTON', 'EXTERNAL_TRIGGER'),
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM('TRIGGERED', 'DISPATCHED', 'RESPONDED', 'RESOLVED', 'CANCELLED'),
    defaultValue: 'TRIGGERED',
  },
  police_notified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  security_notified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  dispatch_logs: {
    type: DataTypes.JSON,
    allowNull: true,
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  resolved_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

module.exports = EmergencyEvent;
