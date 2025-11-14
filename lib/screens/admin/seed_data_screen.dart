import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/room_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';

class SeedDataScreen extends ConsumerStatefulWidget {
  const SeedDataScreen({super.key});

  @override
  ConsumerState<SeedDataScreen> createState() => _SeedDataScreenState();
}

class _SeedDataScreenState extends ConsumerState<SeedDataScreen> {
  bool _isSeeding = false;
  String _statusMessage = '';
  int _currentProgress = 0;
  final int _totalItems = 53; // 3 users + 50 rooms

  // Real room/apartment images from Unsplash
  // Using Unsplash Random Image API - returns real photos
  List<String> _generateRoomImages(int index) {
    final imageCount = 2 + (index % 4); // 2-5 images
    final random = Random(index * 1000);
    
    // Keywords for room/apartment images
    final keywords = [
      'room', 'apartment', 'bedroom', 'living-room', 'interior',
      'home', 'house', 'studio', 'furniture', 'modern-home',
      'vietnam-apartment', 'asian-home', 'cozy-room', 'minimalist',
      'contemporary', 'decoration', 'cozy', 'urban', 'residential'
    ];
    
    return List.generate(imageCount, (i) {
      final width = 800;
      final height = 600;
      final keywordIndex = (index * 3 + i) % keywords.length;
      final keyword = keywords[keywordIndex];
      final randomSig = random.nextInt(1000000);
      
      // Using Unsplash Source API for real images
      // Format: https://source.unsplash.com/{width}x{height}/?{keyword}&sig={random}
      // This returns real photos from Unsplash matching the keyword
      return 'https://source.unsplash.com/${width}x${height}/?$keyword&sig=$randomSig';
    });
  }

  Map<String, dynamic> _generateRoomData(int index, String ownerId) {
    final cities = ['Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ', 'Nha Trang'];
    final districtsHCM = [
      'Quận 1', 'Quận 3', 'Quận 5', 'Quận 7', 'Quận 10',
      'Quận Bình Thạnh', 'Quận Tân Bình', 'Quận Phú Nhuận'
    ];
    final districtsHN = [
      'Quận Hoàn Kiếm', 'Quận Hai Bà Trưng', 'Quận Đống Đa',
      'Quận Cầu Giấy', 'Quận Thanh Xuân', 'Quận Ba Đình'
    ];
    final roomTypes = ['single', 'double', 'shared', 'apartment'];
    final allAmenities = [
      'wifi', 'aircon', 'parking', 'fridge', 'washing_machine',
      'water_heater', 'security', 'elevator'
    ];
    
    final cityIndex = index % cities.length;
    final city = cities[cityIndex];
    final districts = city == 'Hồ Chí Minh' ? districtsHCM : districtsHN;
    final district = districts[index % districts.length];
    final roomType = roomTypes[index % roomTypes.length];
    
    final amenitiesCount = 2 + (index % 5);
    final amenities = allAmenities.sublist(0, amenitiesCount);
    
    final basePrices = [2000000, 3000000, 4000000, 5000000, 6000000];
    final basePrice = basePrices[index % basePrices.length].toDouble();
    final baseAreas = [15, 20, 25, 30, 35, 40];
    final baseArea = baseAreas[index % baseAreas.length].toDouble();
    final capacity = roomType == 'single' ? 1 : 
                     (roomType == 'double' ? 2 : (2 + (index % 3)));
    
    final images = _generateRoomImages(index);
    
    final titles = [
      'Phòng trọ đẹp gần $district',
      'Căn phòng tiện nghi tại $district',
      'Phòng ở ghép $district',
      'Căn hộ mini $district',
      'Phòng trọ giá rẻ $district',
      'Phòng đẹp $district',
      'Căn phòng $district đầy đủ tiện ích',
      'Phòng ở $district gần trung tâm',
      'Studio $district hiện đại',
      'Phòng trọ $district view đẹp',
    ];
    
    final descriptions = [
      'Phòng trọ rộng rãi, thoáng mát, gần trường học, chợ, siêu thị. Phù hợp cho sinh viên và người đi làm. Đầy đủ tiện ích, an ninh tốt.',
      'Phòng đẹp, sạch sẽ, đầy đủ tiện nghi hiện đại. An ninh tốt, khu vực yên tĩnh. Gần các trường đại học, bệnh viện.',
      'Căn phòng tiện nghi, vị trí thuận lợi, giao thông đi lại dễ dàng. Phù hợp cho gia đình nhỏ. Có chỗ để xe.',
      'Phòng ở ghép hiện đại, không gian thoáng mát, đầy đủ tiện ích. Có chỗ để xe riêng, wifi tốc độ cao.',
      'Căn phòng đẹp, view đẹp, nội thất đầy đủ. Vị trí trung tâm, tiện mua sắm và ăn uống. Thích hợp cho người đi làm.',
      'Phòng trọ giá rẻ nhưng chất lượng tốt. Đầy đủ tiện ích cơ bản, gần các tuyến xe buýt, dễ di chuyển.',
      'Căn hộ mini đầy đủ nội thất, thiết kế hiện đại. An ninh 24/7, có thang máy, bãi đỗ xe miễn phí.',
      'Phòng ở ghép sạch sẽ, giá cả phải chăng. Có máy lạnh, wifi, nước nóng. Khu vực an toàn, yên tĩnh.',
    ];
    
    return {
      'title': titles[index % titles.length],
      'description': descriptions[index % descriptions.length],
      'price': basePrice,
      'area': baseArea,
      'roomType': roomType,
      'address': '${100 + index} Đường ${district.split(' ').last}',
      'district': district,
      'city': city,
      'latitude': city == 'Hồ Chí Minh' 
          ? (10.762622 + (index % 100) * 0.01)
          : (21.028511 + (index % 100) * 0.01),
      'longitude': city == 'Hồ Chí Minh'
          ? (106.660172 + (index % 100) * 0.01)
          : (105.804817 + (index % 100) * 0.01),
      'capacity': capacity,
      'occupants': <String>[],
      'allowRoommate': roomType == 'shared' || (index % 3 == 0),
      'amenities': amenities,
      'images': images,
      'status': index < 40 ? 'approved' : 'pending',
    };
  }

