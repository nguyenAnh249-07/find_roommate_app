import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final List<String> images; // URLs
  final double price;
  final double area; // m²
  final String roomType; // 'single', 'double', 'shared', 'apartment'
  final String address;
  final String district;
  final String city;
  final double? latitude;
  final double? longitude;
  final int capacity; // Số người tối đa
  final List<String> occupants; // User IDs đang ở
  final bool allowRoommate; // Cho phép ở ghép
  final List<String> amenities; // Tiện ích: ['wifi', 'aircon', 'parking', ...]
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'pending', 'approved', 'rejected', 'hidden', 'rented'

  RoomModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.images,
    required this.price,
    required this.area,
    required this.roomType,
    required this.address,
    required this.district,
    required this.city,
    this.latitude,
    this.longitude,
    required this.capacity,
    required this.occupants,
    required this.allowRoommate,
    required this.amenities,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'images': images,
      'price': price,
      'area': area,
      'roomType': roomType,
      'address': address,
      'district': district,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'occupants': occupants,
      'allowRoommate': allowRoommate,
      'amenities': amenities,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      price: (map['price'] ?? 0).toDouble(),
      area: (map['area'] ?? 0).toDouble(),
      roomType: map['roomType'] ?? 'single',
      address: map['address'] ?? '',
      district: map['district'] ?? '',
      city: map['city'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      capacity: map['capacity'] ?? 1,
      occupants: List<String>.from(map['occupants'] ?? []),
      allowRoommate: map['allowRoommate'] ?? false,
      amenities: List<String>.from(map['amenities'] ?? []),
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

  bool get isAvailable => occupants.length < capacity;
  bool get isFullyOccupied => occupants.length >= capacity;

  RoomModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    List<String>? images,
    double? price,
    double? area,
    String? roomType,
    String? address,
    String? district,
    String? city,
    double? latitude,
    double? longitude,
    int? capacity,
    List<String>? occupants,
    bool? allowRoommate,
    List<String>? amenities,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return RoomModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      price: price ?? this.price,
      area: area ?? this.area,
      roomType: roomType ?? this.roomType,
      address: address ?? this.address,
      district: district ?? this.district,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      occupants: occupants ?? this.occupants,
      allowRoommate: allowRoommate ?? this.allowRoommate,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

