class CategoryModel {
  final String id;
  final String type; // 'room_type' or 'location'
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'inactive'

  CategoryModel({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      status: map['status'] ?? 'active',
    );
  }

  CategoryModel copyWith({
    String? id,
    String? type,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

