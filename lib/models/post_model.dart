import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String roomId;
  final String ownerId;
  final String title;
  final String description;
  final List<String> images; // URLs
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'pending', 'approved', 'rejected', 'hidden'
  final String? adminNote; // Lý do từ chối (nếu có)

  PostModel({
    required this.id,
    required this.roomId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.adminNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'adminNote': adminNote,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      status: map['status'] ?? 'pending',
      adminNote: map['adminNote'],
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

  PostModel copyWith({
    String? id,
    String? roomId,
    String? ownerId,
    String? title,
    String? description,
    List<String>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? adminNote,
  }) {
    return PostModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}

