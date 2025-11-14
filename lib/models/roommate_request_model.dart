class RoommateRequestModel {
  final String id;
  final String userId; // Người xin ở ghép
  final String roomId;
  final String ownerId;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'pending', 'approved', 'rejected'

  RoommateRequestModel({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.ownerId,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'roomId': roomId,
      'ownerId': ownerId,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory RoommateRequestModel.fromMap(Map<String, dynamic> map) {
    return RoommateRequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      roomId: map['roomId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }
}

