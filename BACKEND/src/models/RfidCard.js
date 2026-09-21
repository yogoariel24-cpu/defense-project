const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const RfidCard = sequelize.define('rfid_cards', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  house_id: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
  card_uid: {
    type: DataTypes.STRING(64),
    allowNull: false,
    comment: 'Hex or decimal UID of RFID card/fob (e.g. A1:B2:C3:D4)',
  },
  resident_id: {
    type: DataTypes.UUID,
    allowNull: true,
    comment: 'Associated resident (null if unassigned or guest card)',
  },
  label: {
    type: DataTypes.STRING(100),
    allowNull: false,
    defaultValue: 'Keycard',
    comment: 'e.g. Master Fob, Martin Keycard, Guest 1',
  },
  status: {
    type: DataTypes.ENUM('ACTIVE', 'BLOCKED', 'REVOKED'),
    defaultValue: 'ACTIVE',
  },
  issued_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
  last_used_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

module.exports = RfidCard;
