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
  final String paymentStatus; // PENDING, SUBMITTED, APPROVED, REJECTED
  final String subscriptionPlan; // STANDARD, PREMIUM
  final String? paymentMethod;
  final String? paymentReference;
  final double paymentAmount;
  final String? rejectionReason;

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
    this.paymentStatus = 'PENDING',
    this.subscriptionPlan = 'STANDARD',
    this.paymentMethod,
    this.paymentReference,
    this.paymentAmount = 49.99,
    this.rejectionReason,
  });

  String get fullName => '$firstName $lastName';
  bool get isPaymentApproved => role == 'PLATFORM_ADMIN' || paymentStatus == 'APPROVED';

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    String? status,
    String? phoneNumber,
    String? profileImageUrl,
    String? houseId,
    String? houseName,
    Map<String, dynamic>? permissions,
    String? paymentStatus,
    String? subscriptionPlan,
    String? paymentMethod,
    String? paymentReference,
    double? paymentAmount,
    String? rejectionReason,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      houseId: houseId ?? this.houseId,
      houseName: houseName ?? this.houseName,
      permissions: permissions ?? this.permissions,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

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
      paymentStatus: json['payment_status'] ?? json['paymentStatus'] ?? (json['role'] == 'PLATFORM_ADMIN' ? 'APPROVED' : 'PENDING'),
      subscriptionPlan: json['subscription_plan'] ?? json['subscriptionPlan'] ?? 'STANDARD',
      paymentMethod: json['payment_method'] ?? json['paymentMethod'],
      paymentReference: json['payment_reference'] ?? json['paymentReference'],
      paymentAmount: json['payment_amount'] != null
          ? (double.tryParse(json['payment_amount'].toString()) ?? 49.99)
          : (json['paymentAmount'] != null ? (double.tryParse(json['paymentAmount'].toString()) ?? 49.99) : 49.99),
      rejectionReason: json['rejection_reason'] ?? json['rejectionReason'],
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
      'payment_status': paymentStatus,
      'subscription_plan': subscriptionPlan,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'payment_amount': paymentAmount,
      'rejection_reason': rejectionReason,
    };
  }
}
