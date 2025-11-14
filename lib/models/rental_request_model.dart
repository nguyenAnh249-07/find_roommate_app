class RentalRequestModel {
  final String id;
  final String userId; // Người xin thuê
  final String roomId;
  final String ownerId;
  final String message;
  final DateTime startDate; // Ngày muốn bắt đầu thuê
  final int durationMonths; // Thời gian thuê (tháng)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'pending', 'approved', 'rejected'

  RentalRequestModel({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.ownerId,
    required this.message,
    required this.startDate,
    required this.durationMonths,
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
      'startDate': startDate.toIso8601String(),
      'durationMonths': durationMonths,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory RentalRequestModel.fromMap(Map<String, dynamic> map) {
    return RentalRequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      roomId: map['roomId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      message: map['message'] ?? '',
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : DateTime.now(),
      durationMonths: map['durationMonths'] ?? 1,
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

