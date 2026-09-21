class AccessHistoryModel {
  final String id;
  final String houseId;
  final String? roomId;
  final String roomName;
  final String? residentId;
  final String residentName;
  final String? rfidCardId;
  final String cardUid;
  final String cardLabel;
  final String accessMethod; // RFID, FACE_EMBEDDING, MANUAL_APP, EMERGENCY_OVERRIDE
  final String status; // GRANTED, DENIED
  final String? denialReason;
  final DateTime timestamp;

  AccessHistoryModel({
    required this.id,
    required this.houseId,
    this.roomId,
    this.roomName = 'Main Door',
    this.residentId,
    this.residentName = 'Unknown',
    this.rfidCardId,
    this.cardUid = '',
    this.cardLabel = '',
    required this.accessMethod,
    required this.status,
    this.denialReason,
    required this.timestamp,
  });

  bool get isGranted => status == 'GRANTED';

  factory AccessHistoryModel.fromJson(Map<String, dynamic> json) {
    String rName = 'Main Door';
    if (json['room'] != null && json['room']['name'] != null) {
      rName = json['room']['name'];
    }

    String uName = 'Unknown';
    if (json['resident'] != null && json['resident']['user'] != null) {
      final u = json['resident']['user'];
      uName = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    }

    String cUid = '';
    String cLabel = '';
    if (json['rfidCard'] != null) {
      cUid = json['rfidCard']['card_uid'] ?? '';
      cLabel = json['rfidCard']['label'] ?? '';
    }

    return AccessHistoryModel(
      id: json['id'] ?? '',
      houseId: json['house_id'] ?? '',
      roomId: json['room_id'],
      roomName: rName,
      residentId: json['resident_id'],
      residentName: uName.isNotEmpty ? uName : (cLabel.isNotEmpty ? cLabel : 'Unknown'),
      rfidCardId: json['rfid_card_id'],
      cardUid: cUid,
      cardLabel: cLabel,
      accessMethod: json['access_method'] ?? 'RFID',
      status: json['status'] ?? 'DENIED',
      denialReason: json['denial_reason'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
