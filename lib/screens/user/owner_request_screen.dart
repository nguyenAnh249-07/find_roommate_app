import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/owner_request_model.dart';

class OwnerRequestScreen extends ConsumerStatefulWidget {
  const OwnerRequestScreen({super.key});

  @override
  ConsumerState<OwnerRequestScreen> createState() => _OwnerRequestScreenState();
}

class _OwnerRequestScreenState extends ConsumerState<OwnerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingRequest() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final existingRequest = await _firestoreService.getOwnerRequestByUserId(currentUser.id);
    if (existingRequest != null && mounted) {
      _showRequestStatusDialog(existingRequest);
    }
  }

  bool _hasCheckedRequest = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for existing request only once after widget is built
    if (!_hasCheckedRequest) {
      _hasCheckedRequest = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkExistingRequest();
        }
      });
    }
  }

  void _showRequestStatusDialog(OwnerRequestModel request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          request.status == 'pending'
              ? 'Đang chờ phê duyệt'
              : request.status == 'approved'
                  ? 'Đã được phê duyệt'
                  : 'Đã bị từ chối',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lý do: ${request.reason ?? ''}'),
            if (request.adminNote != null) ...[
              const SizedBox(height: 16),
              Text(
                'Ghi chú của admin:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(request.adminNote!),
            ],
            const SizedBox(height: 16),
            Text(
              'Ngày tạo: ${request.createdAt.toString().split('.')[0]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập')),
        );
      }
      return;
    }

    // Check if user is already owner
    if (currentUser.role == 'owner') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đã là chủ trọ')),
        );
      }
      return;
    }

    // Check if there's already a pending request
    final existingRequest = await _firestoreService.getOwnerRequestByUserId(currentUser.id);
    if (existingRequest != null) {
      if (mounted) {
        _showRequestStatusDialog(existingRequest);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = OwnerRequestModel(
        id: FirebaseFirestore.instance.collection('owner_requests').doc().id,
        userId: currentUser.id,
        reason: _reasonController.text.trim(),
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createOwnerRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu đăng ký làm chủ trọ'),
          ),
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Đăng ký làm chủ trọ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.home_work_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Yêu cầu nâng cấp tài khoản',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng điền lý do bạn muốn trở thành chủ trọ. Admin sẽ xem xét và phê duyệt yêu cầu của bạn.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // User info card
                if (currentUser != null)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: currentUser.avatarUrl != null
                                ? NetworkImage(currentUser.avatarUrl!)
                                : null,
                            backgroundColor: colorScheme.primaryContainer,
                            child: currentUser.avatarUrl == null
                                ? Text(
                                    currentUser.fullName.isNotEmpty
                                        ? currentUser.fullName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser.fullName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentUser.email,
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
                  ),
                // Reason field
                Text(
                  'Lý do đăng ký',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Tôi có phòng trọ muốn cho thuê...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: theme.textTheme.bodyLarge,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập lý do';
                    }
                    if (value.trim().length < 10) {
                      return 'Lý do phải có ít nhất 10 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

