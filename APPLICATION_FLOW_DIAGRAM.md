# Sơ Đồ Luồng Ứng Dụng Find Roommate App

## 📊 Sơ Đồ Tổng Quát

```mermaid
graph TB
    Start([Khởi động App]) --> Init[Khởi tạo Firebase]
    Init --> CheckAuth{Đã đăng nhập?}
    
    CheckAuth -->|Chưa| LoginScreen[Màn hình Đăng nhập]
    CheckAuth -->|Rồi| LoadUser[Load thông tin User]
    
    LoginScreen --> Register[Đăng ký]
    LoginScreen --> ForgotPass[Quên mật khẩu]
    LoginScreen --> Login[Đăng nhập]
    
    Register --> OTPVerify[Xác thực OTP Email]
    OTPVerify -->|Thành công| SaveUser[Lưu User vào Firestore]
    OTPVerify -->|Thất bại| Register
    
    ForgotPass --> OTPVerify2[Gửi OTP Reset]
    OTPVerify2 --> ResetPass[Đặt lại mật khẩu]
    ResetPass --> LoginScreen
    
    Login --> LoadUser
    SaveUser --> LoadUser
    
    LoadUser --> CheckRole{Phân quyền User}
    
    CheckRole -->|user| UserHome[Home Screen - User]
    CheckRole -->|owner| OwnerDashboard[Owner Dashboard]
    CheckRole -->|admin| AdminDashboard[Admin Dashboard]
    
    %% User Flow
    UserHome --> BrowseRooms[Tìm kiếm/Lọc phòng]
    BrowseRooms --> RoomDetail[Chi tiết phòng]
    RoomDetail --> Chat[Chat với chủ trọ]
    RoomDetail --> SendRequest[Gửi yêu cầu]
    RoomDetail --> SaveRoom[Lưu phòng yêu thích]
    
    SendRequest --> RoommateReq[Yêu cầu ở ghép]
    SendRequest --> RentalReq[Yêu cầu thuê phòng]
    
    UserHome --> MyRequests[Yêu cầu của tôi]
    UserHome --> SavedRooms[Phòng đã lưu]
    UserHome --> TenantDashboard[Tenant Dashboard]
    UserHome --> Profile[Hồ sơ cá nhân]
    UserHome --> Support[Hỗ trợ]
    
    TenantDashboard --> ViewContracts[Xem hợp đồng]
    TenantDashboard --> ViewPayments[Xem thanh toán]
    
    %% Owner Flow
    OwnerDashboard --> CreateRoom[Tạo phòng mới]
    OwnerDashboard --> MyRooms[Phòng của tôi]
    OwnerDashboard --> ManageRoommateReq[Quản lý yêu cầu ở ghép]
    OwnerDashboard --> ManageRentalReq[Quản lý yêu cầu thuê]
    OwnerDashboard --> ViewOccupants[Xem người ở]
    OwnerDashboard --> Contracts[Quản lý hợp đồng]
    OwnerDashboard --> Payments[Quản lý thanh toán]
    OwnerDashboard --> Statistics[Thống kê doanh thu]
    
    CreateRoom --> CreatePost[Tạo bài đăng]
    CreatePost --> WaitApproval[Chờ Admin duyệt]
    
    MyRooms --> EditRoom[Sửa phòng]
    MyRooms --> HideRoom[Ẩn phòng]
    MyRooms --> DeleteRoom[Xóa phòng]
    
    ManageRoommateReq --> ApproveRoommate[Duyệt/Từ chối ở ghép]
    ManageRentalReq --> ApproveRental[Duyệt/Từ chối thuê]
    
    ApproveRoommate --> CreateContract
    ApproveRental --> CreateContract[Tạo hợp đồng]
    CreateContract --> CreatePayment[Tạo hóa đơn]
    
    %% Admin Flow
    AdminDashboard --> PendingPosts[Bài đăng chờ duyệt]
    AdminDashboard --> UserManagement[Quản lý người dùng]
    AdminDashboard --> CategoryManagement[Quản lý danh mục]
    AdminDashboard --> AdminStatistics[Thống kê hệ thống]
    AdminDashboard --> OwnerRequests[Yêu cầu trở thành Owner]
    
    PendingPosts --> ApprovePost[Duyệt bài đăng]
    PendingPosts --> RejectPost[Từ chối bài đăng]
    
    UserManagement --> ChangeRole[Đổi vai trò]
    UserManagement --> BanUser[Khóa tài khoản]
    
    CategoryManagement --> AddCategory[Thêm danh mục]
    CategoryManagement --> DeleteCategory[Xóa danh mục]
    
    OwnerRequests --> ApproveOwner[Duyệt yêu cầu Owner]
    OwnerRequests --> RejectOwner[Từ chối yêu cầu]
    
    %% Logout
    UserHome --> Logout[Đăng xuất]
    OwnerDashboard --> Logout
    AdminDashboard --> Logout
    Logout --> LoginScreen
    
    style Start fill:#e1f5ff
    style LoginScreen fill:#fff4e6
    style UserHome fill:#e8f5e9
    style OwnerDashboard fill:#fff3e0
    style AdminDashboard fill:#f3e5f5
    style Logout fill:#ffebee
```

