class SecurityEventModel {
  final String id;
  final String houseId;
  final String eventType; // MOTION_DETECTED, UNKNOWN_FACE, KNOWN_FACE_ENTRY, etc.
  final String severity; // LOW, MEDIUM, HIGH, CRITICAL
  final String? imageUrl;
  final String? description;
  final String status; // LOGGED, INVESTIGATING, CONFIRMED_THREAT, FALSE_ALARM, RESOLVED
  final DateTime createdAt;
  final AIAnalysisModel? aiAnalysis;

  SecurityEventModel({
    required this.id,
    required this.houseId,
    required this.eventType,
    required this.severity,
    this.imageUrl,
    this.description,
    required this.status,
    required this.createdAt,
    this.aiAnalysis,
  });

  factory SecurityEventModel.fromJson(Map<String, dynamic> json) {
    return SecurityEventModel(
      id: json['id'] ?? '',
      houseId: json['house_id'] ?? '',
      eventType: json['event_type'] ?? 'MOTION_DETECTED',
      severity: json['severity'] ?? 'LOW',
      imageUrl: json['image_url'],
      description: json['description'],
      status: json['status'] ?? 'LOGGED',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      aiAnalysis: json['aiAnalysis'] != null ? AIAnalysisModel.fromJson(json['aiAnalysis']) : null,
    );
  }
}

class AIAnalysisModel {
  final String id;
  final bool personDetected;
  final double personConfidence;
  final bool faceDetected;
  final double faceConfidence;
  final String faceRecognitionResult; // AUTHORIZED, UNKNOWN, UNCERTAIN, NO_FACE
  final String threatLevel; // NORMAL, SUSPICIOUS, CONFIRMED_THREAT
  final double riskScore;

  AIAnalysisModel({
    required this.id,
    required this.personDetected,
    required this.personConfidence,
    required this.faceDetected,
    required this.faceConfidence,
    required this.faceRecognitionResult,
    required this.threatLevel,
    required this.riskScore,
  });

  factory AIAnalysisModel.fromJson(Map<String, dynamic> json) {
    return AIAnalysisModel(
      id: json['id'] ?? '',
      personDetected: json['person_detected'] ?? false,
      personConfidence: (json['person_confidence'] as num?)?.toDouble() ?? 0.0,
      faceDetected: json['face_detected'] ?? false,
      faceConfidence: (json['face_confidence'] as num?)?.toDouble() ?? 0.0,
      faceRecognitionResult: json['face_recognition_result'] ?? 'NO_FACE',
      threatLevel: json['threat_level'] ?? 'NORMAL',
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
