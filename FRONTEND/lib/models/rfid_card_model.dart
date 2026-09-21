class RfidCardModel {
  final String id;
  final String houseId;
  final String cardUid;
  final String? residentId;
  final String residentName;
  final String label;
  final String status; // ACTIVE, BLOCKED, REVOKED
  final DateTime? issuedAt;
  final DateTime? lastUsedAt;

  RfidCardModel({
    required this.id,
    required this.houseId,
    required this.cardUid,
    this.residentId,
    this.residentName = 'Unassigned',
    required this.label,
    this.status = 'ACTIVE',
    this.issuedAt,
    this.lastUsedAt,
  });

  bool get isActive => status == 'ACTIVE';

  factory RfidCardModel.fromJson(Map<String, dynamic> json) {
    String name = 'Unassigned';
    if (json['resident'] != null && json['resident']['user'] != null) {
      final u = json['resident']['user'];
      name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    }

    return RfidCardModel(
      id: json['id'] ?? '',
      houseId: json['house_id'] ?? '',
      cardUid: json['card_uid'] ?? '',
      residentId: json['resident_id'],
      residentName: name.isNotEmpty ? name : 'Unassigned',
      label: json['label'] ?? 'Keycard',
      status: json['status'] ?? 'ACTIVE',
      issuedAt: json['issued_at'] != null ? DateTime.tryParse(json['issued_at']) : null,
      lastUsedAt: json['last_used_at'] != null ? DateTime.tryParse(json['last_used_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'house_id': houseId,
      'card_uid': cardUid,
      'resident_id': residentId,
      'label': label,
      'status': status,
    };
  }
}
