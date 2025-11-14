import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/room_provider.dart';
import '../common/room/room_detail_screen.dart';
import '../common/room/room_filter_screen.dart';
import '../common/profile/profile_screen.dart';
import '../common/chat/conversations_screen.dart';
import 'my_requests_screen.dart';
import 'saved_rooms_screen.dart';
import 'widgets/room_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  final Map<String, dynamic> _filters = {};

  void _updateFilters(Map<String, dynamic> newFilters) {
    if (mounted) {
      setState(() {
        _filters.clear();
        _filters.addAll(newFilters);
      });
    }
  }
  
  void _clearFilters() {
    if (mounted) {
      setState(() {
        _filters.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    
    if (currentUser == null || currentUser.role != 'user') {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            key: ValueKey(_filters.toString()),
            filters: Map<String, dynamic>.from(_filters),
            onFiltersChanged: _updateFilters,
            onClearFilters: _clearFilters,
          ),
          const MyRequestsScreen(),
          const SavedRoomsScreen(),
          const ConversationsScreen(),
          const ProfileScreen(),
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
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.request_quote_outlined),
            selectedIcon: Icon(Icons.request_quote),
            label: 'Yêu cầu',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Đã lưu',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Nhắn tin',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> filters;
  final Function(Map<String, dynamic>) onFiltersChanged;
  final VoidCallback onClearFilters;

  const _HomeTab({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
    required this.onClearFilters,
  });

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roomsAsync = ref.watch(roomsProvider(widget.filters));

    return CustomScrollView(
      slivers: [
        // App Bar với search
        SliverAppBar(
          expandedHeight: 180,
          floating: false,
          pinned: true,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào! 👋',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tìm phòng trọ phù hợp',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Search Bar
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomFilterScreen(
                                onFilterChanged: (filters) {
                                  widget.onFiltersChanged(filters);
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tìm kiếm phòng trọ...',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.tune_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Quick Actions
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(
                  context,
                  Icons.search_rounded,
                  'Tìm phòng',
                  colorScheme.primary,
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomFilterScreen(
                          onFilterChanged: (filters) {
                            widget.onFiltersChanged(filters);
                          },
                        ),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context,
                  Icons.location_on_rounded,
                  'Gần đây',
                  colorScheme.secondary,
                  () {
                    // Reset filters to show all nearby rooms (sorted by newest)
                    widget.onFiltersChanged({
                      'status': 'approved',
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã hiển thị tất cả phòng trọ'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context,
                  Icons.price_check_rounded,
                  'Giá tốt',
                  Colors.orange,
                  () {
                    widget.onFiltersChanged({
                      'status': 'approved',
                      'maxPrice': 3000000.0, // Dưới 3 triệu
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã lọc phòng giá tốt (< 3 triệu)'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context,
                  Icons.people_rounded,
                  'Ở ghép',
                  Colors.purple,
                  () {
                    widget.onFiltersChanged({
                      'status': 'approved',
                      'allowRoommate': true,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã lọc phòng cho phép ở ghép'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.filters.isEmpty
                      ? 'Phòng trọ nổi bật'
                      : widget.filters.containsKey('maxPrice') && widget.filters['maxPrice'] != null
                          ? 'Phòng giá tốt'
                          : widget.filters.containsKey('allowRoommate') && widget.filters['allowRoommate'] == true
                              ? 'Phòng ở ghép'
                              : 'Phòng trọ nổi bật',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (widget.filters.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      widget.onClearFilters();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa bộ lọc'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Xóa bộ lọc'),
                  ),
              ],
            ),
          ),
        ),
        // Rooms List
        roomsAsync.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
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
                          'Chưa có phòng trọ nào',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hãy tìm kiếm phòng trọ phù hợp với bạn',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final room = rooms[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RoomCard(
                        room: room,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomDetailScreen(roomId: room.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: rooms.length,
                ),
              ),
            );
          },
          loading: () => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            ),
          ),
          error: (error, stack) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
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
                      'Có lỗi xảy ra',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

