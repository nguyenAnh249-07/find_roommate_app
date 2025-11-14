
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../models/room_model.dart';
import '../../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../../user/roommate_request_screen.dart';
import '../../user/rental_request_screen.dart';
import '../../owner/edit_room_screen.dart';
import 'widgets/favorite_button.dart';

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailProvider(roomId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Không tìm thấy phòng'));
          }
          return _buildContent(context, ref, room, currentUser.value);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    RoomModel room,
    dynamic currentUser,
  ) {
    final priceFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
        // Image Slider
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          actions: [
            Builder(
              builder: (context) {
                final currentUser = ref.watch(currentUserProvider).value;
                if (currentUser == null || currentUser.role != 'user') {
                  return const SizedBox.shrink();
                }
                
                return FavoriteButton(
                  userId: currentUser.id,
                  roomId: room.id,
                );
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: room.images.isNotEmpty
                ? PageView.builder(
                    itemCount: room.images.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: room.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.home, size: 80),
                  ),
          ),
        ),
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        room.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Text(
                      priceFormat.format(room.price),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${room.address}, ${room.district}, ${room.city}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Info Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        Icons.square_foot,
                        'Diện tích',
                        '${room.area} m²',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        Icons.people,
                        'Sức chứa',
                        '${room.occupants.length}/${room.capacity}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        Icons.bed,
                        'Loại phòng',
                        room.roomType,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Description
                Text(
                  'Mô tả',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  room.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                // Amenities
                if (room.amenities.isNotEmpty) ...[
                  Text(
                    'Tiện ích',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: room.amenities.map((amenity) {
                      return Chip(
                        label: Text(amenity),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                // Roommate Section
                if (room.allowRoommate) ...[
                  Text(
                    'Ở ghép',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.isAvailable
                        ? 'Phòng này cho phép ở ghép và còn chỗ trống'
                        : 'Phòng này đã đầy',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, ref, room, currentUser),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    RoomModel room,
    dynamic currentUser,
  ) {
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    // Resolve ownerId if it's PLACEHOLDER_OWNER_ID
    return FutureBuilder<String>(
      future: ChatService().resolveOwnerId(room.ownerId, room.id),
      builder: (context, snapshot) {
        // Wait for resolution to complete
        if (!snapshot.hasData) {
          // Show loading state while resolving
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        
        final actualOwnerId = snapshot.data!;
        // Only compare if actualOwnerId is not PLACEHOLDER_OWNER_ID
        final isOwner = actualOwnerId != 'PLACEHOLDER_OWNER_ID' && currentUser.id == actualOwnerId;
        final isAdmin = currentUser.role == 'admin';
        
        return _buildBottomBarContent(context, ref, room, currentUser, isOwner, isAdmin);
      },
    );
  }

  Widget _buildBottomBarContent(
    BuildContext context,
    WidgetRef ref,
    RoomModel room,
    dynamic currentUser,
    bool isOwner,
    bool isAdmin,
  ) {

    if (isOwner || isAdmin) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditRoomScreen(roomId: room.id),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Chỉnh sửa phòng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Resolve actual ownerId if it's PLACEHOLDER_OWNER_ID
                  final chatService = ChatService();
                  final actualOwnerId = await chatService.resolveOwnerId(
                    room.ownerId,
                    room.id,
                  );
                  
                  if (!context.mounted) return;
                  
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: actualOwnerId,
                        roomId: room.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Nhắn tin'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: room.allowRoommate && room.isAvailable
                    ? () async {
                        // Resolve ownerId before navigating to ensure correct ownerId
                        final chatService = ChatService();
                        final actualOwnerId = await chatService.resolveOwnerId(
                          room.ownerId,
                          room.id,
                        );
                        
                        print('RoomDetailScreen: Navigate to RoommateRequestScreen with roomId: ${room.id}, resolved ownerId: $actualOwnerId');
                        
                        if (!context.mounted) return;
                        
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RoommateRequestScreen(roomId: room.id),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Ở ghép'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                // Chỉ cho phép thuê khi chưa có người thuê nào (occupants.isEmpty)
                onPressed: room.occupants.isEmpty
                    ? () async {
                        // Resolve ownerId before navigating to ensure correct ownerId is passed
                        final chatService = ChatService();
                        final actualOwnerId = await chatService.resolveOwnerId(
                          room.ownerId,
                          room.id,
                        );
                        
                        print('RoomDetailScreen: Navigate to RentalRequestScreen with roomId: ${room.id}, resolved ownerId: $actualOwnerId');
                        
                        if (!context.mounted) return;
                        
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RentalRequestScreen(roomId: room.id),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.home_work_outlined),
                label: const Text('Thuê phòng'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

