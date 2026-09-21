class DetectionEventModel {
  final String id;
  final String houseId;
  final String? cameraId;
  final String objectType; // person, vehicle, animal, package, etc.
  final String? className;
  final double confidence;
  final Map<String, dynamic>? boundingBox;
  final bool hasFace;
  final double faceConfidence;
  final String status; // DETECTED, ANALYZING, NORMAL, SUSPICIOUS, VERIFIED_THREAT, RESOLVED
  final String? imageUrl;
  final DateTime timestamp;

  DetectionEventModel({
    required this.id,
    required this.houseId,
    this.cameraId,
    required this.objectType,
    this.className,
    required this.confidence,
    this.boundingBox,
    required this.hasFace,
    required this.faceConfidence,
    required this.status,
    this.imageUrl,
    required this.timestamp,
  });

  bool get isVerifiedThreat => status == 'VERIFIED_THREAT';

  factory DetectionEventModel.fromJson(Map<String, dynamic> json) {
    return DetectionEventModel(
      id: json['id'] ?? '',
      houseId: json['house_id'] ?? '',
      cameraId: json['camera_id'],
      objectType: json['object_type'] ?? 'other',
      className: json['class_name'] ?? json['object_type'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      boundingBox: json['bounding_box'] is Map<String, dynamic>
          ? json['bounding_box']
          : null,
      hasFace: json['has_face'] ?? false,
      faceConfidence: (json['face_confidence'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'DETECTED',
      imageUrl: json['image_url'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
