import 'user_model.dart';

class ResidentModel {
  final String id;
  final String userId;
  final String houseId;
  final String relationshipToOwner;
  final bool isActive;
  final UserModel? user;
  final ResidentPermissions permissions;
  final String? facePhotoUrl;

  ResidentModel({
    required this.id,
    required this.userId,
    required this.houseId,
    required this.relationshipToOwner,
    required this.isActive,
    this.user,
    required this.permissions,
    this.facePhotoUrl,
  });

  String get fullName {
    if (user != null) {
      final name = '${user!.firstName} ${user!.lastName}'.trim();
      if (name.isNotEmpty) return name;
    }
    return 'Resident';
  }

  factory ResidentModel.fromJson(Map<String, dynamic> json) {
    return ResidentModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      houseId: json['house_id'] ?? '',
      relationshipToOwner: json['relationship_to_owner'] ?? 'Resident',
      isActive: json['is_active'] ?? true,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      permissions: json['permissions'] != null
          ? ResidentPermissions.fromJson(json['permissions'])
          : ResidentPermissions.defaultPermissions(),
      facePhotoUrl: json['faceProfile']?['photo_url'],
    );
  }
}

class ResidentPermissions {
  final bool canControlLights;
  final bool canViewCameras;
  final bool canArmSecurity;
  final bool canDisarmSecurity;
  final bool canTriggerEmergency;
  final bool canManageDevices;

  ResidentPermissions({
    required this.canControlLights,
    required this.canViewCameras,
    required this.canArmSecurity,
    required this.canDisarmSecurity,
    required this.canTriggerEmergency,
    required this.canManageDevices,
  });

  factory ResidentPermissions.defaultPermissions() {
    return ResidentPermissions(
      canControlLights: true,
      canViewCameras: true,
      canArmSecurity: false,
      canDisarmSecurity: false,
      canTriggerEmergency: true,
      canManageDevices: false,
    );
  }

  factory ResidentPermissions.fromJson(Map<String, dynamic> json) {
    return ResidentPermissions(
      canControlLights: json['can_control_lights'] ?? true,
      canViewCameras: json['can_view_cameras'] ?? true,
      canArmSecurity: json['can_arm_security'] ?? false,
      canDisarmSecurity: json['can_disarm_security'] ?? false,
      canTriggerEmergency: json['can_trigger_emergency'] ?? true,
      canManageDevices: json['can_manage_devices'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_control_lights': canControlLights,
      'can_view_cameras': canViewCameras,
      'can_arm_security': canArmSecurity,
      'can_disarm_security': canDisarmSecurity,
      'can_trigger_emergency': canTriggerEmergency,
      'can_manage_devices': canManageDevices,
    };
  }
}
