class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // PLATFORM_ADMIN, HOMEOWNER, RESIDENT
  final String status; // ACTIVE, SUSPENDED, PENDING
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? houseId;
  final String? houseName;
  final Map<String, dynamic>? permissions;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    this.phoneNumber,
    this.profileImageUrl,
    this.houseId,
    this.houseName,
    this.permissions,
  });

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      role: json['role'] ?? 'RESIDENT',
      status: json['status'] ?? 'ACTIVE',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
      houseId: json['house_id'] ?? json['houseId'],
      houseName: json['house_name'] ?? json['houseName'],
      permissions: json['permissions'] != null ? Map<String, dynamic>.from(json['permissions']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'status': status,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
      'house_id': houseId,
      'house_name': houseName,
      'permissions': permissions,
    };
  }
}
