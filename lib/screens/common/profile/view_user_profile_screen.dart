import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../models/user_model.dart';

class ViewUserProfileScreen extends ConsumerWidget {
  final String userId;

  const ViewUserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ người dùng'),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Không tìm thấy người dùng'));
          }
          return _buildProfileContent(context, user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Avatar
          CircleAvatar(
            radius: 60,
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 48),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          // Info Cards
          _buildInfoCard(
            context,
            Icons.person,
            'Họ tên',
            user.fullName,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            Icons.email,
            'Email',
            user.email,
          ),
          if (user.gender != null) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              Icons.wc,
              'Giới tính',
              user.gender == 'male'
                  ? 'Nam'
                  : user.gender == 'female'
                      ? 'Nữ'
                      : 'Khác',
            ),
          ],
          if (user.dateOfBirth != null) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              Icons.calendar_today,
              'Ngày sinh',
              '${user.dateOfBirth!.day}/${user.dateOfBirth!.month}/${user.dateOfBirth!.year}',
            ),
          ],
          if (user.phoneNumber != null) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              Icons.phone,
              'Số điện thoại',
              user.phoneNumber!,
            ),
          ],
          if (user.address != null) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              Icons.location_on,
              'Địa chỉ',
              user.address!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}

