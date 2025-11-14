/**
 * Seed Data Script for Find Roommate App (REST API Version)
 * 
 * This script uses Firebase REST API instead of Admin SDK.
 * No Service Account Key needed - uses API key from google-services.json
 * 
 * This script will create:
 * - 3 user accounts (user, owner, admin)
 * - 50 rooms with real images from Unsplash
 * - 50 posts corresponding to rooms
 * 
 * Usage:
 *   node scripts/seed_data_rest_api.js [owner_user_id]
 * 
 * If owner_user_id is not provided, will create a new owner account and use it.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// Read project info from google-services.json
function readProjectInfo() {
  const googleServicesPaths = [
    '../android/app/google-services.json',
    path.join(__dirname, '../android/app/google-services.json'),
    './android/app/google-services.json',
  ];
  
  for (const googleServicesPath of googleServicesPaths) {
    if (fs.existsSync(googleServicesPath)) {
      try {
        const googleServices = JSON.parse(fs.readFileSync(googleServicesPath, 'utf8'));
        return {
          projectId: googleServices.project_info?.project_id,
          apiKey: googleServices.client?.[0]?.api_key?.[0]?.current_key,
        };
      } catch (e) {
        console.error('Error reading google-services.json:', e.message);
      }
    }
  }
  
  return null;
}

// Firebase REST API helper
function makeRequest(url, data = null, method = 'PATCH') {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };
    
    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = responseData ? JSON.parse(responseData) : {};
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(jsonData);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${jsonData.error?.message || responseData}`));
          }
        } catch (e) {
          reject(new Error(`Parse error: ${e.message}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

// Generate room images using Unsplash
function generateRoomImages(index) {
  const imageCount = 2 + (index % 4); // 2-5 images
  
  // Real Unsplash photo IDs
  const unsplashPhotoIds = [
    '1522708323590-d24dbb6b0267', '1540518614842-5e9fe4bd1d04', '1560448204-e02f11c3d0e2',
    '1502672260266-1c1ef2d93688', '1536376072261-38c75010e6c9', '1586023492125-27b2c045efd7',
    '1512918728675-ed5a9ecdebfd', '1497366216548-37526070297c', '1505843512277-9f0b24b86cc3',
    '1522771739844-6a9f6d5f14af', '1538688525198-9b4f4fb34ced', '1513694203232-719a280e022f',
    '1554995207-c18c35360202', '1556911220-bff31c812aab', '1560184897-67f85a4840f9',
    '1560449752-015f8d9193f8', '1556912173-0e02239a3eda', '1560185007-c5ca9d2c014d',
  ];
  
  const images = [];
  for (let i = 0; i < imageCount; i++) {
    const photoIndex = (index * 3 + i) % unsplashPhotoIds.length;
    const photoId = unsplashPhotoIds[photoIndex];
    images.push(`https://images.unsplash.com/photo-${photoId}?w=800&h=600&auto=format&fit=crop`);
  }
  
  return images;
}

// Generate room data
function generateRoomData(index) {
  const cities = ['Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ', 'Nha Trang'];
  const districtsHCM = [
    'Quận 1', 'Quận 3', 'Quận 5', 'Quận 7', 'Quận 10',
    'Quận Bình Thạnh', 'Quận Tân Bình', 'Quận Phú Nhuận'
  ];
  const districtsHN = [
    'Quận Hoàn Kiếm', 'Quận Hai Bà Trưng', 'Quận Đống Đa',
    'Quận Cầu Giấy', 'Quận Thanh Xuân', 'Quận Ba Đình'
  ];
  const roomTypes = ['single', 'double', 'shared', 'apartment'];
  const allAmenities = [
    'wifi', 'aircon', 'parking', 'fridge', 'washing_machine',
    'water_heater', 'security', 'elevator'
  ];
  
  const cityIndex = index % cities.length;
  const city = cities[cityIndex];
  const districts = city === 'Hồ Chí Minh' ? districtsHCM : districtsHN;
  const district = districts[index % districts.length];
  const roomType = roomTypes[index % roomTypes.length];
  
  const amenitiesCount = 2 + (index % 5);
  const amenities = allAmenities.slice(0, amenitiesCount);
  
  const basePrices = [2000000, 3000000, 4000000, 5000000, 6000000];
  const basePrice = basePrices[index % basePrices.length];
  const baseAreas = [15, 20, 25, 30, 35, 40];
  const baseArea = baseAreas[index % baseAreas.length];
  const capacity = roomType === 'single' ? 1 : 
                   (roomType === 'double' ? 2 : (2 + (index % 3)));
  
  const images = generateRoomImages(index);
  
  const titles = [
    `Phòng trọ đẹp gần ${district}`,
    `Căn phòng tiện nghi tại ${district}`,
    `Phòng ở ghép ${district}`,
    `Căn hộ mini ${district}`,
    `Phòng trọ giá rẻ ${district}`,
    `Phòng đẹp ${district}`,
    `Căn phòng ${district} đầy đủ tiện ích`,
    `Phòng ở ${district} gần trung tâm`,
    `Studio ${district} hiện đại`,
    `Phòng trọ ${district} view đẹp`,
  ];
  
  const descriptions = [
    'Phòng trọ rộng rãi, thoáng mát, gần trường học, chợ, siêu thị. Phù hợp cho sinh viên và người đi làm. Đầy đủ tiện ích, an ninh tốt.',
    'Phòng đẹp, sạch sẽ, đầy đủ tiện nghi hiện đại. An ninh tốt, khu vực yên tĩnh. Gần các trường đại học, bệnh viện.',
    'Căn phòng tiện nghi, vị trí thuận lợi, giao thông đi lại dễ dàng. Phù hợp cho gia đình nhỏ. Có chỗ để xe.',
    'Phòng ở ghép hiện đại, không gian thoáng mát, đầy đủ tiện ích. Có chỗ để xe riêng, wifi tốc độ cao.',
    'Căn phòng đẹp, view đẹp, nội thất đầy đủ. Vị trí trung tâm, tiện mua sắm và ăn uống. Thích hợp cho người đi làm.',
    'Phòng trọ giá rẻ nhưng chất lượng tốt. Đầy đủ tiện ích cơ bản, gần các tuyến xe buýt, dễ di chuyển.',
    'Căn hộ mini đầy đủ nội thất, thiết kế hiện đại. An ninh 24/7, có thang máy, bãi đỗ xe miễn phí.',
    'Phòng ở ghép sạch sẽ, giá cả phải chăng. Có máy lạnh, wifi, nước nóng. Khu vực an toàn, yên tĩnh.',
  ];
  
  const now = new Date().toISOString();
  const createdAt = new Date(Date.now() - (index % 30) * 24 * 60 * 60 * 1000).toISOString();
  
  return {
    title: titles[index % titles.length],
    description: descriptions[index % descriptions.length],
    price: basePrice,
    area: baseArea,
    roomType: roomType,
    address: `${100 + index} Đường ${district.split(' ').pop()}`,
    district: district,
    city: city,
    latitude: city === 'Hồ Chí Minh' 
        ? (10.762622 + (index % 100) * 0.01)
        : (21.028511 + (index % 100) * 0.01),
    longitude: city === 'Hồ Chí Minh'
        ? (106.660172 + (index % 100) * 0.01)
        : (105.804817 + (index % 100) * 0.01),
    capacity: capacity,
    occupants: [],
    allowRoommate: roomType === 'shared' || (index % 3 === 0),
    amenities: amenities,
    images: images,
    status: index < 40 ? 'approved' : 'pending',
    createdAt: createdAt,
    updatedAt: now,
  };
}

// Create room using Firestore REST API
async function createRoom(projectId, apiKey, roomData, ownerId, index) {
  // Generate random ID for room
  const roomId = 'room_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/rooms/${roomId}?key=${apiKey}`;
  
  // Convert data to Firestore format
  const firestoreData = {
    fields: {
      id: { stringValue: roomId },
      ownerId: { stringValue: ownerId },
      title: { stringValue: roomData.title },
      description: { stringValue: roomData.description },
      price: { doubleValue: roomData.price },
      area: { doubleValue: roomData.area },
      roomType: { stringValue: roomData.roomType },
      address: { stringValue: roomData.address },
      district: { stringValue: roomData.district },
      city: { stringValue: roomData.city },
      latitude: { doubleValue: roomData.latitude },
      longitude: { doubleValue: roomData.longitude },
      capacity: { integerValue: roomData.capacity.toString() },
      occupants: { arrayValue: { values: [] } },
      allowRoommate: { booleanValue: roomData.allowRoommate },
      amenities: { arrayValue: { values: roomData.amenities.map(a => ({ stringValue: a })) } },
      images: { arrayValue: { values: roomData.images.map(img => ({ stringValue: img })) } },
      status: { stringValue: roomData.status },
      createdAt: { timestampValue: roomData.createdAt },
      updatedAt: { timestampValue: roomData.updatedAt },
    }
  };
  
  try {
    await makeRequest(url, firestoreData, 'PATCH');
    
    // Create corresponding post
    const postId = 'post_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    const postData = {
      fields: {
        id: { stringValue: postId },
        roomId: { stringValue: roomId },
        ownerId: { stringValue: ownerId },
        title: { stringValue: roomData.title },
        description: { stringValue: roomData.description },
        images: { arrayValue: { values: roomData.images.map(img => ({ stringValue: img })) } },
        status: { stringValue: roomData.status },
        createdAt: { timestampValue: roomData.createdAt },
        updatedAt: { timestampValue: roomData.updatedAt },
      }
    };
    
    const postUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/posts/${postId}?key=${apiKey}`;
    
    await makeRequest(postUrl, postData, 'PATCH');
    
    console.log(`✅ Created room ${index + 1}/50: ${roomData.title}`);
    return roomId;
  } catch (error) {
    console.error(`❌ Error creating room ${index + 1}:`, error.message);
    throw error;
  }
}

// Create user using Firebase Authentication REST API
async function createUser(projectId, apiKey, email, password, userData) {
  try {
    // Check if user exists first by trying to sign in
    // If fails, create new user
    
    // Step 1: Try to create user with signUp endpoint
    const signUpUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`;
    
    const signUpData = {
      email: email,
      password: password,
      returnSecureToken: true,
    };
    
    try {
      const result = await makeRequest(signUpUrl, signUpData, 'POST');
      const userId = result.localId;
      
      console.log(`✅ Created user: ${email} (ID: ${userId})`);
      
      // Step 2: Save user data to Firestore
      const userUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${userId}?key=${apiKey}`;
      
      const now = new Date().toISOString();
      const firestoreUserData = {
        fields: {
          id: { stringValue: userId },
          email: { stringValue: email },
          emailVerified: { booleanValue: true },
          avatarUrl: { nullValue: null },
          fullName: { stringValue: userData.fullName },
          gender: { nullValue: null },
          dateOfBirth: { nullValue: null },
          role: { stringValue: userData.role },
          phoneNumber: { stringValue: userData.phoneNumber },
          address: { stringValue: userData.address },
          createdAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
          status: { stringValue: 'active' },
        }
      };
      
      await makeRequest(userUrl, firestoreUserData, 'PATCH');
      
      return userId;
    } catch (error) {
      if (error.message.includes('EMAIL_EXISTS')) {
        console.log(`⚠️  User ${email} already exists, skipping...`);
        
        // Try to get user ID by signing in
        try {
          const signInUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
          const signInData = {
            email: email,
            password: password,
            returnSecureToken: true,
          };
          
          const signInResult = await makeRequest(signInUrl, signInData, 'POST');
          return signInResult.localId;
        } catch (signInError) {
          console.error(`❌ Cannot get user ID for ${email}`);
          return null;
        }
      } else {
        throw error;
      }
    }
  } catch (error) {
    console.error(`❌ Error creating user ${email}:`, error.message);
    return null;
  }
}

// Main function
async function seedData() {
  console.log('🚀 Bắt đầu seed data (REST API version)...\n');
  
  // Read project info
  const projectInfo = readProjectInfo();
  
  if (!projectInfo || !projectInfo.projectId || !projectInfo.apiKey) {
    console.error('❌ Cannot read project info from google-services.json');
    console.log('   Make sure android/app/google-services.json exists and has valid project_id and api_key');
    process.exit(1);
  }
  
  const { projectId, apiKey } = projectInfo;
  
  console.log(`📱 Project ID: ${projectId}`);
  console.log(`🔑 Using API Key from google-services.json\n`);
  
  try {
    // 1. Create 3 users
    console.log('👤 Tạo 3 tài khoản...\n');
    
    const users = [
      {
        email: 'user@test.com',
        password: '123456',
        fullName: 'Nguyễn Văn User',
        role: 'user',
        phoneNumber: '0901234567',
        address: '123 Đường Test, Quận 1, Hồ Chí Minh',
      },
      {
        email: 'owner@test.com',
        password: '123456',
        fullName: 'Trần Thị Owner',
        role: 'owner',
        phoneNumber: '0902345678',
        address: '456 Đường Owner, Quận 7, Hồ Chí Minh',
      },
      {
        email: 'admin@test.com',
        password: '123456',
        fullName: 'Lê Văn Admin',
        role: 'admin',
        phoneNumber: '0903456789',
        address: '789 Đường Admin, Quận 1, Hồ Chí Minh',
      },
    ];
    
    const userIds = {};
    
    for (const userData of users) {
      const userId = await createUser(projectId, apiKey, userData.email, userData.password, userData);
      if (userId) {
        userIds[userData.role] = userId;
      }
      // Small delay
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    
    const ownerId = process.argv[2] || userIds.owner || 'PLACEHOLDER_OWNER_ID';
    
    if (ownerId === 'PLACEHOLDER_OWNER_ID') {
      console.log('\n⚠️  Warning: No owner ID available');
      console.log('   Rooms will be created but need a real owner ID to be functional.');
      console.log('   Please create an owner account first or provide owner ID:\n');
      console.log('   node seed_data_rest_api.js <owner_user_id>\n');
      process.exit(1);
    }
    
    if (!userIds.owner) {
      console.log(`\n📝 Using provided owner ID: ${ownerId}\n`);
    } else {
      console.log(`\n📝 Using created owner ID: ${ownerId}\n`);
    }
    
    // 2. Create 50 rooms
    console.log('📦 Bắt đầu tạo 50 phòng trọ...\n');
    
    for (let i = 0; i < 50; i++) {
      try {
        const roomData = generateRoomData(i);
        await createRoom(projectId, apiKey, roomData, ownerId, i);
        
        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 200));
      } catch (error) {
        console.error(`❌ Error creating room ${i + 1}:`, error.message);
      }
    }
    
    console.log('\n🎉 Hoàn thành! Đã tạo:');
    console.log('   - 3 tài khoản (user, owner, admin)');
    console.log('   - 50 phòng trọ với hình ảnh thật từ Unsplash');
    console.log('   - 50 bài đăng tương ứng');
    console.log('\n📝 Thông tin đăng nhập:');
    console.log('   - User: user@test.com / 123456');
    console.log('   - Owner: owner@test.com / 123456');
    console.log('   - Admin: admin@test.com / 123456');
    console.log('\n✅ Seed data thành công!\n');
    
  } catch (error) {
    console.error('\n❌ Lỗi seed data:', error);
    process.exit(1);
  }
}

// Run seed data
seedData();

