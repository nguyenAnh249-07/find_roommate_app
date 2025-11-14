import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final String? roomId; // Optional: liên quan đến phòng nào

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    required this.isRead,
    this.roomId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'roomId': roomId,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final createdAt = _parseDateTime(map['createdAt']) ?? DateTime.now();
    return MessageModel(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: createdAt,
      isRead: map['isRead'] == true || map['isRead'] == 'true',
      roomId: map['roomId']?.toString(),
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
}

