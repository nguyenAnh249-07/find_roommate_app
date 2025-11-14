import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/post_model.dart';
import '../common/room/room_detail_screen.dart';
import '../owner/manage_rental_requests_screen.dart';
import '../common/auth/login_screen.dart';
import 'user_management_screen.dart';
import 'admin_statistics_screen.dart';
import 'owner_requests_screen.dart';
import 'room_management_screen.dart';
import 'seed_data_screen.dart';
import '../../services/auth_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Xác nhận đăng xuất',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Close any open dialogs first
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      
      // Clear static caches before sign out
      ChatService.clearCache();
      ManageRentalRequestsScreen.clearCache();
      
      final authService = ref.read(authServiceProvider);
      
      // Sign out first
      await authService.signOut();
      
      // Invalidate providers to clear cached data after sign out
      Future.microtask(() {
        ref.invalidate(currentUserProvider);
        ref.invalidate(authStateProvider);
      });

      if (mounted) {
        // Clear navigation stack and navigate to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng xuất: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null || currentUser.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Quản trị viên',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage_outlined),
            tooltip: 'Seed Data',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SeedDataScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'sign_out') {
                _signOut(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sign_out',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _PendingPostsTab(),
          _OwnerRequestsTab(),
          _UsersTab(),
          _RoomsTab(),
          _StatisticsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        elevation: 4,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pending_outlined),
            selectedIcon: Icon(Icons.pending),
            label: 'Duyệt tin',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_outlined),
            selectedIcon: Icon(Icons.home_work),
            label: 'Yêu cầu Owner',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Người dùng',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Phòng trọ',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
        ],
      ),
    );
  }
}

class _PendingPostsTab extends ConsumerStatefulWidget {
  const _PendingPostsTab();

  @override
  ConsumerState<_PendingPostsTab> createState() => _PendingPostsTabState();
}

class _PendingPostsTabState extends ConsumerState<_PendingPostsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'pending';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final postsStream = FirestoreService().getPostsStream(status: _filterStatus);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bài đăng...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      context,
                      'Chờ duyệt',
                      'pending',
                      Icons.pending_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      'Đã duyệt',
                      'approved',
                      Icons.check_circle_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      'Từ chối',
                      'rejected',
                      Icons.cancel_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Posts list
        Expanded(
          child: StreamBuilder<List<PostModel>>(
      stream: postsStream,
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

              final allPosts = snapshot.data ?? [];
              final searchQuery = _searchController.text.toLowerCase();
              final posts = searchQuery.isEmpty
                  ? allPosts
                  : allPosts
                      .where((post) =>
                          post.title.toLowerCase().contains(searchQuery) ||
                          post.description.toLowerCase().contains(searchQuery))
                      .toList();

              if (posts.isEmpty) {
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
                            searchQuery.isEmpty
                                ? Icons.check_circle_outlined
                                : Icons.search_off_outlined,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          searchQuery.isEmpty
                              ? 'Không có tin nào ${_filterStatus == 'pending' ? 'chờ duyệt' : _filterStatus == 'approved' ? 'đã duyệt' : 'bị từ chối'}'
                              : 'Không tìm thấy bài đăng',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isEmpty
                              ? 'Tất cả các tin đăng đã được xử lý'
                              : 'Thử tìm kiếm với từ khóa khác',
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
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _PostCard(post: post);
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
}

class _PostCard extends ConsumerStatefulWidget {
  final PostModel post;

  const _PostCard({required this.post});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _isLoading = false;

  Future<void> _updatePostStatus(String status, {String? adminNote}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await FirestoreService().updatePostStatus(
        widget.post.id,
        status,
        adminNote: adminNote,
      );
      
      // Also update room status
      final room = await FirestoreService().getRoom(widget.post.roomId);
      if (room != null) {
        await FirestoreService().updateRoom(
          room.copyWith(
            status: status == 'approved' ? 'approved' : 'rejected',
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Đã duyệt tin thành công'
                  : 'Đã từ chối tin',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Từ chối bài đăng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vui lòng nhập lý do từ chối (tùy chọn):',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();
      await _updatePostStatus(
        'rejected',
        adminNote: reason.isEmpty ? null : reason,
      );
    }
  }

  Future<void> _showApproveDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Phê duyệt bài đăng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text('Bạn có chắc chắn muốn phê duyệt bài đăng này?'),
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

    if (confirmed == true) {
      await _updatePostStatus('approved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(roomId: widget.post.roomId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Images
            if (widget.post.images.isNotEmpty)
              Stack(
                children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
              ),
                    child: CachedNetworkImage(
                      imageUrl: widget.post.images.first,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 120,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.post.status)
                            .withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusLabel(widget.post.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  // Image count badge
                  if (widget.post.images.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.post.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Title
                Text(
                    widget.post.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                  // Description
                Text(
                    widget.post.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                  // Admin note if rejected
                  if (widget.post.status == 'rejected' &&
                      widget.post.adminNote != null &&
                      widget.post.adminNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outlined,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lý do từ chối:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.post.adminNote!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Đăng: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.post.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                ),
                const SizedBox(height: 16),
                  // Actions
                  if (widget.post.status == 'pending') ...[
                Row(
                  children: [
                    Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _showRejectDialog,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close_outlined),
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
                            onPressed: _isLoading ? null : _showApproveDialog,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Duyệt'),
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RoomDetailScreen(roomId: widget.post.roomId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Xem chi tiết'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
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
        return 'Đã duyệt';
      case 'pending':
        return 'Chờ duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }
}

class _OwnerRequestsTab extends StatelessWidget {
  const _OwnerRequestsTab();

  @override
  Widget build(BuildContext context) {
    return const OwnerRequestsScreen();
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return const UserManagementScreen();
  }
}

class _RoomsTab extends StatelessWidget {
  const _RoomsTab();

  @override
  Widget build(BuildContext context) {
    return const RoomManagementScreen();
  }
}

class _StatisticsTab extends StatelessWidget {
  const _StatisticsTab();

  @override
  Widget build(BuildContext context) {
    return const AdminStatisticsScreen();
  }
}
