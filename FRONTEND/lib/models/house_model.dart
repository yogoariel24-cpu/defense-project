class HouseModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String securityStatus; // DISARMED, ARMED_AWAY, ARMED_HOME, ALARM_TRIGGERED
  final String lightMode; // AUTO, MANUAL
  final int globalBrightness;
  final String emergencyContactPolice;
  final String emergencyContactSecurity;
  final DateTime? lastSecurityChangeAt;

  HouseModel({
    required this.id,
    required this.name,
    required this.address,
    this.latitude = 37.774929,
    this.longitude = -122.419416,
    required this.securityStatus,
    required this.lightMode,
    required this.globalBrightness,
    required this.emergencyContactPolice,
    required this.emergencyContactSecurity,
    this.lastSecurityChangeAt,
  });

  String get googleMapsUrl => 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  bool get isArmed => securityStatus == 'ARMED_AWAY' || securityStatus == 'ARMED_HOME';
  bool get isAlarmTriggered => securityStatus == 'ALARM_TRIGGERED';

  factory HouseModel.fromJson(Map<String, dynamic> json) {
    return HouseModel(
      id: json['id'] ?? 'HOUSE_001',
      name: json['name'] ?? 'Smart House',
      address: json['address'] ?? '',
      latitude: (json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null) ?? 37.774929,
      longitude: (json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null) ?? -122.419416,
      securityStatus: json['security_status'] ?? json['securityStatus'] ?? 'DISARMED',
      lightMode: json['light_mode'] ?? json['lightMode'] ?? 'AUTO',
      globalBrightness: json['global_brightness'] ?? json['globalBrightness'] ?? 75,
      emergencyContactPolice: json['emergency_contact_police'] ?? '911',
      emergencyContactSecurity: json['emergency_contact_security'] ?? '+1-800-VIGILIS',
      lastSecurityChangeAt: json['last_security_change_at'] != null
          ? DateTime.tryParse(json['last_security_change_at'])
          : null,
    );
  }

  HouseModel copyWith({
    String? securityStatus,
    String? lightMode,
    int? globalBrightness,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return HouseModel(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      securityStatus: securityStatus ?? this.securityStatus,
      lightMode: lightMode ?? this.lightMode,
      globalBrightness: globalBrightness ?? this.globalBrightness,
      emergencyContactPolice: emergencyContactPolice,
      emergencyContactSecurity: emergencyContactSecurity,
      lastSecurityChangeAt: lastSecurityChangeAt,
    );
  }
}
