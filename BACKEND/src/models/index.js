const { sequelize } = require('../config/database');

const User = require('./User');
const PlatformAdministrator = require('./PlatformAdministrator');
const Homeowner = require('./Homeowner');
const Resident = require('./Resident');
const House = require('./House');
const Permission = require('./Permission');
const Device = require('./Device');
const Camera = require('./Camera');
const MotionSensor = require('./MotionSensor');
const LightSensor = require('./LightSensor');
const SmartLight = require('./SmartLight');
const SecurityEvent = require('./SecurityEvent');
const AIAnalysis = require('./AIAnalysis');
const FaceProfile = require('./FaceProfile');
const Notification = require('./Notification');
const EmergencyEvent = require('./EmergencyEvent');
const ActivityLog = require('./ActivityLog');

// User Associations
User.hasOne(PlatformAdministrator, { foreignKey: 'user_id', as: 'adminProfile', onDelete: 'CASCADE' });
PlatformAdministrator.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

User.hasOne(Homeowner, { foreignKey: 'user_id', as: 'homeownerProfile', onDelete: 'CASCADE' });
Homeowner.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

User.hasOne(Resident, { foreignKey: 'user_id', as: 'residentProfile', onDelete: 'CASCADE' });
Resident.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// Homeowner & House
Homeowner.hasOne(House, { foreignKey: 'homeowner_id', as: 'house', onDelete: 'CASCADE' });
House.belongsTo(Homeowner, { foreignKey: 'homeowner_id', as: 'homeowner' });

// House & Residents
House.hasMany(Resident, { foreignKey: 'house_id', as: 'residents', onDelete: 'CASCADE' });
Resident.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

// Resident Permissions & Biometrics
Resident.hasOne(Permission, { foreignKey: 'resident_id', as: 'permissions', onDelete: 'CASCADE' });
Permission.belongsTo(Resident, { foreignKey: 'resident_id', as: 'resident' });

Resident.hasOne(FaceProfile, { foreignKey: 'resident_id', as: 'faceProfile', onDelete: 'CASCADE' });
FaceProfile.belongsTo(Resident, { foreignKey: 'resident_id', as: 'resident' });

// House & Devices
House.hasMany(Device, { foreignKey: 'house_id', as: 'devices', onDelete: 'CASCADE' });
Device.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

// Device sub-types
Device.hasOne(Camera, { foreignKey: 'device_id', as: 'camera', onDelete: 'CASCADE' });
Camera.belongsTo(Device, { foreignKey: 'device_id', as: 'device' });

Device.hasOne(MotionSensor, { foreignKey: 'device_id', as: 'motionSensor', onDelete: 'CASCADE' });
MotionSensor.belongsTo(Device, { foreignKey: 'device_id', as: 'device' });

Device.hasOne(LightSensor, { foreignKey: 'device_id', as: 'lightSensor', onDelete: 'CASCADE' });
LightSensor.belongsTo(Device, { foreignKey: 'device_id', as: 'device' });

Device.hasOne(SmartLight, { foreignKey: 'device_id', as: 'smartLight', onDelete: 'CASCADE' });
SmartLight.belongsTo(Device, { foreignKey: 'device_id', as: 'device' });

// House Sub-device Direct Access
House.hasMany(Camera, { foreignKey: 'house_id', as: 'cameras', onDelete: 'CASCADE' });
Camera.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

House.hasMany(MotionSensor, { foreignKey: 'house_id', as: 'motionSensors', onDelete: 'CASCADE' });
MotionSensor.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

House.hasMany(LightSensor, { foreignKey: 'house_id', as: 'lightSensors', onDelete: 'CASCADE' });
LightSensor.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

House.hasMany(SmartLight, { foreignKey: 'house_id', as: 'smartLights', onDelete: 'CASCADE' });
SmartLight.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

// Security Events & AI Analysis
House.hasMany(SecurityEvent, { foreignKey: 'house_id', as: 'securityEvents', onDelete: 'CASCADE' });
SecurityEvent.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

SecurityEvent.hasOne(AIAnalysis, { foreignKey: 'security_event_id', as: 'aiAnalysis', onDelete: 'CASCADE' });
AIAnalysis.belongsTo(SecurityEvent, { foreignKey: 'security_event_id', as: 'securityEvent' });

// Emergency Events
House.hasMany(EmergencyEvent, { foreignKey: 'house_id', as: 'emergencyEvents', onDelete: 'CASCADE' });
EmergencyEvent.belongsTo(House, { foreignKey: 'house_id', as: 'house' });
EmergencyEvent.belongsTo(User, { foreignKey: 'triggered_by_user_id', as: 'triggeredBy' });

// Notifications
User.hasMany(Notification, { foreignKey: 'user_id', as: 'notifications', onDelete: 'CASCADE' });
Notification.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

House.hasMany(Notification, { foreignKey: 'house_id', as: 'houseNotifications', onDelete: 'CASCADE' });
Notification.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

// Activity Logs
User.hasMany(ActivityLog, { foreignKey: 'user_id', as: 'activityLogs', onDelete: 'SET NULL' });
ActivityLog.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

House.hasMany(ActivityLog, { foreignKey: 'house_id', as: 'houseActivityLogs', onDelete: 'SET NULL' });
ActivityLog.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

module.exports = {
  sequelize,
  User,
  PlatformAdministrator,
  Homeowner,
  Resident,
  House,
  Permission,
  Device,
  Camera,
  MotionSensor,
  LightSensor,
  SmartLight,
  SecurityEvent,
  AIAnalysis,
  FaceProfile,
  Notification,
  EmergencyEvent,
  ActivityLog,
};
