import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/room_provider.dart';
import '../common/profile/view_user_profile_screen.dart';

class ViewOccupantsScreen extends ConsumerWidget {
  final String roomId;

  const ViewOccupantsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailProvider(roomId));

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Người đang ở',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Không tìm thấy phòng'));
          }

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          if (room.occupants.isEmpty) {
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
                        Icons.people_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Chưa có người ở',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phòng này hiện đang trống',
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: room.occupants.length,
            itemBuilder: (context, index) {
              final userId = room.occupants[index];
              return _OccupantCard(userId: userId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _OccupantCard extends ConsumerWidget {
  final String userId;

  const _OccupantCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userAsync = ref.watch(userStreamProvider(userId));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Đang tải...'),
            );
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(user.fullName[0].toUpperCase())
                  : null,
            ),
            title: Text(user.fullName),
            subtitle: Text(user.email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ViewUserProfileScreen(userId: userId),
                ),
              );
            },
          );
        },
        loading: () => const ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Đang tải...'),
        ),
        error: (_, __) => const ListTile(
          leading: Icon(Icons.error),
          title: Text('Lỗi'),
        ),
      ),
    );
  }
}