## 🔐 Luồng Xác Thực Chi Tiết

```mermaid
sequenceDiagram
    participant U as User
    participant App as Ứng dụng
    participant Auth as Firebase Auth
    participant OTP as OTP Service
    participant Firestore as Cloud Firestore
    
    Note over U,Firestore: Đăng ký tài khoản mới
    U->>App: Nhập email, password, thông tin
    App->>Auth: createUserWithEmailAndPassword()
    Auth-->>App: UserCredential
    App->>OTP: Gửi OTP qua Email SMTP
    OTP-->>U: Email chứa mã OTP
    U->>App: Nhập mã OTP
    App->>OTP: Xác thực OTP
    OTP-->>App: Xác thực thành công
    App->>Firestore: Lưu UserModel (role: 'user')
    Firestore-->>App: Lưu thành công
    App-->>U: Chuyển đến Home Screen
    
    Note over U,Firestore: Đăng nhập
    U->>App: Nhập email, password
    App->>Auth: signInWithEmailAndPassword()
    Auth-->>App: UserCredential
    App->>Firestore: Lấy UserModel theo userId
    Firestore-->>App: UserModel với role
    App->>App: Route theo role (user/owner/admin)
    App-->>U: Hiển thị Dashboard tương ứng
    
    Note over U,Firestore: Quên mật khẩu
    U->>App: Nhập email
    App->>OTP: Gửi OTP Reset Password
    OTP-->>U: Email chứa mã OTP
    U->>App: Nhập mã OTP
    App->>OTP: Xác thực OTP
    OTP-->>App: Xác thực thành công
    App->>U: Cho phép đặt lại mật khẩu
    U->>App: Nhập mật khẩu mới
    App->>Auth: updatePassword()
    Auth-->>App: Cập nhật thành công
    App-->>U: Chuyển đến Login Screen
```

## 👤 Luồng Người Dùng (User)

```mermaid
graph LR
    A[Home Screen] --> B[Tìm kiếm/Lọc phòng]
    A --> C[Phòng đã lưu]
    A --> D[Yêu cầu của tôi]
    A --> E[Tenant Dashboard]
    A --> F[Hồ sơ]
    A --> G[Hỗ trợ]
    
    B --> H[Chi tiết phòng]
    H --> I[Chat với chủ trọ]
    H --> J[Gửi yêu cầu ở ghép]
    H --> K[Gửi yêu cầu thuê]
    H --> L[Lưu phòng]
    
    J --> M[Chờ Owner duyệt]
    K --> M
    
    M -->|Được duyệt| N[Owner tạo hợp đồng]
    N --> O[Tenant xem hợp đồng]
    O --> P[Owner tạo hóa đơn]
    P --> Q[Tenant xem thanh toán]
    
    E --> O
    E --> Q
    
    style A fill:#e8f5e9
    style H fill:#c8e6c9
    style N fill:#a5d6a7
```

## 🏠 Luồng Chủ Trọ (Owner)

```mermaid
graph TB
    A[Owner Dashboard] --> B[Tạo phòng mới]
    A --> C[Phòng của tôi]
    A --> D[Yêu cầu ở ghép]
    A --> E[Yêu cầu thuê]
    A --> F[Người đang ở]
    A --> G[Hợp đồng]
    A --> H[Thanh toán]
    A --> I[Thống kê]
    
    B --> J[Điền thông tin phòng]
    J --> K[Tạo bài đăng]
    K --> L[Chờ Admin duyệt]
    L -->|Được duyệt| M[Bài đăng hiển thị]
    L -->|Bị từ chối| N[Chỉnh sửa lại]
    N --> K
    
    C --> O[Sửa phòng]
    C --> P[Ẩn phòng]
    C --> Q[Xóa phòng]
    
    D --> R[Duyệt/Từ chối yêu cầu]
    E --> S[Duyệt/Từ chối yêu cầu]
    
    R -->|Đồng ý| T[Tạo hợp đồng]
    S -->|Đồng ý| T
    
    T --> U[Tạo hóa đơn]
    U --> V[Quản lý thanh toán]
    
    F --> W[Xem danh sách người ở]
    W --> X[Xem hồ sơ người thuê]
    
    I --> Y[Doanh thu]
    I --> Z[Số phòng]
    I --> AA[Số hợp đồng]
    
    style A fill:#fff3e0
    style T fill:#ffe0b2
    style I fill:#ffcc80
```

