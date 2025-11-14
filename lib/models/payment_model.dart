import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String contractId;
  final String roomId;
  final String tenantId;
  final String ownerId;
  final double amount;
  final DateTime dueDate; // Hạn thanh toán
  final DateTime? paidDate; // Ngày thanh toán thực tế
  final String paymentMethod; // 'cash', 'bank_transfer', 'momo', 'zalopay'
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'pending', 'paid', 'overdue', 'cancelled'

  PaymentModel({
    required this.id,
    required this.contractId,
    required this.roomId,
    required this.tenantId,
    required this.ownerId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.paymentMethod,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contractId': contractId,
      'roomId': roomId,
      'tenantId': tenantId,
      'ownerId': ownerId,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] ?? '',
      contractId: map['contractId'] ?? '',
      roomId: map['roomId'] ?? '',
      tenantId: map['tenantId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      dueDate: _parseDateTime(map['dueDate']),
      paidDate: _parseDateTimeNullable(map['paidDate']),
      paymentMethod: map['paymentMethod'] ?? 'cash',
      description: map['description'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      status: map['status'] ?? 'pending',
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

  // Helper method to parse nullable DateTime from various formats
  static DateTime? _parseDateTimeNullable(dynamic value) {
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

  bool get isOverdue => 
      status == 'pending' && DateTime.now().isAfter(dueDate);

  PaymentModel copyWith({
    String? id,
    String? contractId,
    String? roomId,
    String? tenantId,
    String? ownerId,
    double? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    String? paymentMethod,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      roomId: roomId ?? this.roomId,
      tenantId: tenantId ?? this.tenantId,
      ownerId: ownerId ?? this.ownerId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

