class RoomModel {
  final String id;
  final String houseId;
  final String name;
  final String roomType;
  final String description;
  final bool isRestricted;
  final List<RoomPermissionModel> permissions;
  final int deviceCount;

  RoomModel({
    required this.id,
    required this.houseId,
    required this.name,
    this.roomType = 'OTHER',
    this.description = '',
    this.isRestricted = false,
    this.permissions = const [],
    this.deviceCount = 0,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    var rawPermissions = json['permissions'] as List? ?? [];
    var permissionList = rawPermissions.map((p) => RoomPermissionModel.fromJson(p)).toList();

    var rawDevices = json['devices'] as List? ?? [];

    return RoomModel(
      id: json['id'] ?? '',
      houseId: json['house_id'] ?? '',
      name: json['name'] ?? 'Room',
      roomType: json['room_type'] ?? 'OTHER',
      description: json['description'] ?? '',
      isRestricted: json['is_restricted'] ?? false,
      permissions: permissionList,
      deviceCount: rawDevices.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'house_id': houseId,
      'name': name,
      'room_type': roomType,
      'description': description,
      'is_restricted': isRestricted,
    };
  }
}

class RoomPermissionModel {
  final String id;
  final String houseId;
  final String roomId;
  final String residentId;
  final String residentName;
  final String residentEmail;
  final bool canAccess;
  final String? scheduleStart;
  final String? scheduleEnd;
  final bool isActive;

  RoomPermissionModel({
    required this.id,
    required this.houseId,
    required this.roomId,
    required this.residentId,
    this.residentName = 'Resident',
    this.residentEmail = '',
    this.canAccess = true,
    this.scheduleStart,
    this.scheduleEnd,
    this.isActive = true,
  });

  factory RoomPermissionModel.fromJson(Map<String, dynamic> json) {
    String name = 'Resident';
    String email = '';
    if (json['resident'] != null && json['resident']['user'] != null) {
      final u = json['resident']['user'];
      name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      email = u['email'] ?? '';
    }

    return RoomPermissionModel(
      id: json['id'] ?? '',
      houseId: json['house_id'] ?? '',
      roomId: json['room_id'] ?? '',
      residentId: json['resident_id'] ?? '',
      residentName: name.isNotEmpty ? name : 'Resident',
      residentEmail: email,
      canAccess: json['can_access'] ?? true,
      scheduleStart: json['schedule_start'],
      scheduleEnd: json['schedule_end'],
      isActive: json['is_active'] ?? true,
    );
  }
}