  Future<void> _seedData() async {
    setState(() {
      _isSeeding = true;
      _currentProgress = 0;
      _statusMessage = 'Bắt đầu seed data...';
    });

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    try {
      // 1. Create 3 users
      setState(() {
        _statusMessage = 'Đang tạo tài khoản...';
      });

      final users = [
        {
          'email': 'user@test.com',
          'password': '123456',
          'fullName': 'Nguyễn Văn User',
          'role': 'user',
          'phoneNumber': '0901234567',
          'address': '123 Đường Test, Quận 1, Hồ Chí Minh',
        },
        {
          'email': 'owner@test.com',
          'password': '123456',
          'fullName': 'Trần Thị Owner',
          'role': 'owner',
          'phoneNumber': '0902345678',
          'address': '456 Đường Owner, Quận 7, Hồ Chí Minh',
        },
        {
          'email': 'admin@test.com',
          'password': '123456',
          'fullName': 'Lê Văn Admin',
          'role': 'admin',
          'phoneNumber': '0903456789',
          'address': '789 Đường Admin, Quận 1, Hồ Chí Minh',
        },
      ];

      final userIds = <String, String>{};
      String ownerId = '';

      for (final userData in users) {
        try {
          // Try to sign in first
          try {
            final credential = await auth.signInWithEmailAndPassword(
              email: userData['email'] as String,
              password: userData['password'] as String,
            );
            userIds[userData['role'] as String] = credential.user!.uid;
            if (userData['role'] == 'owner') ownerId = credential.user!.uid;
            await auth.signOut();
            setState(() => _currentProgress++);
          } catch (e) {
            // User doesn't exist, create new
            final credential = await auth.createUserWithEmailAndPassword(
              email: userData['email'] as String,
              password: userData['password'] as String,
            );
            
            final userId = credential.user!.uid;
            userIds[userData['role'] as String] = userId;
            if (userData['role'] == 'owner') ownerId = userId;
            
            final user = UserModel(
              id: userId,
              email: userData['email'] as String,
              emailVerified: true,
              fullName: userData['fullName'] as String,
              role: userData['role'] as String,
              phoneNumber: userData['phoneNumber'] as String,
              address: userData['address'] as String,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: 'active',
            );
            
            await firestore.collection('users').doc(userId).set(user.toMap());
            setState(() => _currentProgress++);
            await auth.signOut();
          }
        } catch (e) {
          print('Error creating user ${userData['role']}: $e');
        }
      }

      if (ownerId.isEmpty) {
        ownerId = userIds['owner']!;
      }

      // 2. Create 50 rooms
      setState(() {
        _statusMessage = 'Đang tạo 50 phòng trọ...';
      });

      for (int i = 0; i < 50; i++) {
        try {
          final roomData = _generateRoomData(i, ownerId);
          final roomId = firestore.collection('rooms').doc().id;
          final now = DateTime.now();
          final createdAt = now.subtract(Duration(days: i % 30));

          final room = RoomModel(
            id: roomId,
            ownerId: ownerId,
            title: roomData['title'] as String,
            description: roomData['description'] as String,
            images: roomData['images'] as List<String>,
            price: roomData['price'] as double,
            area: roomData['area'] as double,
            roomType: roomData['roomType'] as String,
            address: roomData['address'] as String,
            district: roomData['district'] as String,
            city: roomData['city'] as String,
            latitude: roomData['latitude'] as double,
            longitude: roomData['longitude'] as double,
            capacity: roomData['capacity'] as int,
            occupants: roomData['occupants'] as List<String>,
            allowRoommate: roomData['allowRoommate'] as bool,
            amenities: roomData['amenities'] as List<String>,
            createdAt: createdAt,
            updatedAt: now,
            status: roomData['status'] as String,
          );

          await firestore.collection('rooms').doc(roomId).set(room.toMap());

          // Create corresponding post
          final postId = firestore.collection('posts').doc().id;
          final post = PostModel(
            id: postId,
            roomId: roomId,
            ownerId: ownerId,
            title: roomData['title'] as String,
            description: roomData['description'] as String,
            images: roomData['images'] as List<String>,
            status: roomData['status'] as String,
            createdAt: createdAt,
            updatedAt: now,
          );

          await firestore.collection('posts').doc(postId).set(post.toMap());

          setState(() {
            _currentProgress++;
            _statusMessage = 'Đã tạo phòng ${i + 1}/50: ${room.title}';
          });

          // Small delay to avoid rate limiting
          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          print('Error creating room ${i + 1}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isSeeding = false;
          _statusMessage = '✅ Hoàn thành! Đã tạo 3 tài khoản và 50 phòng trọ.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Seed data thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSeeding = false;
          _statusMessage = '❌ Lỗi: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi seed data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Seed Data',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storage_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tạo dữ liệu mẫu',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Script sẽ tạo 3 tài khoản và 50 phòng trọ với hình ảnh thật từ Unsplash',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Info Cards
            _buildInfoCard(
              context,
              Icons.person_outlined,
              '3 Tài khoản',
              'User, Owner, Admin\n(user@test.com / 123456)',
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              Icons.home_outlined,
              '50 Phòng trọ',
              'Với hình ảnh thật từ Unsplash\n40 approved, 10 pending',
            ),
            const SizedBox(height: 32),
            // Progress
            if (_isSeeding || _currentProgress > 0) ...[
              LinearProgressIndicator(
                value: _currentProgress / _totalItems,
                backgroundColor: colorScheme.surfaceContainerHighest,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Text(
                'Tiến độ: $_currentProgress/$_totalItems',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_statusMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Seed Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSeeding ? null : _seedData,
                icon: _isSeeding
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.play_arrow_outlined),
                label: Text(
                  _isSeeding ? 'Đang tạo dữ liệu...' : 'Bắt đầu Seed Data',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cảnh báo: Script sẽ tạo mới dữ liệu. Users đã tồn tại sẽ được bỏ qua.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