## 👨‍💼 Luồng Quản Trị Viên (Admin)

```mermaid
graph TB
    A[Admin Dashboard] --> B[Bài đăng chờ duyệt]
    A --> C[Quản lý người dùng]
    A --> D[Quản lý danh mục]
    A --> E[Thống kê hệ thống]
    A --> F[Yêu cầu trở thành Owner]
    
    B --> G[Duyệt bài đăng]
    B --> H[Từ chối bài đăng]
    G --> I[Bài đăng hiển thị]
    H --> J[Gửi thông báo từ chối]
    
    C --> K[Xem danh sách users]
    K --> L[Đổi vai trò]
    K --> M[Khóa/Kích hoạt tài khoản]
    K --> N[Xem hồ sơ]
    
    D --> O[Quản lý loại phòng]
    D --> P[Quản lý khu vực]
    O --> Q[Thêm/Xóa loại phòng]
    P --> R[Thêm/Xóa khu vực]
    
    E --> S[Thống kê users]
    E --> T[Thống kê phòng]
    E --> U[Thống kê bài đăng]
    E --> V[Thống kê hợp đồng & thanh toán]
    
    F --> W[Duyệt yêu cầu Owner]
    F --> X[Từ chối yêu cầu Owner]
    W --> Y[Cập nhật role: owner]
    
    style A fill:#f3e5f5
    style G fill:#e1bee7
    style E fill:#ce93d8
```

## 💬 Luồng Chat

```mermaid
sequenceDiagram
    participant U as User
    participant App as Ứng dụng
    participant Firestore as Cloud Firestore
    participant O as Owner
    
    U->>App: Xem chi tiết phòng
    App->>App: Hiển thị nút "Chat với chủ trọ"
    U->>App: Nhấn nút Chat
    App->>Firestore: Lấy ownerId từ Room
    Firestore-->>App: ownerId
    App->>App: Mở Chat Screen với ownerId
    
    Note over U,O: Real-time Chat
    U->>App: Nhập tin nhắn
    App->>Firestore: Lưu MessageModel
    Firestore-->>O: Real-time update (Stream)
    O->>App: Xem tin nhắn
    O->>App: Trả lời
    App->>Firestore: Lưu MessageModel
    Firestore-->>U: Real-time update (Stream)
    U->>App: Xem tin nhắn mới
    
    Note over U,O: Đánh dấu đã đọc
    U->>App: Mở cuộc trò chuyện
    App->>Firestore: markMessageAsRead()
    Firestore-->>App: Cập nhật isRead = true
```

## 📝 Luồng Tạo và Duyệt Bài Đăng

```mermaid
sequenceDiagram
    participant O as Owner
    participant App as Ứng dụng
    participant Firestore as Cloud Firestore
    participant A as Admin
    
    Note over O,A: Owner tạo phòng và bài đăng
    O->>App: Tạo phòng mới
    App->>Firestore: Lưu RoomModel
    Firestore-->>App: Room đã lưu
    O->>App: Tạo bài đăng cho phòng
    App->>Firestore: Lưu PostModel (status: 'pending')
    Firestore-->>App: Post đã lưu
    
    Note over O,A: Admin duyệt bài đăng
    A->>App: Xem danh sách bài đăng chờ duyệt
    App->>Firestore: Lấy Posts (status: 'pending')
    Firestore-->>App: Danh sách Posts
    App-->>A: Hiển thị danh sách
    
    A->>App: Xem chi tiết bài đăng
    App->>Firestore: Lấy RoomModel từ roomId
    Firestore-->>App: RoomModel
    App-->>A: Hiển thị thông tin phòng và bài đăng
    
    alt Duyệt bài đăng
        A->>App: Nhấn "Duyệt"
        App->>Firestore: updatePostStatus('approved')
        Firestore-->>App: Cập nhật thành công
        App-->>O: Thông báo bài đăng đã được duyệt
    else Từ chối bài đăng
        A->>App: Nhấn "Từ chối" + nhập lý do
        App->>Firestore: updatePostStatus('rejected', adminNote)
        Firestore-->>App: Cập nhật thành công
        App-->>O: Thông báo bài đăng bị từ chối + lý do
    end
    
    Note over O,A: User xem bài đăng
    User->>App: Tìm kiếm phòng
    App->>Firestore: Lấy Rooms (status: 'available') + Posts (status: 'approved')
    Firestore-->>App: Danh sách phòng đã duyệt
    App-->>User: Hiển thị danh sách phòng
```

## 🔄 Luồng Yêu Cầu và Hợp Đồng

