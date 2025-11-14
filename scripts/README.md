# Seed Data Script - REST API Version

Script JavaScript để tạo dữ liệu mẫu cho Find Roommate App sử dụng Firebase REST API.

## 🚀 Ưu Điểm

- ✅ **Không cần Service Account Key** - Chỉ cần API key từ `google-services.json`
- ✅ **Không cần npm install** - Chỉ cần Node.js
- ✅ **Tự động detect** - Đọc project ID và API key từ `google-services.json`
- ✅ **Tạo đầy đủ** - Tạo cả users, rooms và posts

## 📋 Yêu Cầu

1. **Node.js** đã được cài đặt (version 14+)
2. File `android/app/google-services.json` tồn tại (tự động có trong project)

## 📝 Cách Sử Dụng

### Chạy đơn giản

```bash
cd scripts
node seed_data_rest_api.js
```

Script sẽ tự động:
1. Đọc project ID và API key từ `google-services.json`
2. Tạo 3 tài khoản (user, owner, admin)
3. Tạo 50 phòng trọ với hình ảnh thật từ Unsplash
4. Tạo 50 bài đăng tương ứng

### Với owner ID tùy chỉnh (nếu cần)

```bash
node seed_data_rest_api.js <owner_user_id>
```

## ⚙️ Cấu Hình Firestore Rules

Để script có thể write data, tạm thời mở Firestore Rules:

1. Vào Firebase Console → Firestore Database → Rules
2. Thay đổi rules thành:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Tạm thời cho phép mọi thứ (chỉ dùng cho development!)
      allow read, write: if true;
    }
  }
}
```

3. Click **Publish**
4. ⚠️ **Sau khi seed xong, khôi phục lại rules gốc!**

## 📦 Dữ Liệu Sẽ Được Tạo

### 3 Tài Khoản:
- **User**: `user@test.com` / `123456`
- **Owner**: `owner@test.com` / `123456`
- **Admin**: `admin@test.com` / `123456`

### 50 Phòng Trọ:
- Mỗi phòng có **2-5 hình ảnh thật** từ Unsplash
- Đa dạng về giá: **2M - 6M VND**
- Diện tích: **15 - 40 m²**
- Nhiều loại: single, double, shared, apartment
- Phân bố ở: **HCM, Hà Nội, Đà Nẵng, Cần Thơ, Nha Trang**
- **40 phòng** status: `approved`
- **10 phòng** status: `pending` (để admin duyệt)

### 50 Bài Đăng:
- Mỗi bài đăng tương ứng với 1 phòng

## 🖼️ Hình Ảnh

Script sử dụng **Unsplash** để lấy hình ảnh thật:
- Format: `https://images.unsplash.com/photo-{photoId}?w=800&h=600&auto=format&fit=crop`
- Sử dụng photo IDs thực tế từ Unsplash
- Mỗi phòng có nhiều ảnh khác nhau

## 🔍 Kiểm Tra Kết Quả

Sau khi chạy thành công:

1. **Firebase Console → Authentication**
   - Sẽ có 3 users: user@test.com, owner@test.com, admin@test.com

2. **Firebase Console → Firestore Database**
   - Collection `users`: 3 documents
   - Collection `rooms`: 50 documents
   - Collection `posts`: 50 documents

3. **Đăng nhập vào App**
   - User: `user@test.com` / `123456`
   - Owner: `owner@test.com` / `123456`
   - Admin: `admin@test.com` / `123456`


## 🐛 Troubleshooting

### Lỗi: Permission denied

- Kiểm tra Firestore Rules đã được mở chưa (xem [Cấu Hình Firestore Rules](#cấu-hình-firestore-rules))
- Đảm bảo API key trong `google-services.json` còn valid

### Lỗi: Cannot read project info

- Kiểm tra file `android/app/google-services.json` tồn tại
- Kiểm tra file có format JSON đúng không
- Đảm bảo file có `project_info.project_id` và `client[0].api_key[0].current_key`

### Lỗi: EMAIL_EXISTS

- Script sẽ tự động bỏ qua users đã tồn tại
- Không ảnh hưởng đến việc tạo rooms

### Lỗi: Rate limit exceeded

- Script đã có delay 200ms giữa mỗi room
- Nếu vẫn gặp lỗi, tăng delay trong script:
  ```javascript
  await new Promise(resolve => setTimeout(resolve, 500)); // Tăng từ 200 lên 500
  ```

## 📊 Output

Script sẽ hiển thị:
- ✅ Tiến độ tạo users
- ✅ Tiến độ tạo rooms (1/50, 2/50, ...)
- ✅ Tổng kết sau khi hoàn thành

## 🎯 Kết Quả

Sau khi chạy thành công, bạn sẽ có:
- ✅ 3 tài khoản sẵn sàng sử dụng
- ✅ 50 phòng trọ với hình ảnh thật
- ✅ 50 bài đăng để admin duyệt/test

---

**Script:** `seed_data_rest_api.js`  
**Project ID:** Tự động detect từ `google-services.json`  
**API Key:** Tự động lấy từ `google-services.json`

