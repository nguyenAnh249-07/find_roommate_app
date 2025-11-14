import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';
import '../../models/post_model.dart';
import '../../models/contract_model.dart';
import '../../models/payment_model.dart';
import '../../models/owner_request_model.dart';

class AdminStatisticsScreen extends ConsumerWidget {
  const AdminStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Streams with error handling
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                if (data.isEmpty) return null;
                return UserModel.fromMap(data);
              } catch (e) {
                print('Error parsing user ${doc.id}: $e');
                return null;
              }
            })
            .where((user) => user != null)
            .cast<UserModel>()
            .toList();
      } catch (e) {
        print('Error in usersStream: $e');
        return <UserModel>[];
      }
    });

    final roomsStream = FirebaseFirestore.instance
        .collection('rooms')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                if (data.isEmpty) return null;
                return RoomModel.fromMap(data);
              } catch (e) {
                print('Error parsing room ${doc.id}: $e');
                return null;
              }
            })
            .where((room) => room != null)
            .cast<RoomModel>()
            .toList();
      } catch (e) {
        print('Error in roomsStream: $e');
        return <RoomModel>[];
      }
    });

    final postsStream = FirestoreService().getPostsStream();
    final contractsStream = FirestoreService().getContractsStream();
    final paymentsStream = FirestoreService().getPaymentsStream();
    final ownerRequestsStream = FirestoreService().getOwnerRequestsStream();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Thống kê hệ thống',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh streams
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Cards
              _buildSummarySection(
                context,
                usersStream,
                roomsStream,
                postsStream,
                paymentsStream,
              ),
              const SizedBox(height: 24),
              // Users Statistics
              _buildUsersStatisticsSection(context, usersStream),
              const SizedBox(height: 24),
              // Rooms Statistics
              _buildRoomsStatisticsSection(context, roomsStream),
              const SizedBox(height: 24),
              // Posts Statistics
              _buildPostsStatisticsSection(context, postsStream),
              const SizedBox(height: 24),
              // Contracts & Payments Statistics
              _buildContractsPaymentsStatisticsSection(
                context,
                contractsStream,
                paymentsStream,
              ),
              const SizedBox(height: 24),
              // Owner Requests Statistics
              _buildOwnerRequestsStatisticsSection(
                context,
                ownerRequestsStream,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    Stream<List<UserModel>> usersStream,
    Stream<List<RoomModel>> roomsStream,
    Stream<List<PostModel>> postsStream,
    Stream<List<PaymentModel>> paymentsStream,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<UserModel>>(
      stream: usersStream,
      builder: (context, usersSnapshot) {
        return StreamBuilder<List<RoomModel>>(
          stream: roomsStream,
          builder: (context, roomsSnapshot) {
            return StreamBuilder<List<PostModel>>(
              stream: postsStream,
              builder: (context, postsSnapshot) {
                return StreamBuilder<List<PaymentModel>>(
                  stream: paymentsStream,
                  builder: (context, paymentsSnapshot) {
                    if (usersSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        roomsSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        postsSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        paymentsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // Handle errors
                    if (usersSnapshot.hasError) {
                      print('Error loading users: ${usersSnapshot.error}');
                    }
                    if (roomsSnapshot.hasError) {
                      print('Error loading rooms: ${roomsSnapshot.error}');
                    }
                    if (postsSnapshot.hasError) {
                      print('Error loading posts: ${postsSnapshot.error}');
                    }
                    if (paymentsSnapshot.hasError) {
                      print('Error loading payments: ${paymentsSnapshot.error}');
                    }

                    final users = usersSnapshot.data ?? [];
                    final rooms = roomsSnapshot.data ?? [];
                    final posts = postsSnapshot.data ?? [];
                    final payments = paymentsSnapshot.data ?? [];

                    final totalRevenue = payments
                        .where((p) => p.status == 'paid')
                        .fold<double>(0, (total, p) => total + p.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng quan',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                'Tổng người dùng',
                                users.length.toString(),
                                Icons.people_outlined,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                'Tổng phòng trọ',
                                rooms.length.toString(),
                                Icons.home_outlined,
                                Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                'Tổng bài đăng',
                                posts.length.toString(),
                                Icons.post_add_outlined,
                                Colors.pink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                context,
                                'Tổng doanh thu',
                                _formatCurrency(totalRevenue),
                                Icons.attach_money_outlined,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersStatisticsSection(
    BuildContext context,
    Stream<List<UserModel>> usersStream,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<UserModel>>(
      stream: usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(
            context,
            'Lỗi tải dữ liệu người dùng: ${snapshot.error}',
          );
        }

        final users = snapshot.data ?? [];
        final totalUsers = users.length;
        final regularUsers = users.where((u) => u.role == 'user').length;
        final owners = users.where((u) => u.role == 'owner').length;
        final admins = users.where((u) => u.role == 'admin').length;
        final activeUsers = users.where((u) => u.status == 'active').length;
        final inactiveUsers = users.where((u) => u.status == 'inactive').length;
        final bannedUsers = users.where((u) => u.status == 'banned').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê người dùng',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Người dùng',
                    regularUsers.toString(),
                    totalUsers > 0
                        ? '${((regularUsers / totalUsers) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.person_outlined,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Chủ trọ',
                    owners.toString(),
                    totalUsers > 0
                        ? '${((owners / totalUsers) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.home_work_outlined,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Quản trị viên',
                    admins.toString(),
                    totalUsers > 0
                        ? '${((admins / totalUsers) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.admin_panel_settings_outlined,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Đang hoạt động',
                    activeUsers.toString(),
                    totalUsers > 0
                        ? '${((activeUsers / totalUsers) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.check_circle_outlined,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            if (inactiveUsers > 0 || bannedUsers > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (inactiveUsers > 0)
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Không hoạt động',
                        inactiveUsers.toString(),
                        totalUsers > 0
                            ? '${((inactiveUsers / totalUsers) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        Icons.pause_circle_outlined,
                        Colors.grey,
                      ),
                    ),
                  if (inactiveUsers > 0 && bannedUsers > 0)
                    const SizedBox(width: 12),
                  if (bannedUsers > 0)
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Đã khóa',
                        bannedUsers.toString(),
                        totalUsers > 0
                            ? '${((bannedUsers / totalUsers) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        Icons.block_outlined,
                        Colors.red,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRoomsStatisticsSection(
    BuildContext context,
    Stream<List<RoomModel>> roomsStream,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<RoomModel>>(
      stream: roomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(
            context,
            'Lỗi tải dữ liệu phòng trọ: ${snapshot.error}',
          );
        }

        final rooms = snapshot.data ?? [];
        final totalRooms = rooms.length;
        final approvedRooms = rooms.where((r) => r.status == 'approved').length;
        final pendingRooms = rooms.where((r) => r.status == 'pending').length;
        final rejectedRooms = rooms.where((r) => r.status == 'rejected').length;
        final occupiedRooms = rooms
            .where((r) => r.occupants.isNotEmpty && r.occupants.length >= r.capacity)
            .length;
        final availableRooms = rooms
            .where((r) => r.status == 'approved' && (r.occupants.isEmpty || r.occupants.length < r.capacity))
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê phòng trọ',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Tổng số phòng',
                    totalRooms.toString(),
                    '',
                    Icons.home_outlined,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Đã duyệt',
                    approvedRooms.toString(),
                    totalRooms > 0
                        ? '${((approvedRooms / totalRooms) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.check_circle_outlined,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Chờ duyệt',
                    pendingRooms.toString(),
                    totalRooms > 0
                        ? '${((pendingRooms / totalRooms) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.pending_outlined,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Từ chối',
                    rejectedRooms.toString(),
                    totalRooms > 0
                        ? '${((rejectedRooms / totalRooms) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Đã thuê',
                    occupiedRooms.toString(),
                    totalRooms > 0
                        ? '${((occupiedRooms / totalRooms) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.hotel_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Còn trống',
                    availableRooms.toString(),
                    totalRooms > 0
                        ? '${((availableRooms / totalRooms) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.house_outlined,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostsStatisticsSection(
    BuildContext context,
    Stream<List<PostModel>> postsStream,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<PostModel>>(
      stream: postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(
            context,
            'Lỗi tải dữ liệu bài đăng: ${snapshot.error}',
          );
        }

        final posts = snapshot.data ?? [];
        final totalPosts = posts.length;
        final approvedPosts = posts.where((p) => p.status == 'approved').length;
        final pendingPosts = posts.where((p) => p.status == 'pending').length;
        final rejectedPosts = posts.where((p) => p.status == 'rejected').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê bài đăng',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Tổng bài đăng',
                    totalPosts.toString(),
                    '',
                    Icons.post_add_outlined,
                    Colors.pink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Đã duyệt',
                    approvedPosts.toString(),
                    totalPosts > 0
                        ? '${((approvedPosts / totalPosts) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.check_circle_outlined,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Chờ duyệt',
                    pendingPosts.toString(),
                    totalPosts > 0
                        ? '${((pendingPosts / totalPosts) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.pending_outlined,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Từ chối',
                    rejectedPosts.toString(),
                    totalPosts > 0
                        ? '${((rejectedPosts / totalPosts) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildContractsPaymentsStatisticsSection(
    BuildContext context,
    Stream<List<ContractModel>> contractsStream,
    Stream<List<PaymentModel>> paymentsStream,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<ContractModel>>(
      stream: contractsStream,
      builder: (context, contractSnapshot) {
        return StreamBuilder<List<PaymentModel>>(
          stream: paymentsStream,
          builder: (context, paymentSnapshot) {
            if (contractSnapshot.connectionState == ConnectionState.waiting ||
                paymentSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            if (contractSnapshot.hasError) {
              return _buildErrorWidget(
                context,
                'Lỗi tải dữ liệu hợp đồng: ${contractSnapshot.error}',
              );
            }

            if (paymentSnapshot.hasError) {
              return _buildErrorWidget(
                context,
                'Lỗi tải dữ liệu thanh toán: ${paymentSnapshot.error}',
              );
            }

            final contracts = contractSnapshot.data ?? [];
            final payments = paymentSnapshot.data ?? [];

            final totalContracts = contracts.length;
            final activeContracts =
                contracts.where((c) => c.status == 'active').length;
            final expiredContracts =
                contracts.where((c) => c.status == 'expired').length;

            final totalRevenue = payments
                .where((p) => p.status == 'paid')
                .fold<double>(0, (total, p) => total + p.amount);
            final pendingPayments =
                payments.where((p) => p.status == 'pending').length;
            final overduePayments =
                payments.where((p) => p.status == 'overdue').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thống kê hợp đồng & thanh toán',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Tổng hợp đồng',
                        totalContracts.toString(),
                        '',
                        Icons.description_outlined,
                        Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Đang hoạt động',
                        activeContracts.toString(),
                        totalContracts > 0
                            ? '${((activeContracts / totalContracts) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        Icons.check_circle_outlined,
                        Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Đã hết hạn',
                        expiredContracts.toString(),
                        totalContracts > 0
                            ? '${((expiredContracts / totalContracts) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        Icons.event_busy_outlined,
                        Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Tổng doanh thu',
                        _formatCurrency(totalRevenue),
                        '',
                        Icons.attach_money_outlined,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Chờ thanh toán',
                        pendingPayments.toString(),
                        '',
                        Icons.pending_outlined,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Quá hạn',
                        overduePayments.toString(),
                        '',
                        Icons.warning_outlined,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOwnerRequestsStatisticsSection(
    BuildContext context,
    Stream<List<OwnerRequestModel>> ownerRequestsStream,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<OwnerRequestModel>>(
      stream: ownerRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(
            context,
            'Lỗi tải dữ liệu yêu cầu Owner: ${snapshot.error}',
          );
        }

        final requests = snapshot.data ?? [];
        final totalRequests = requests.length;
        final pendingRequests =
            requests.where((r) => r.status == 'pending').length;
        final approvedRequests =
            requests.where((r) => r.status == 'approved').length;
        final rejectedRequests =
            requests.where((r) => r.status == 'rejected').length;

        if (totalRequests == 0) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê yêu cầu Owner',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Tổng yêu cầu',
                    totalRequests.toString(),
                    '',
                    Icons.home_work_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Chờ xử lý',
                    pendingRequests.toString(),
                    totalRequests > 0
                        ? '${((pendingRequests / totalRequests) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.pending_outlined,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Đã phê duyệt',
                    approvedRequests.toString(),
                    totalRequests > 0
                        ? '${((approvedRequests / totalRequests) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.check_circle_outlined,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Đã từ chối',
                    rejectedRequests.toString(),
                    totalRequests > 0
                        ? '${((rejectedRequests / totalRequests) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, String errorMessage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(2)}B ₫';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M ₫';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K ₫';
    }
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
        .format(amount);
  }
}