```mermaid
graph TB
    A[User xem phòng] --> B[Gửi yêu cầu]
    B --> C{Yêu cầu gì?}
    
    C -->|Ở ghép| D[Roommate Request]
    C -->|Thuê phòng| E[Rental Request]
    
    D --> F[Owner xem yêu cầu]
    E --> F
    
    F --> G{Quyết định}
    G -->|Đồng ý| H[Tạo hợp đồng]
    G -->|Từ chối| I[Yêu cầu bị từ chối]
    
    H --> J[ContractModel]
    J --> K[Tenant xem hợp đồng]
    
    H --> L[Tạo hóa đơn]
    L --> M[PaymentModel]
    M --> N[Tenant xem thanh toán]
    
    N --> O{Thanh toán}
    O -->|Đã thanh toán| P[Owner cập nhật trạng thái]
    O -->|Chưa| Q[Chờ thanh toán]
    
    style H fill:#a5d6a7
    style L fill:#c8e6c9
    style P fill:#81c784
```

## 🗄️ Cấu Trúc Database (Firestore)

```mermaid
erDiagram
    USERS ||--o{ ROOMS : "owns"
    USERS ||--o{ POSTS : "creates"
    USERS ||--o{ ROOMMATE_REQUESTS : "sends"
    USERS ||--o{ RENTAL_REQUESTS : "sends"
    USERS ||--o{ CONTRACTS : "has"
    USERS ||--o{ PAYMENTS : "pays"
    USERS ||--o{ MESSAGES : "sends/receives"
    
    ROOMS ||--o| POSTS : "has"
    ROOMS ||--o{ ROOMMATE_REQUESTS : "receives"
    ROOMS ||--o{ RENTAL_REQUESTS : "receives"
    ROOMS ||--o{ CONTRACTS : "has"
    
    CONTRACTS ||--o{ PAYMENTS : "has"
    
    USERS {
        string id PK
        string email
        string fullName
        string role
        string status
        array savedRooms
    }
    
    ROOMS {
        string id PK
        string ownerId FK
        string title
        string description
        double price
        double area
        string status
    }
    
    POSTS {
        string id PK
        string roomId FK
        string ownerId FK
        string status
        string adminNote
    }
    
    ROOMMATE_REQUESTS {
        string id PK
        string userId FK
        string ownerId FK
        string roomId FK
        string status
    }
    
    RENTAL_REQUESTS {
        string id PK
        string userId FK
        string ownerId FK
        string roomId FK
        string status
    }
    
    CONTRACTS {
        string id PK
        string ownerId FK
        array tenantIds FK
        string roomId FK
        datetime startDate
        datetime endDate
    }
    
    PAYMENTS {
        string id PK
        string ownerId FK
        string tenantId FK
        string contractId FK
        double amount
        string status
    }
    
    MESSAGES {
        string id PK
        string senderId FK
        string receiverId FK
        string content
        bool isRead
    }
```

## 🎯 Tóm Tắt Luồng Chính

### 1. **Luồng Khởi Động**
- App khởi động → Khởi tạo Firebase
- Kiểm tra trạng thái đăng nhập
- Nếu chưa đăng nhập → Login Screen
- Nếu đã đăng nhập → Load User → Route theo role

### 2. **Luồng Xác Thực**
- Đăng ký → Xác thực OTP → Lưu User (role: 'user')
- Đăng nhập → Kiểm tra role → Route đến Dashboard tương ứng
- Quên mật khẩu → OTP → Đặt lại mật khẩu

### 3. **Luồng User**
- Tìm kiếm/Lọc phòng → Xem chi tiết → Chat/Gửi yêu cầu
- Quản lý yêu cầu → Xem hợp đồng → Xem thanh toán
- Lưu phòng yêu thích → Xem lại sau

### 4. **Luồng Owner**
- Tạo phòng → Tạo bài đăng → Chờ Admin duyệt
- Quản lý yêu cầu → Duyệt/Từ chối → Tạo hợp đồng
- Tạo hóa đơn → Quản lý thanh toán → Xem thống kê

### 5. **Luồng Admin**
- Duyệt bài đăng → Duyệt/Từ chối
- Quản lý người dùng → Đổi role/Khóa tài khoản
- Quản lý danh mục → Thêm/Xóa
- Xem thống kê hệ thống

### 6. **Luồng Real-time**
- Chat: Stream messages từ Firestore
- Yêu cầu: Stream requests với trạng thái real-time
- Thanh toán: Stream payments với cập nhật real-time

---

**Ghi chú:**
- Tất cả các luồng đều sử dụng **Firebase Firestore** làm database
- **Real-time updates** được thực hiện qua StreamBuilder
- **State management** sử dụng **Riverpod**
- **UI/UX** được thiết kế với **Material 3**

