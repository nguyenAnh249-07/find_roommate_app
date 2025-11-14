import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/room_model.dart';
import '../common/room/room_detail_screen.dart';
import '../common/profile/view_user_profile_screen.dart';

class RoomManagementScreen extends ConsumerStatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  ConsumerState<RoomManagementScreen> createState() =>
      _RoomManagementScreenState();
}

class _RoomManagementScreenState extends ConsumerState<RoomManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all';
  String? _filterOwnerId;

  // Helper method to resolve ownerId and filter rooms (optimized with batch resolve)
  Future<List<RoomModel>> _resolveAndFilterRooms(
    List<RoomModel> rooms,
    String? filterOwnerId,
    String filterStatus,
    String searchQuery,
  ) async {
    final chatService = ChatService();
    Map<String, String> resolvedMap = {};
    
    // Only batch resolve if filtering by owner
    if (filterOwnerId != null) {
      resolvedMap = await chatService.batchResolveOwnerIds(rooms);
    }

    final filteredRooms = <RoomModel>[];

    for (final room in rooms) {
      // Resolve ownerId if filtering by owner
      if (filterOwnerId != null) {
        final actualOwnerId = resolvedMap[room.id] ?? room.ownerId;
        if (actualOwnerId != filterOwnerId) {
          continue;
        }
      }

      // Status filter
      if (filterStatus != 'all' && room.status != filterStatus) {
        continue;
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        final matchesTitle = room.title.toLowerCase().contains(searchQuery);
        final matchesDescription = room.description.toLowerCase().contains(searchQuery);
        final matchesAddress = room.address.toLowerCase().contains(searchQuery);
        final matchesDistrict = room.district.toLowerCase().contains(searchQuery);
        final matchesCity = room.city.toLowerCase().contains(searchQuery);
        if (!matchesTitle &&
            !matchesDescription &&
            !matchesAddress &&
            !matchesDistrict &&
            !matchesCity) {
          continue;
        }
      }

      filteredRooms.add(room);
    }

    return filteredRooms;
  }

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

    // Get all rooms using FirestoreService
    final roomsStream = FirestoreService().getAllRoomsStream();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Quản lý phòng trọ',
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
                    hintText: 'Tìm kiếm phòng trọ...',
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
                        'Tất cả',
                        'all',
                        Icons.all_inclusive,
                      ),
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        'Đã thuê',
                        'rented',
                        Icons.hotel_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        'Ẩn',
                        'hidden',
                        Icons.visibility_off_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Rooms list
          Expanded(
            child: StreamBuilder<List<RoomModel>>(
              stream: roomsStream,
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

                final allRooms = snapshot.data ?? [];
                final searchQuery = _searchController.text.toLowerCase();

                // Remove duplicates by ID (if any) - should not happen with the updated stream, but just in case
                final uniqueRoomIds = <String>{};
                final uniqueRooms = allRooms.where((room) {
                  if (uniqueRoomIds.contains(room.id)) {
                    return false;
                  }
                  uniqueRoomIds.add(room.id);
                  return true;
                }).toList();
                
                // Debug: Print room count if duplicates found
                if (allRooms.length != uniqueRooms.length) {
                  print('Warning: Found duplicate room IDs in stream. Total: ${allRooms.length}, Unique: ${uniqueRooms.length}');
                } else {
                  print('Total rooms loaded: ${uniqueRooms.length}');
                }
                
                // Resolve ownerId and apply filters
                return FutureBuilder<List<RoomModel>>(
                  future: _resolveAndFilterRooms(
                    uniqueRooms,
                    _filterOwnerId,
                    _filterStatus,
                    searchQuery,
                  ),
                  builder: (context, filterSnapshot) {
                    if (filterSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filteredRooms = filterSnapshot.data ?? [];

                    if (filteredRooms.isEmpty) {
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
                                      ? Icons.home_outlined
                                      : Icons.search_off_outlined,
                                  size: 64,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                searchQuery.isEmpty
                                    ? 'Chưa có phòng trọ nào'
                                    : 'Không tìm thấy phòng trọ',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                searchQuery.isEmpty
                                    ? 'Chưa có phòng trọ nào trong hệ thống'
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

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRooms.length,
                        itemBuilder: (context, index) {
                          final room = filteredRooms[index];
                          return _RoomCard(
                            room: room,
                            onView: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RoomDetailScreen(roomId: room.id),
                                ),
                              );
                            },
                            onDelete: () => _deleteRoom(context, room),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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

  Future<void> _deleteRoom(BuildContext context, RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn xóa phòng trọ này?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${room.address}, ${room.district}, ${room.city}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(room.price)}/tháng',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hành động này sẽ xóa phòng trọ và bài đăng liên quan. Hành động này không thể hoàn tác.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
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
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final firestoreService = FirestoreService();

      // Delete related post
      try {
        final posts = await firestoreService.getPostsStream(roomId: room.id).first;
        for (final post in posts) {
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(post.id)
              .delete();
        }
      } catch (e) {
        print('Error deleting related posts: $e');
        // Continue to delete room even if post deletion fails
      }

      // Delete room
      await firestoreService.deleteRoom(room.id);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa phòng trọ thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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

class _RoomCard extends ConsumerWidget {
  final RoomModel room;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _RoomCard({
    required this.room,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priceFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    // Resolve ownerId first, then get owner info
    return FutureBuilder<String>(
      future: ChatService().resolveOwnerId(room.ownerId, room.id),
      builder: (context, ownerIdSnapshot) {
        final actualOwnerId = ownerIdSnapshot.data ?? room.ownerId;
        
        // Get owner info with resolved ownerId
        final ownerStream = ref.watch(userStreamProvider(actualOwnerId));

        return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            if (room.images.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: room.images.first,
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
                        color: _getStatusColor(room.status).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusLabel(room.status),
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
                  if (room.images.length > 1)
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
                              '${room.images.length}',
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
                    room.title,
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
                    room.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Price and area
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        priceFormat.format(room.price),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.square_foot_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.area.toStringAsFixed(0)} m²',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Address
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${room.address}, ${room.district}, ${room.city}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Owner info
                  ownerStream.when(
                    data: (owner) {
                      if (owner == null) {
                        return const SizedBox.shrink();
                      }
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ViewUserProfileScreen(userId: owner.id),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: owner.avatarUrl != null
                                    ? NetworkImage(owner.avatarUrl!)
                                    : null,
                                backgroundColor: colorScheme.primaryContainer,
                                child: owner.avatarUrl == null
                                    ? Text(
                                        owner.fullName.isNotEmpty
                                            ? owner.fullName[0].toUpperCase()
                                            : 'O',
                                        style: TextStyle(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chủ trọ: ${owner.fullName}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (owner.phoneNumber != null)
                                      Text(
                                        owner.phoneNumber!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  // Room info
                  Row(
                    children: [
                      _buildInfoChip(
                        context,
                        Icons.bed_outlined,
                        _getRoomTypeLabel(room.roomType),
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        context,
                        Icons.people_outlined,
                        '${room.occupants.length}/${room.capacity}',
                      ),
                      if (room.allowRoommate)
                        const SizedBox(width: 8),
                      if (room.allowRoommate)
                        _buildInfoChip(
                          context,
                          Icons.handshake_outlined,
                          'Cho ở ghép',
                        ),
                    ],
                  ),
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
                          'Đăng: ${DateFormat('dd/MM/yyyy HH:mm').format(room.createdAt)}',
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onView,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outlined),
                          label: const Text('Xóa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
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
      case 'rented':
        return Colors.blue;
      case 'hidden':
        return Colors.grey;
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
      case 'rented':
        return 'Đã thuê';
      case 'hidden':
        return 'Ẩn';
      default:
        return status;
    }
  }

  String _getRoomTypeLabel(String roomType) {
    switch (roomType) {
      case 'single':
        return 'Phòng đơn';
      case 'double':
        return 'Phòng đôi';
      case 'shared':
        return 'Ở ghép';
      case 'apartment':
        return 'Căn hộ';
      default:
        return roomType;
    }
  }
}


