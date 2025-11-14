import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/room_model.dart';
import '../../models/post_model.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _capacityController = TextEditingController();
  final List<String> _imageUrls = [];
  final _imageUrlController = TextEditingController();
  String? _selectedRoomType;
  bool _allowRoommate = false;
  final List<String> _selectedAmenities = [];
  bool _isLoading = false;

  final List<String> _availableAmenities = [
    'wifi',
    'aircon',
    'parking',
    'fridge',
    'washing_machine',
    'water_heater',
    'security',
    'elevator',
  ];

  String _getAmenityLabel(String amenity) {
    final labels = {
      'wifi': 'WiFi',
      'aircon': 'Điều hòa',
      'parking': 'Bãi đỗ xe',
      'fridge': 'Tủ lạnh',
      'washing_machine': 'Máy giặt',
      'water_heater': 'Máy nước nóng',
      'security': 'An ninh',
      'elevator': 'Thang máy',
    };
    return labels[amenity] ?? amenity;
  }

  IconData _getAmenityIcon(String amenity) {
    final icons = {
      'wifi': Icons.wifi,
      'aircon': Icons.ac_unit,
      'parking': Icons.local_parking,
      'fridge': Icons.kitchen,
      'washing_machine': Icons.local_laundry_service,
      'water_heater': Icons.water_drop,
      'security': Icons.security,
      'elevator': Icons.elevator,
    };
    return icons[amenity] ?? Icons.check_circle;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _capacityController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _addImageUrl() {
    if (_imageUrlController.text.trim().isNotEmpty) {
      setState(() {
        _imageUrls.add(_imageUrlController.text.trim());
        _imageUrlController.clear();
      });
    }
  }

  void _removeImageUrl(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 ảnh')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final roomId = FirebaseFirestore.instance.collection('rooms').doc().id;

      final room = RoomModel(
        id: roomId,
        ownerId: currentUser.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: _imageUrls,
        price: double.parse(_priceController.text),
        area: double.parse(_areaController.text),
        roomType: _selectedRoomType ?? 'single',
        address: _addressController.text.trim(),
        district: _districtController.text.trim(),
        city: _cityController.text.trim(),
        capacity: int.parse(_capacityController.text),
        occupants: [],
        allowRoommate: _allowRoommate,
        amenities: _selectedAmenities,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending', // Chờ admin duyệt
      );

      await FirestoreService().createRoom(room);

      // Tạo post
      final post = PostModel(
        id: FirebaseFirestore.instance.collection('posts').doc().id,
        roomId: roomId,
        ownerId: currentUser.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: _imageUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
      );

      await FirestoreService().createPost(post);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo phòng, đang chờ duyệt')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng tin cho thuê'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
                  Icons.add_home_work_outlined,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Thông tin phòng trọ',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Image URLs Section
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hình ảnh phòng',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _imageUrlController,
                              decoration: InputDecoration(
                                hintText: 'Nhập URL ảnh',
                                hintStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                ),
                                prefixIcon: Icon(
                                  Icons.link,
                                  color: colorScheme.primary,
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _addImageUrl(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: _addImageUrl,
                              tooltip: 'Thêm ảnh',
                            ),
                          ),
                        ],
                      ),
                      if (_imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _imageUrls.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Show full image
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: CachedNetworkImage(
                                                  imageUrl: _imageUrls[index],
                                                  fit: BoxFit.contain,
                                                  placeholder: (context, url) => Container(
                                                    color: colorScheme.surfaceContainerHighest,
                                                    child: Center(
                                                      child: CircularProgressIndicator(
                                                        color: colorScheme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: colorScheme.errorContainer,
                                                    child: Icon(
                                                      Icons.error_outline,
                                                      color: colorScheme.onErrorContainer,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: IconButton(
                                                  icon: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  onPressed: () => Navigator.of(context).pop(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: CachedNetworkImage(
                                      imageUrl: _imageUrls[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: colorScheme.surfaceContainerHighest,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: colorScheme.errorContainer,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                              Icons.error_outline,
                                              color: colorScheme.onErrorContainer,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Lỗi',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: colorScheme.onErrorContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeImageUrl(index),
                                      tooltip: 'Xóa ảnh',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá thuê (VNĐ)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập giá';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Diện tích (m²)',
                        prefixIcon: Icon(Icons.square_foot),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập diện tích';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập địa chỉ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _districtController,
                      decoration: const InputDecoration(
                        labelText: 'Quận/Huyện',
                        prefixIcon: Icon(Icons.map),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập quận/huyện';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Thành phố',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập thành phố';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRoomType,
                decoration: const InputDecoration(
                  labelText: 'Loại phòng',
                  prefixIcon: Icon(Icons.bed),
                ),
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('Phòng đơn')),
                  DropdownMenuItem(value: 'double', child: Text('Phòng đôi')),
                  DropdownMenuItem(value: 'shared', child: Text('Phòng chung')),
                  DropdownMenuItem(value: 'apartment', child: Text('Căn hộ')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRoomType = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Vui lòng chọn loại phòng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sức chứa (người)',
                  prefixIcon: Icon(Icons.people),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập sức chứa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Allow Roommate Switch
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Cho phép ở ghép',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Cho phép người khác ở ghép trong phòng này',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _allowRoommate,
                  onChanged: (value) {
                    setState(() => _allowRoommate = value);
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Amenities Section
              Text(
                'Tiện ích',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableAmenities.map((amenity) {
                  final isSelected = _selectedAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(
                      _getAmenityLabel(amenity),
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colorScheme.primaryContainer,
                    checkmarkColor: colorScheme.onPrimaryContainer,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAmenities.add(amenity);
                        } else {
                          _selectedAmenities.remove(amenity);
                        }
                      });
                    },
                    avatar: Icon(
                      _getAmenityIcon(amenity),
                      size: 18,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isLoading ? 'Đang đăng tin...' : 'Đăng tin',
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

