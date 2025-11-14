# Tài liệu hệ thống - Find Roommate App

## I. Tổng quan

Ứng dụng tìm phòng trọ và bạn ở ghép được xây dựng bằng Flutter với backend Firebase. Hệ thống hỗ trợ 3 vai trò chính: Người dùng, Chủ trọ, và Quản trị viên.

## II. Công nghệ sử dụng

### 1. Flutter
- **Lý do chọn**: 
  - Cross-platform (Android/iOS)
  - Performance tốt với native code
  - Hot reload nhanh chóng
  - Material 3 design system
  - Rich animation support

### 2. Firebase Authentication
- **Chỉ dùng Email/Password**: 
  - Đơn giản, không cần số điện thoại
  - Dễ quản lý và bảo mật
  - Không phụ thuộc vào SMS OTP

### 3. OTP qua SMTP Email
- **Lý do chọn**:
  - Không cần Firebase Phone Auth
  - Linh hoạt với nhiều SMTP provider (Gmail, Mailgun, SendGrid)
  - Chi phí thấp
  - Dễ tích hợp

### 4. Cloud Firestore
- **Lý do chọn**:
  - Real-time database
  - NoSQL linh hoạt
  - Tự động sync
  - Offline support

### 5. URL ảnh thay vì Firebase Storage
- **Lý do chọn**:
  - Giảm chi phí lưu trữ
  - Linh hoạt với nhiều nguồn ảnh
  - Dễ quản lý
  - Không cần upload/download

### 6. Không dùng Firebase Cloud Messaging
- **Lý do**:
  - Thông báo in-app realtime qua Firestore
  - Đơn giản hóa kiến trúc
  - Giảm phụ thuộc

## III. Kiến trúc hệ thống

### 1. Architecture Pattern: MVVM với Riverpod

```
┌─────────────────────────────────────────┐
│           UI Layer (Screens)            │
│  (Login, Home, RoomDetail, Chat, etc.)   │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│        State Management (Riverpod)       │
│  (Providers, StateNotifiers, Streams)    │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Services Layer                  │
│  (AuthService, FirestoreService,         │
│   OTPService, ChatService)               │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Models Layer                    │
│  (User, Room, Post, Message, etc.)       │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Firebase Backend                │
│  (Auth, Firestore, SMTP)                 │
└─────────────────────────────────────────┘
```

### 2. Cấu trúc thư mục

```
lib/
├── main.dart
├── core/
│   ├── theme/
│   │   └── app_theme.dart
│   └── providers/
│       ├── auth_provider.dart
│       ├── room_provider.dart
│       └── theme_provider.dart
├── models/
│   ├── user_model.dart
│   ├── room_model.dart
│   ├── post_model.dart
│   ├── message_model.dart
│   ├── roommate_request_model.dart
│   ├── contract_model.dart
│   ├── payment_model.dart
│   └── otp_model.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── otp_service.dart
│   └── chat_service.dart
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   ├── otp_verification_screen.dart
    │   └── forgot_password_screen.dart
    ├── home/
    │   ├── home_screen.dart
    │   └── widgets/
    │       └── room_card.dart
    ├── room/
    │   ├── room_detail_screen.dart
    │   ├── room_filter_screen.dart
    │   ├── roommate_request_screen.dart
    │   └── create_room_screen.dart
    ├── chat/
    │   └── chat_screen.dart
    ├── profile/
    │   └── profile_screen.dart
    ├── owner/
    │   ├── owner_dashboard_screen.dart
    │   └── manage_roommate_requests_screen.dart
    └── admin/
        └── admin_dashboard_screen.dart
```

## IV. Database Schema (Firestore)

### Collection: users
```json
{
  "id": "string",
  "email": "string",
  "emailVerified": "boolean",
  "avatarUrl": "string | null",
  "fullName": "string",
  "gender": "string | null",
  "dateOfBirth": "timestamp | null",
  "role": "string", // "user" | "owner" | "admin"
  "phoneNumber": "string | null",
  "address": "string | null",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "status": "string" // "active" | "inactive" | "banned"
}
```

### Collection: rooms
```json
{
  "id": "string",
  "ownerId": "string",
  "title": "string",
  "description": "string",
  "images": ["string"], // URLs
  "price": "number",
  "area": "number",
  "roomType": "string", // "single" | "double" | "shared" | "apartment"
  "address": "string",
  "district": "string",
  "city": "string",
  "latitude": "number | null",
  "longitude": "number | null",
  "capacity": "number",
  "occupants": ["string"], // User IDs
  "allowRoommate": "boolean",
  "amenities": ["string"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "status": "string" // "pending" | "approved" | "rejected" | "hidden" | "rented"
}
```

### Collection: posts
```json
{
  "id": "string",
  "roomId": "string",
  "ownerId": "string",
  "title": "string",
  "description": "string",
  "images": ["string"], // URLs
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "status": "string" // "pending" | "approved" | "rejected" | "hidden"
}
```

### Collection: roommate_requests
```json
{
  "id": "string",
  "userId": "string",
  "roomId": "string",
  "ownerId": "string",
  "message": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "status": "string" // "pending" | "approved" | "rejected"
}
```

