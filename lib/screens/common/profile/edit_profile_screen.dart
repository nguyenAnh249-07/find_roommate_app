import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      _fullNameController.text = currentUser.fullName;
      _phoneNumberController.text = currentUser.phoneNumber ?? '';
      _addressController.text = currentUser.address ?? '';
      _avatarUrlController.text = currentUser.avatarUrl ?? '';
      _selectedGender = currentUser.gender;
      _selectedDateOfBirth = currentUser.dateOfBirth;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final updatedUser = currentUser.copyWith(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty
            ? null
            : _phoneNumberController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim().isEmpty
            ? null
            : _avatarUrlController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth,
        updatedAt: DateTime.now(),
      );

      final authService = ref.read(authServiceProvider);
      await authService.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật hồ sơ thành công')),
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
        title: const Text('Chỉnh sửa hồ sơ'),
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
                  Icons.edit_outlined,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Cập nhật thông tin',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Avatar URL
              TextFormField(
                controller: _avatarUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL Ảnh đại diện',
                  prefixIcon: Icon(Icons.image),
                  hintText: 'https://example.com/avatar.jpg',
                ),
              ),
              const SizedBox(height: 20),
              // Full Name
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập họ tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Giới tính',
                  prefixIcon: Icon(Icons.wc),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Nam')),
                  DropdownMenuItem(value: 'female', child: Text('Nữ')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (value) {
                  setState(() => _selectedGender = value);
                },
              ),
              const SizedBox(height: 20),
              // Date of Birth
              InkWell(
                onTap: _selectDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày sinh',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                        : 'Chọn ngày sinh',
                    style: TextStyle(
                      color: _selectedDateOfBirth != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Phone Number
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 20),
              // Address
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 32),
              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
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
                    _isLoading ? 'Đang lưu...' : 'Lưu thay đổi',
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

