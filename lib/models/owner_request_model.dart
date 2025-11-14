import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerRequestModel {
  final String id;
  final String userId;
  final String? reason; // Lý do đăng ký làm owner
  final String status; // 'pending', 'approved', 'rejected'
  final String? adminId; // ID của admin phê duyệt/từ chối
  final String? adminNote; // Ghi chú của admin
  final DateTime createdAt;
  final DateTime updatedAt;

  OwnerRequestModel({
    required this.id,
    required this.userId,
    this.reason,
    required this.status,
    this.adminId,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'reason': reason,
      'status': status,
      'adminId': adminId,
      'adminNote': adminNote,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OwnerRequestModel.fromMap(Map<String, dynamic> map) {
    return OwnerRequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      reason: map['reason'],
      status: map['status'] ?? 'pending',
      adminId: map['adminId'],
      adminNote: map['adminNote'],
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  // Helper method to parse DateTime from various formats
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    // If it's already a DateTime, return it
    if (value is DateTime) return value;
    
    // If it's a Firestore Timestamp, convert to DateTime
    if (value is Timestamp) return value.toDate();
    
    // If it's a String, parse it
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  OwnerRequestModel copyWith({
    String? id,
    String? userId,
    String? reason,
    String? status,
    String? adminId,
    String? adminNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OwnerRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      adminId: adminId ?? this.adminId,
      adminNote: adminNote ?? this.adminNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

