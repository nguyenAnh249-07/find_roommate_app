import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../models/room_model.dart';
import '../../services/chat_service.dart';
import '../common/auth/login_screen.dart';
import 'create_room_screen.dart';
import 'edit_room_screen.dart';
import 'contract/contract_management_screen.dart';
import 'payment/payment_management_screen.dart';
import '../common/chat/conversations_screen.dart';
import 'manage_roommate_requests_screen.dart';
import 'manage_rental_requests_screen.dart';
import 'view_occupants_screen.dart';
import 'statistics_screen.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<_MyRoomsTabState> _myRoomsTabKey = GlobalKey<_MyRoomsTabState>();

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
    if (currentUser == null || currentUser.role != 'owner') {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Quản lý phòng trọ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Refresh button - only show on MyRoomsTab
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: () {
                // Trigger refresh in _MyRoomsTab
                _myRoomsTabKey.currentState?.refresh();
              },
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateRoomScreen(),
                  ),
                );
              },
              tooltip: 'Tạo phòng mới',
            ),
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
        children: [
          _MyRoomsTab(key: _myRoomsTabKey),
          const _RoommateRequestsTab(),
          const _RentalRequestsTab(),
          const _ContractsTab(),
          const _PaymentsTab(),
          const _ConversationsTab(),
          const _StatisticsTab(),
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Phòng của tôi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_outlined),
            selectedIcon: Icon(Icons.person_add),
            label: 'Ở ghép',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_outlined),
            selectedIcon: Icon(Icons.home_work),
            label: 'Thuê phòng',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Hợp đồng',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment),
            label: 'Thanh toán',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Nhắn tin',
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

class _MyRoomsTab extends ConsumerStatefulWidget {
  const _MyRoomsTab({super.key});

  @override
  ConsumerState<_MyRoomsTab> createState() => _MyRoomsTabState();
}

class _MyRoomsTabState extends ConsumerState<_MyRoomsTab> {
  Stream<List<RoomModel>>? _cachedStream;
  String? _cachedUserId;

  // Helper method to resolve ownerId and filter rooms (optimized with batch resolve)
  Future<List<RoomModel>> _resolveAndFilterRooms(
    List<RoomModel> rooms,
    String currentUserId,
  ) async {
    final chatService = ChatService();
    
    // Batch resolve all ownerIds in parallel
    final resolvedMap = await chatService.batchResolveOwnerIds(rooms);
    
    // Filter rooms by resolved ownerId
    return rooms.where((room) {
      final actualOwnerId = resolvedMap[room.id] ?? room.ownerId;
      return actualOwnerId == currentUserId;
    }).toList();
  }

  // Create stream with realtime updates and ownerId resolution
  Stream<List<RoomModel>> _createRoomsStream(String currentUserId) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          // Parse rooms from snapshot
          final allRooms = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  // Ensure doc.id is used as room.id
                  final roomData = Map<String, dynamic>.from(data);
                  roomData['id'] = doc.id;
                  return RoomModel.fromMap(roomData);
                } catch (e) {
                  print('Error parsing room ${doc.id}: $e');
                  return null;
                }
              })
              .where((room) => room != null)
              .cast<RoomModel>()
              .toList();
          
          // Resolve ownerId and filter in realtime
          return await _resolveAndFilterRooms(allRooms, currentUserId);
        });
  }

  // Force refresh by recreating stream
  void refresh() {
    setState(() {
      _cachedStream = null;
    });
  }

  void _refreshData() {
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Center(child: Text('Chưa đăng nhập'));
    }

    // Initialize or reuse cached stream for realtime updates
    if (_cachedStream == null || _cachedUserId != currentUser.id) {
      _cachedUserId = currentUser.id;
      _cachedStream = _createRoomsStream(currentUser.id);
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshData();
        // Wait a bit for stream to update
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: StreamBuilder<List<RoomModel>>(
        stream: _cachedStream,
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
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Lỗi: ${snapshot.error}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final myRooms = snapshot.data ?? [];

            if (myRooms.isEmpty) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
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
                          Icons.home_outlined,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chưa có phòng nào',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bắt đầu bằng cách tạo phòng trọ đầu tiên của bạn',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateRoomScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_home_work_outlined),
                          label: const Text(
                            'Tạo phòng mới',
                            style: TextStyle(
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
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
              padding: const EdgeInsets.all(16),
              itemCount: myRooms.length,
              itemBuilder: (context, index) {
                final room = myRooms[index];
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
                          builder: (_) => EditRoomScreen(roomId: room.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: room.images.isNotEmpty
                                ? Image.network(
                                    room.images.first,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      width: 80,
                                      height: 80,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.home_outlined,
                                        size: 40,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.home_outlined,
                                      size: 40,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people_outlined,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${room.occupants.length}/${room.capacity} người',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.square_foot_outlined,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${room.area} m²',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Actions & Status
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(room.status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusLabel(room.status),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.people_outlined,
                                  color: colorScheme.primary,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ViewOccupantsScreen(roomId: room.id),
                                    ),
                                  );
                                },
                                tooltip: 'Xem người ở',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
        },
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

class _RoommateRequestsTab extends StatelessWidget {
  const _RoommateRequestsTab();

  @override
  Widget build(BuildContext context) {
    return const ManageRoommateRequestsScreen();
  }
}

class _RentalRequestsTab extends StatelessWidget {
  const _RentalRequestsTab();

  @override
  Widget build(BuildContext context) {
    return const ManageRentalRequestsScreen();
  }
}

class _ContractsTab extends StatelessWidget {
  const _ContractsTab();

  @override
  Widget build(BuildContext context) {
    return const ContractManagementScreen(isOwnerView: true);
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    return const PaymentManagementScreen(isOwnerView: true);
  }
}

class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context) {
    return const ConversationsScreen();
  }
}

class _StatisticsTab extends StatelessWidget {
  const _StatisticsTab();

  @override
  Widget build(BuildContext context) {
    return const StatisticsScreen();
  }
}