### Collection: contracts
```json
{
  "id": "string",
  "roomId": "string",
  "ownerId": "string",
  "tenantIds": ["string"],
  "startDate": "timestamp",
  "endDate": "timestamp",
  "monthlyRent": "number",
  "deposit": "number",
  "terms": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "status": "string" // "active" | "expired" | "terminated"
}
```

### Collection: payments
```json
{
  "id": "string",
  "contractId": "string",
  "roomId": "string",
  "tenantId": "string",
  "ownerId": "string",
  "amount": "number",
  "dueDate": "timestamp",
  "paidDate": "timestamp | null",
  "paymentMethod": "string",
  "description": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "status": "string" // "pending" | "paid" | "overdue" | "cancelled"
}
```

### Collection: messages
```json
{
  "id": "string",
  "senderId": "string",
  "receiverId": "string",
  "text": "string",
  "createdAt": "timestamp",
  "isRead": "boolean",
  "roomId": "string | null"
}
```

### Collection: otps
```json
{
  "id": "string",
  "email": "string",
  "code": "string", // 6 digits
  "createdAt": "timestamp",
  "expiresAt": "timestamp",
  "isUsed": "boolean",
  "purpose": "string" // "register" | "forgot_password"
}
```

## V. ERD (Entity Relationship Diagram)

```
┌─────────────┐
│    User     │
├─────────────┤
│ id (PK)     │
│ email       │
│ fullName    │
│ role        │
│ ...         │
└──────┬──────┘
       │
       │ 1:N
       │
┌──────▼──────────────┐
│       Room          │
├─────────────────────┤
│ id (PK)             │
│ ownerId (FK)        │──┐
│ title               │  │
│ price               │  │
│ allowRoommate       │  │
│ ...                 │  │
└──────┬──────────────┘  │
       │                  │
       │ 1:N              │
       │                  │
┌──────▼──────────────┐  │
│   Post              │  │
├─────────────────────┤  │
│ id (PK)             │  │
│ roomId (FK)         │──┘
│ ownerId (FK)        │──┐
│ status              │  │
│ ...                 │  │
└─────────────────────┘  │
                         │
┌────────────────────────┘
│
│ 1:N
│
┌──────────────▼──────────────┐
│   RoommateRequest           │
├─────────────────────────────┤
│ id (PK)                     │
│ userId (FK)                 │──┐
│ roomId (FK)                 │  │
│ ownerId (FK)                │──┘
│ status                      │
│ ...                         │
└─────────────────────────────┘

┌─────────────┐
│  Contract   │
├─────────────┤
│ id (PK)     │
│ roomId (FK) │
│ ownerId (FK)│
│ tenantIds   │
│ ...         │
└──────┬──────┘
       │
       │ 1:N
       │
┌──────▼──────┐
│  Payment    │
├─────────────┤
│ id (PK)     │
│ contractId  │
│ tenantId    │
│ ...         │
└─────────────┘

┌─────────────┐
│   Message   │
├─────────────┤
│ id (PK)     │
│ senderId    │
│ receiverId  │
│ text        │
│ ...         │
└─────────────┘
```

## VI. Use Cases

### A. Người dùng chung

#### UC-01: Đăng ký tài khoản
- **Actor**: Người dùng mới
- **Precondition**: Chưa có tài khoản
- **Flow**:
  1. User nhập email, password, họ tên
  2. Hệ thống tạo OTP và gửi qua email
  3. User nhập OTP
  4. Hệ thống xác thực OTP
  5. Tạo tài khoản Firebase Auth
  6. Lưu thông tin vào Firestore
- **Postcondition**: User đã đăng ký thành công

#### UC-02: Đăng nhập
- **Actor**: Người dùng
- **Precondition**: Đã có tài khoản
- **Flow**:
  1. User nhập email và password
  2. Hệ thống xác thực
  3. Đăng nhập thành công
- **Postcondition**: User đã đăng nhập

#### UC-03: Quên mật khẩu
- **Actor**: Người dùng
- **Flow**:
  1. User nhập email
  2. Hệ thống gửi OTP qua email
  3. User nhập OTP và mật khẩu mới
  4. Hệ thống xác thực và đổi mật khẩu
- **Postcondition**: Mật khẩu đã được đổi

### B. Người tìm phòng

#### UC-04: Tìm kiếm phòng
- **Actor**: Người tìm phòng
- **Flow**:
  1. User mở màn hình tìm kiếm
  2. Nhập từ khóa hoặc chọn bộ lọc
  3. Hệ thống hiển thị danh sách phòng phù hợp
- **Postcondition**: Hiển thị kết quả tìm kiếm

#### UC-05: Xem chi tiết phòng
- **Actor**: Người tìm phòng
- **Flow**:
  1. User chọn phòng từ danh sách
  2. Hiển thị thông tin chi tiết
  3. User có thể nhắn tin hoặc xin ở ghép
- **Postcondition**: User đã xem thông tin phòng

