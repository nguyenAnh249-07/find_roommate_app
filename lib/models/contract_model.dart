import 'package:cloud_firestore/cloud_firestore.dart';

class ContractModel {
  final String id;
  final String roomId;
  final String ownerId;
  final List<String> tenantIds; // Danh sách người thuê
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double deposit; // Tiền cọc
  final String terms; // Điều khoản
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'expired', 'terminated'

  ContractModel({
    required this.id,
    required this.roomId,
    required this.ownerId,
    required this.tenantIds,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.deposit,
    required this.terms,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'ownerId': ownerId,
      'tenantIds': tenantIds,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'monthlyRent': monthlyRent,
      'deposit': deposit,
      'terms': terms,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory ContractModel.fromMap(Map<String, dynamic> map) {
    return ContractModel(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      tenantIds: List<String>.from(map['tenantIds'] ?? []),
      startDate: _parseDateTime(map['startDate']),
      endDate: _parseDateTime(map['endDate']),
      monthlyRent: (map['monthlyRent'] ?? 0).toDouble(),
      deposit: (map['deposit'] ?? 0).toDouble(),
      terms: map['terms'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      status: map['status'] ?? 'active',
    );
  }

  // Helper method to parse DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    // If it's already a DateTime, return it
    if (value is DateTime) return value;
    
    // If it's a Firestore Timestamp, convert to DateTime
    if (value is Timestamp) return value.toDate();
    
    // If it's a String, parse it
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }

  ContractModel copyWith({
    String? id,
    String? roomId,
    String? ownerId,
    List<String>? tenantIds,
    DateTime? startDate,
    DateTime? endDate,
    double? monthlyRent,
    double? deposit,
    String? terms,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return ContractModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      ownerId: ownerId ?? this.ownerId,
      tenantIds: tenantIds ?? this.tenantIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      deposit: deposit ?? this.deposit,
      terms: terms ?? this.terms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

