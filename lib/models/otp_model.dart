class OTPModel {
  final String id;
  final String email;
  final String code; // 6 chữ số
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String purpose; // 'register', 'forgot_password'

  OTPModel({
    required this.id,
    required this.email,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    required this.isUsed,
    required this.purpose,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'code': code,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed,
      'purpose': purpose,
    };
  }

  factory OTPModel.fromMap(Map<String, dynamic> map) {
    return OTPModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      code: map['code'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'])
          : DateTime.now().add(const Duration(minutes: 10)),
      isUsed: map['isUsed'] ?? false,
      purpose: map['purpose'] ?? 'register',
    );
  }

  bool get isValid => !isUsed && DateTime.now().isBefore(expiresAt);
}