#### UC-06: Gửi yêu cầu ở ghép
- **Actor**: Người tìm phòng
- **Precondition**: Phòng cho phép ở ghép và còn chỗ
- **Flow**:
  1. User chọn "Xin ở ghép"
  2. Nhập lời nhắn
  3. Gửi yêu cầu
  4. Chủ trọ nhận thông báo
- **Postcondition**: Yêu cầu đã được gửi

### C. Chủ trọ

#### UC-07: Đăng tin cho thuê
- **Actor**: Chủ trọ
- **Flow**:
  1. Chủ trọ tạo tin với thông tin phòng
  2. Thêm URL ảnh
  3. Gửi lên hệ thống
  4. Admin duyệt tin
  5. Tin xuất hiện trên app
- **Postcondition**: Tin đã được đăng

#### UC-08: Duyệt yêu cầu ở ghép
- **Actor**: Chủ trọ
- **Flow**:
  1. Chủ trọ xem danh sách yêu cầu
  2. Xem thông tin người xin
  3. Duyệt hoặc từ chối
  4. Nếu duyệt, thêm user vào danh sách người thuê
- **Postcondition**: Yêu cầu đã được xử lý

### D. Quản trị viên

#### UC-09: Duyệt bài đăng
- **Actor**: Admin
- **Flow**:
  1. Admin xem danh sách tin chờ duyệt
  2. Xem chi tiết tin
  3. Duyệt hoặc từ chối
  4. Cập nhật trạng thái phòng
- **Postcondition**: Tin đã được duyệt

## VII. Luồng hoạt động (Flow Diagrams)

### 1. Luồng đăng ký + OTP

```
User → Nhập thông tin → Tạo OTP → Gửi email SMTP
  ↓
Nhập OTP → Xác thực → Tạo Firebase Auth → Lưu Firestore
  ↓
Đăng nhập thành công
```

### 2. Luồng tìm phòng

```
User → Tìm kiếm/Lọc → Hiển thị danh sách
  ↓
Chọn phòng → Xem chi tiết
  ↓
Nhắn tin / Xin ở ghép
```

### 3. Luồng ở ghép

```
User → Xem phòng → Gửi yêu cầu
  ↓
Chủ trọ nhận thông báo → Xem yêu cầu
  ↓
Duyệt / Từ chối
  ↓
Nếu duyệt → Thêm vào occupants
```

### 4. Luồng đăng tin

```
Chủ trọ → Tạo tin → Thêm URL ảnh → Gửi
  ↓
Admin nhận thông báo → Xem tin
  ↓
Duyệt / Từ chối
  ↓
Nếu duyệt → Phòng xuất hiện trên app
```

## VIII. UI/UX Design

### 1. Material 3 Design System
- **Color Scheme**: Teal/Cyan primary colors
- **Typography**: Inter/Poppins/Roboto
- **Border Radius**: 16-24dp
- **Elevation**: 2-4dp cho cards
- **Spacing**: 8dp grid system

### 2. Dark Mode Support
- Tự động chuyển theo system
- Hoặc toggle thủ công
- Màu sắc tối ưu cho cả 2 chế độ

### 3. Animations
- **Fade**: Transition giữa các màn hình
- **Slide**: Navigation animations
- **Hero**: Image transitions
- **Shimmer**: Loading states

### 4. Responsive Design
- Hỗ trợ nhiều kích thước màn hình
- Layout linh hoạt
- Touch-friendly buttons (min 48dp)

## IX. Tính năng nâng cao (Gợi ý)

1. **Lưu phòng yêu thích**: User có thể bookmark phòng
2. **Gợi ý phòng phù hợp**: AI/ML recommendation
3. **Lịch hẹn xem phòng**: Đặt lịch xem phòng
4. **Đánh giá phòng/chủ trọ**: Rating và review system
5. **Thông báo realtime**: In-app notifications qua Firestore
6. **Tìm kiếm nâng cao**: Filter theo nhiều tiêu chí
7. **Bản đồ**: Hiển thị vị trí phòng trên map

## X. Bảo mật

1. **Firebase Security Rules**: Bảo vệ Firestore data
2. **OTP Expiration**: OTP hết hạn sau 10 phút
3. **Email Verification**: Xác thực email khi đăng ký
4. **Role-based Access**: Phân quyền theo role
5. **Input Validation**: Validate tất cả input

## XI. Testing

1. **Unit Tests**: Test models và services
2. **Widget Tests**: Test UI components
3. **Integration Tests**: Test luồng hoạt động
4. **E2E Tests**: Test toàn bộ user flows

## XII. Deployment

1. **Android**: Build APK/AAB
2. **Firebase Setup**: Cấu hình Firebase project
3. **SMTP Configuration**: Setup email service
4. **Environment Variables**: Cấu hình secrets

## XIII. Maintenance

1. **Error Logging**: Firebase Crashlytics
2. **Analytics**: Firebase Analytics
3. **Performance Monitoring**: Firebase Performance
4. **Regular Updates**: Cập nhật dependencies

---

**Tài liệu này được tạo tự động và có thể được cập nhật theo yêu cầu.**

