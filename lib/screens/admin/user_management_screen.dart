import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../common/profile/view_user_profile_screen.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'all';
  String _filterStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null || currentUser.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get all users
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList());

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Quản lý người dùng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Search and filter bar
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
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm người dùng...',
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
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildRoleFilterChip(context, 'Tất cả', 'all'),
                            const SizedBox(width: 8),
                            _buildRoleFilterChip(context, 'Người dùng', 'user'),
                            const SizedBox(width: 8),
                            _buildRoleFilterChip(context, 'Chủ trọ', 'owner'),
                            const SizedBox(width: 8),
                            _buildRoleFilterChip(context, 'Admin', 'admin'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusFilterChip(
                                context, 'Tất cả', 'all', Icons.all_inclusive),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip(context, 'Hoạt động',
                                'active', Icons.check_circle_outlined),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip(context, 'Không hoạt động',
                                'inactive', Icons.pause_circle_outlined),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip(context, 'Đã khóa',
                                'banned', Icons.block_outlined),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Users list
          Expanded(
            child: StreamBuilder<List<UserModel>>(
        stream: usersStream,
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

                final allUsers = snapshot.data ?? [];
                final searchQuery = _searchController.text.toLowerCase();

                // Apply filters
                var filteredUsers = allUsers.where((user) {
                  // Role filter
                  if (_filterRole != 'all' && user.role != _filterRole) {
                    return false;
                  }
                  // Status filter
                  if (_filterStatus != 'all' && user.status != _filterStatus) {
                    return false;
                  }
                  // Search filter
                  if (searchQuery.isNotEmpty) {
                    final matchesName =
                        user.fullName.toLowerCase().contains(searchQuery);
                    final matchesEmail =
                        user.email.toLowerCase().contains(searchQuery);
                    final matchesPhone = user.phoneNumber != null &&
                        user.phoneNumber!.toLowerCase().contains(searchQuery);
                    if (!matchesName && !matchesEmail && !matchesPhone) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filteredUsers.isEmpty) {
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
                                  ? Icons.people_outlined
                                  : Icons.search_off_outlined,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            searchQuery.isEmpty
                                ? 'Chưa có người dùng nào'
                                : 'Không tìm thấy người dùng',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isEmpty
                                ? 'Chưa có người dùng nào trong hệ thống'
                                : 'Thử tìm kiếm với từ khóa khác hoặc thay đổi bộ lọc',
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

          // Group by role
                final regularUsers =
                    filteredUsers.where((u) => u.role == 'user').toList();
                final owners =
                    filteredUsers.where((u) => u.role == 'owner').toList();
                final admins =
                    filteredUsers.where((u) => u.role == 'admin').toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
                      if (regularUsers.isNotEmpty) ...[
                        _buildSectionHeader(
                            context, 'Người dùng (${regularUsers.length})'),
              ...regularUsers.map((user) => _UserCard(user: user)),
              const SizedBox(height: 16),
                      ],
                      if (owners.isNotEmpty) ...[
                        _buildSectionHeader(
                            context, 'Chủ trọ (${owners.length})'),
              ...owners.map((user) => _UserCard(user: user)),
              const SizedBox(height: 16),
                      ],
                      if (admins.isNotEmpty) ...[
                        _buildSectionHeader(
                            context, 'Quản trị viên (${admins.length})'),
              ...admins.map((user) => _UserCard(user: user)),
            ],
                    ],
                  ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(BuildContext context, String label, String role) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _filterRole == role;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterRole = role);
        }
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildStatusFilterChip(
      BuildContext context, String label, String status, IconData icon) {
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
            ),
      ),
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool _isLoading = false;

  Future<void> _updateUserStatus(String status) async {
    if (_isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          status == 'banned'
              ? 'Khóa tài khoản'
              : status == 'active'
                  ? 'Kích hoạt tài khoản'
                  : 'Cập nhật trạng thái',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          status == 'banned'
              ? 'Bạn có chắc chắn muốn khóa tài khoản "${widget.user.fullName}"?'
              : status == 'active'
                  ? 'Bạn có chắc chắn muốn kích hoạt tài khoản "${widget.user.fullName}"?'
                  : 'Bạn có chắc chắn muốn cập nhật trạng thái thành "$status"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: status == 'banned'
                ? ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final updatedUser = widget.user.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      await authService.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật trạng thái: $status'),
            backgroundColor: Colors.green,
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

  Future<void> _changeUserRole(String role) async {
    if (_isLoading) return;

    if (widget.user.role == role) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Người dùng đã có vai trò này')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Đổi vai trò',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Bạn có chắc chắn muốn đổi vai trò của "${widget.user.fullName}" từ "${_getRoleLabel(widget.user.role)}" sang "${_getRoleLabel(role)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final updatedUser = widget.user.copyWith(
        role: role,
        updatedAt: DateTime.now(),
      );
      await authService.updateUser(updatedUser);

      // Invalidate current user provider if it's the updated user
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser != null && currentUser.id == widget.user.id) {
        ref.invalidate(currentUserProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã đổi vai trò thành: ${_getRoleLabel(role)}'),
            backgroundColor: Colors.green,
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

  String _getRoleLabel(String role) {
    switch (role) {
      case 'user':
        return 'Người dùng';
      case 'owner':
        return 'Chủ trọ';
      case 'admin':
        return 'Quản trị viên';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ViewUserProfileScreen(userId: widget.user.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: widget.user.avatarUrl != null
                        ? NetworkImage(widget.user.avatarUrl!)
              : null,
                    backgroundColor: colorScheme.primaryContainer,
                    child: widget.user.avatarUrl == null
                        ? Text(
                            widget.user.fullName.isNotEmpty
                                ? widget.user.fullName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
              : null,
        ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
                      widget.user.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.user.phoneNumber != null) ...[
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
                            widget.user.phoneNumber!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                ),
              ],
            ),
          ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRoleChip(context, widget.user.role),
                        const SizedBox(width: 8),
                        _buildStatusChip(context, widget.user.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ngày tạo: ${DateFormat('dd/MM/yyyy').format(widget.user.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Xem hồ sơ'),
                      ],
                    ),
              onTap: () {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                              builder: (_) => ViewUserProfileScreen(
                                userId: widget.user.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.swap_horiz_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Đổi vai trò'),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _showRoleDialog(context, ref),
                );
              },
            ),
                  if (widget.user.status != 'banned')
            PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            Icons.block_outlined,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Khóa tài khoản',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
              onTap: () {
                        Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _updateUserStatus('banned'),
                        );
              },
            ),
                  if (widget.user.status == 'banned')
            PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outlined,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kích hoạt',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
              onTap: () {
                        Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _updateUserStatus('active'),
                        );
              },
            ),
                  if (widget.user.status == 'inactive')
            PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outlined,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kích hoạt',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
              onTap: () {
                        Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _updateUserStatus('active'),
                        );
              },
            ),
          ],
        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, String role) {
    final roleColor = _getRoleColor(role);
    final roleLabel = _getRoleLabel(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        roleLabel,
        style: TextStyle(
          color: roleColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          color: statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Đổi vai trò',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleOption(context, 'user', 'Người dùng', Icons.person_outlined),
            _buildRoleOption(context, 'owner', 'Chủ trọ', Icons.home_work_outlined),
            _buildRoleOption(context, 'admin', 'Quản trị viên', Icons.admin_panel_settings_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(
    BuildContext context,
    String role,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = widget.user.role == role;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: colorScheme.primary,
            )
          : null,
      onTap: () {
        Navigator.of(context).pop();
        _changeUserRole(role);
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'owner':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'banned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Hoạt động';
      case 'inactive':
        return 'Không hoạt động';
      case 'banned':
        return 'Đã khóa';
      default:
        return status;
    }
  }
}
