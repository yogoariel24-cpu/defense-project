class CameraModel {
  final String id;
  final String deviceId;
  final String houseId;
  final String locationName;
  final String streamUrl;
  final String resolution;
  final bool isActive;
  final bool isAiEnabled;
  final String? roomId;
  final String? roomName;
  final String? deviceIdentifier;
  final String? deviceStatus;

  CameraModel({
    required this.id,
    required this.deviceId,
    required this.houseId,
    required this.locationName,
    required this.streamUrl,
    this.resolution = '1080p',
    this.isActive = true,
    this.isAiEnabled = true,
    this.roomId,
    this.roomName,
    this.deviceIdentifier,
    this.deviceStatus = 'ONLINE',
  });

  bool get isOnline => (deviceStatus == 'ONLINE') && isActive;

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id'] ?? '',
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      houseId: json['house_id'] ?? json['houseId'] ?? '',
      locationName: json['location_name'] ?? json['locationName'] ?? 'Security Camera',
      streamUrl: json['stream_url'] ?? json['streamUrl'] ?? 'http://192.168.1.150:81/stream',
      resolution: json['resolution'] ?? '1080p',
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      isAiEnabled: json['is_ai_enabled'] ?? json['isAiEnabled'] ?? true,
      roomId: json['room_id'] ?? json['roomId'],
      roomName: json['room']?['name'],
      deviceIdentifier: json['device']?['device_identifier'],
      deviceStatus: json['device']?['status'] ?? 'ONLINE',
    );
  }

  CameraModel copyWith({
    String? locationName,
    String? streamUrl,
    String? resolution,
    bool? isActive,
    bool? isAiEnabled,
    String? roomId,
  }) {
    return CameraModel(
      id: id,
      deviceId: deviceId,
      houseId: houseId,
      locationName: locationName ?? this.locationName,
      streamUrl: streamUrl ?? this.streamUrl,
      resolution: resolution ?? this.resolution,
      isActive: isActive ?? this.isActive,
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      roomId: roomId ?? this.roomId,
      roomName: roomName,
      deviceIdentifier: deviceIdentifier,
      deviceStatus: deviceStatus,
    );
  }
}
