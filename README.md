# Find Roommate App

Ứng dụng tìm phòng trọ và bạn ở ghép được xây dựng bằng Flutter và Firebase.

## Tính năng chính

### Người dùng
- ✅ Đăng ký/Đăng nhập với Email/Password
- ✅ Xác thực OTP qua Email SMTP
- ✅ Quên mật khẩu với OTP
- ✅ Tìm kiếm và lọc phòng trọ
- ✅ Xem chi tiết phòng
- ✅ Nhắn tin với chủ trọ
- ✅ Gửi yêu cầu ở ghép
- ✅ Quản lý hồ sơ cá nhân

### Chủ trọ
- ✅ Đăng tin cho thuê
- ✅ Quản lý phòng của mình
- ✅ Duyệt yêu cầu ở ghép
- ✅ Xem thống kê

### Quản trị viên
- ✅ Duyệt bài đăng
- ✅ Quản lý người dùng
- ✅ Xem thống kê hệ thống

## Công nghệ

- **Flutter**: Framework chính
- **Firebase Auth**: Xác thực Email/Password
- **Cloud Firestore**: Database realtime
- **SMTP Email**: Gửi OTP qua email
- **Riverpod**: State management
- **Material 3**: Design system

## Cài đặt

1. Clone repository:
```bash
git clone <repository-url>
cd find_roommate_app
```

2. Cài đặt dependencies:
```bash
flutter pub get
```

3. Cấu hình Firebase:
   - Tạo Firebase project
   - Thêm file `google-services.json` vào `android/app/`
   - Cấu hình Firestore Security Rules

4. Cấu hình SMTP:
   - Mở file `lib/services/otp_service.dart`
   - Cập nhật SMTP credentials:
     ```dart
     static const String smtpUsername = 'your-email@gmail.com';
     static const String smtpPassword = 'your-app-password';
     ```

5. Chạy ứng dụng:
```bash
flutter run
```

## Cấu trúc dự án

```
lib/
├── main.dart                 # Entry point
├── core/                     # Core functionality
│   ├── theme/               # Theme configuration
│   └── providers/           # Riverpod providers
├── models/                   # Data models
├── services/                # Business logic
└── screens/                  # UI screens
    ├── auth/                # Authentication screens
    ├── home/                # Home screen
    ├── room/                # Room related screens
    ├── chat/                # Chat screens
    ├── profile/             # Profile screens
    ├── owner/               # Owner screens
    └── admin/               # Admin screens
```

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Rooms
    match /rooms/{roomId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        resource.data.ownerId == request.auth.uid;
    }
    
    // Posts
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.ownerId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Messages
    match /messages/{messageId} {
      allow read: if request.auth != null && 
        (resource.data.senderId == request.auth.uid || 
         resource.data.receiverId == request.auth.uid);
      allow create: if request.auth != null;
    }
    
    // Roommate Requests
    match /roommate_requests/{requestId} {
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.ownerId == request.auth.uid);
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        resource.data.ownerId == request.auth.uid;
    }
  }
}
```

## Lưu ý quan trọng

1. **SMTP Configuration**: Cần cấu hình SMTP credentials trong `otp_service.dart`
2. **Firebase Setup**: Đảm bảo đã setup Firebase project đúng cách
3. **Security Rules**: Cấu hình Firestore Security Rules để bảo vệ data
4. **Image URLs**: Tất cả ảnh phải là URL, không dùng Firebase Storage

## Tài liệu chi tiết

Xem file `DOCUMENTATION.md` để biết thêm chi tiết về:
- Kiến trúc hệ thống
- Database schema
- Use cases
- Flow diagrams
- ERD

## License

MIT License
