class DeviceModel {
  final String id;
  final String deviceIdentifier;
  final String name;
  final String type; // ESP32, ESP32_CAM, MOTION_SENSOR, LIGHT_SENSOR, SMART_LIGHT, CAMERA
  final String status; // ONLINE, OFFLINE, ERROR
  final String? ipAddress;
  final String? macAddress;
  final String? locationName;
  final int? brightness;
  final bool? isOn;
  final double? currentLux;
  final double? thresholdLux;
  final bool? motionDetected;
  final String? streamUrl;

  DeviceModel({
    required this.id,
    required this.deviceIdentifier,
    required this.name,
    required this.type,
    required this.status,
    this.ipAddress,
    this.macAddress,
    this.locationName,
    this.brightness,
    this.isOn,
    this.currentLux,
    this.thresholdLux,
    this.motionDetected,
    this.streamUrl,
  });

  bool get isOnline => status == 'ONLINE';

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    String? locName;
    int? b;
    bool? on;
    double? lux;
    double? thresh;
    bool? motion;
    String? stream;

    if (json['smartLight'] != null) {
      locName = json['smartLight']['location_name'];
      b = json['smartLight']['brightness_percentage'];
      on = json['smartLight']['is_on'];
    } else if (json['lightSensor'] != null) {
      locName = json['lightSensor']['location_name'];
      lux = (json['lightSensor']['current_lux'] as num?)?.toDouble();
      thresh = (json['lightSensor']['threshold_lux'] as num?)?.toDouble();
    } else if (json['motionSensor'] != null) {
      locName = json['motionSensor']['location_name'];
      motion = json['motionSensor']['is_motion_detected'];
    } else if (json['camera'] != null) {
      locName = json['camera']['location_name'];
      stream = json['camera']['stream_url'];
    }

    return DeviceModel(
      id: json['id'] ?? '',
      deviceIdentifier: json['device_identifier'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'ESP32',
      status: json['status'] ?? 'ONLINE',
      ipAddress: json['ip_address'],
      macAddress: json['mac_address'],
      locationName: locName ?? json['location_name'],
      brightness: b,
      isOn: on,
      currentLux: lux,
      thresholdLux: thresh,
      motionDetected: motion,
      streamUrl: stream,
    );
  }
}
