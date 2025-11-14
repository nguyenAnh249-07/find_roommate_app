import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/owner_request_model.dart';
import '../common/profile/view_user_profile_screen.dart';

class OwnerRequestsScreen extends ConsumerStatefulWidget {
  const OwnerRequestsScreen({super.key});

  @override
  ConsumerState<OwnerRequestsScreen> createState() =>
      _OwnerRequestsScreenState();
}

class _OwnerRequestsScreenState extends ConsumerState<OwnerRequestsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _adminNoteController = TextEditingController();
  String _filterStatus = 'pending';

  @override
  void dispose() {
    _adminNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final requestsStream = _firestoreService.getOwnerRequestsStream(
      status: _filterStatus == 'all' ? null : _filterStatus,
    );

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        context,
                        'Tất cả',
                        'all',
                        Icons.all_inclusive,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        'Chờ xử lý',
                        'pending',
                        Icons.pending_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        'Đã phê duyệt',
                        'approved',
                        Icons.check_circle_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        'Đã từ chối',
                        'rejected',
                        Icons.cancel_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Requests list
        Expanded(
          child: StreamBuilder<List<OwnerRequestModel>>(
            stream: requestsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Lỗi: ${snapshot.error}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {});
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outlined,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _filterStatus == 'all'
                              ? 'Không có yêu cầu nào'
                              : _filterStatus == 'pending'
                                  ? 'Không có yêu cầu chờ xử lý'
                                  : _filterStatus == 'approved'
                                      ? 'Không có yêu cầu đã phê duyệt'
                                      : 'Không có yêu cầu bị từ chối',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterStatus == 'all'
                              ? 'Tất cả các yêu cầu đã được xử lý'
                              : 'Thử chuyển sang tab khác',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _RequestCard(
                      request: request,
                      onApprove: () => _approveRequest(request),
                      onReject: () => _rejectRequest(request),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String status,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _filterStatus == status;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = status);
        }
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  Future<void> _approveRequest(OwnerRequestModel request) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null || currentUser.role != 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Phê duyệt yêu cầu',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn phê duyệt yêu cầu này? Người dùng sẽ được cấp quyền Owner sau khi phê duyệt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Phê duyệt'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Update request status
      await _firestoreService.updateOwnerRequestStatus(
        request.id,
        'approved',
        currentUser.id,
        null,
      );

      // Update user role
      final user = await _authService.getUserFromFirestore(request.userId);
      if (user != null) {
        await _authService.updateUser(
          user.copyWith(
            role: 'owner',
            updatedAt: DateTime.now(),
          ),
        );

        // Invalidate current user provider if it's the approved user
        final currentUserData = ref.read(currentUserProvider).value;
        if (currentUserData != null &&
            currentUserData.id == request.userId) {
          ref.invalidate(currentUserProvider);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã phê duyệt yêu cầu thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(OwnerRequestModel request) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null || currentUser.role != 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show dialog to enter admin note
    final adminNote = await showDialog<String>(
      context: context,
      builder: (context) {
        final noteController = TextEditingController();
        return AlertDialog(
          title: const Text(
            'Từ chối yêu cầu',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vui lòng nhập lý do từ chối (tùy chọn):',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Nhập lý do từ chối...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                noteController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final note = noteController.text.trim();
                noteController.clear();
                Navigator.of(context).pop(note.isEmpty ? null : note);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );

    if (adminNote == null && _adminNoteController.text.trim().isEmpty) {
      return;
    }

    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Update request status
      await _firestoreService.updateOwnerRequestStatus(
        request.id,
        'rejected',
        currentUser.id,
        adminNote,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối yêu cầu thành công'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _RequestCard extends ConsumerWidget {
  final OwnerRequestModel request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userStream = ref.watch(userStreamProvider(request.userId));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            userStream.when(
              data: (user) {
                if (user == null) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.errorContainer,
                      child: Icon(
                        Icons.person_off_outlined,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      'Người dùng không tìm thấy',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  );
                }
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewUserProfileScreen(userId: user.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          backgroundColor: colorScheme.primaryContainer,
                          child: user.avatarUrl == null
                              ? Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
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
                                user.fullName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (user.phoneNumber != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.phoneNumber!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircularProgressIndicator(),
                title: Text('Đang tải...'),
              ),
              error: (_, __) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Lỗi tải thông tin',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(request.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor(request.status).withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                _getStatusLabel(request.status),
                style: TextStyle(
                  color: _getStatusColor(request.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reason
            if (request.reason != null && request.reason!.isNotEmpty) ...[
              Text(
                'Lý do yêu cầu:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.reason!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Admin note
            if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
              Text(
                'Lý do từ chối:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  request.adminNote!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Date
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (request.updatedAt != request.createdAt) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.update_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(request.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            // Actions
            if (request.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_outlined),
                      label: const Text('Từ chối'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Phê duyệt'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      request.status == 'approved'
                          ? Icons.check_circle_outlined
                          : Icons.cancel_outlined,
                      color: _getStatusColor(request.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.status == 'approved'
                            ? 'Yêu cầu đã được phê duyệt'
                            : 'Yêu cầu đã bị từ chối',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getStatusColor(request.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Đã phê duyệt';
      case 'pending':
        return 'Chờ xử lý';
      case 'rejected':
        return 'Đã từ chối';
      default:
        return status;
    }
  }
}
