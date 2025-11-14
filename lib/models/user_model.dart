import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final bool emailVerified;
  final String? avatarUrl;
  final String fullName;
  final String? gender; // 'male', 'female', 'other'
  final DateTime? dateOfBirth;
  final String role; // 'user', 'owner', 'admin'
  final String? phoneNumber;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'inactive', 'banned'

  UserModel({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.avatarUrl,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    required this.role,
    this.phoneNumber,
    this.address,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'emailVerified': emailVerified,
      'avatarUrl': avatarUrl,
      'fullName': fullName,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'role': role,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      emailVerified: map['emailVerified'] ?? false,
      avatarUrl: map['avatarUrl'],
      fullName: map['fullName'] ?? '',
      gender: map['gender'],
      dateOfBirth: _parseDateTime(map['dateOfBirth']),
      role: map['role'] ?? 'user',
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      status: map['status'] ?? 'active',
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

  UserModel copyWith({
    String? id,
    String? email,
    bool? emailVerified,
    String? avatarUrl,
    String? fullName,
    String? gender,
    DateTime? dateOfBirth,
    String? role,
    String? phoneNumber,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

