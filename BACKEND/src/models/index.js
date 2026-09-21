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
const Room = require('./Room');
const RoomPermission = require('./RoomPermission');
const RfidCard = require('./RfidCard');
const AccessHistory = require('./AccessHistory');

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

const DeviceOrder = require('./DeviceOrder');
const DetectionEvent = require('./DetectionEvent');

// Device Orders
House.hasMany(DeviceOrder, { foreignKey: 'house_id', as: 'deviceOrders', onDelete: 'CASCADE' });
DeviceOrder.belongsTo(House, { foreignKey: 'house_id', as: 'house' });
DeviceOrder.belongsTo(Homeowner, { foreignKey: 'homeowner_id', as: 'homeowner' });

// Detection Events (YOLO + OpenCV Real-time Ingestion)
House.hasMany(DetectionEvent, { foreignKey: 'house_id', as: 'detectionEvents', onDelete: 'CASCADE' });
DetectionEvent.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

Camera.hasMany(DetectionEvent, { foreignKey: 'camera_id', as: 'detections', onDelete: 'SET NULL' });
DetectionEvent.belongsTo(Camera, { foreignKey: 'camera_id', as: 'camera' });

// Rooms & Room Permissions
House.hasMany(Room, { foreignKey: 'house_id', as: 'rooms', onDelete: 'CASCADE' });
Room.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

Room.hasMany(RoomPermission, { foreignKey: 'room_id', as: 'permissions', onDelete: 'CASCADE' });
RoomPermission.belongsTo(Room, { foreignKey: 'room_id', as: 'room' });

Resident.hasMany(RoomPermission, { foreignKey: 'resident_id', as: 'roomPermissions', onDelete: 'CASCADE' });
RoomPermission.belongsTo(Resident, { foreignKey: 'resident_id', as: 'resident' });

Room.hasMany(Device, { foreignKey: 'room_id', as: 'devices', onDelete: 'SET NULL' });
Device.belongsTo(Room, { foreignKey: 'room_id', as: 'room' });

// RFID Cards
House.hasMany(RfidCard, { foreignKey: 'house_id', as: 'rfidCards', onDelete: 'CASCADE' });
RfidCard.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

Resident.hasMany(RfidCard, { foreignKey: 'resident_id', as: 'rfidCards', onDelete: 'SET NULL' });
RfidCard.belongsTo(Resident, { foreignKey: 'resident_id', as: 'resident' });

// Access History
House.hasMany(AccessHistory, { foreignKey: 'house_id', as: 'accessHistory', onDelete: 'CASCADE' });
AccessHistory.belongsTo(House, { foreignKey: 'house_id', as: 'house' });

Room.hasMany(AccessHistory, { foreignKey: 'room_id', as: 'accessLogs', onDelete: 'SET NULL' });
AccessHistory.belongsTo(Room, { foreignKey: 'room_id', as: 'room' });

Resident.hasMany(AccessHistory, { foreignKey: 'resident_id', as: 'accessLogs', onDelete: 'SET NULL' });
AccessHistory.belongsTo(Resident, { foreignKey: 'resident_id', as: 'resident' });

RfidCard.hasMany(AccessHistory, { foreignKey: 'rfid_card_id', as: 'accessLogs', onDelete: 'SET NULL' });
AccessHistory.belongsTo(RfidCard, { foreignKey: 'rfid_card_id', as: 'rfidCard' });

Device.hasMany(AccessHistory, { foreignKey: 'device_id', as: 'accessLogs', onDelete: 'SET NULL' });
AccessHistory.belongsTo(Device, { foreignKey: 'device_id', as: 'device' });

module.exports = {
  sequelize,
  User,
  PlatformAdministrator,
  Homeowner,
  Resident,
  House,
  Permission,
  Device,
  DeviceOrder,
  Camera,
  MotionSensor,
  LightSensor,
  SmartLight,
  SecurityEvent,
  DetectionEvent,
  AIAnalysis,
  FaceProfile,
  Notification,
  EmergencyEvent,
  ActivityLog,
  Room,
  RoomPermission,
  RfidCard,
  AccessHistory,
};

