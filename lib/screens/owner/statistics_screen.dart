import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/payment_model.dart';
import '../../models/contract_model.dart';
import '../../models/room_model.dart';

enum TimePeriod { thisMonth, lastMonth, thisQuarter, thisYear, allTime }

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.allTime;
  
  // Cache streams to avoid recreating on every build
  Stream<List<PaymentModel>>? _paymentsStream;
  Stream<List<ContractModel>>? _contractsStream;
  Stream<List<RoomModel>>? _roomsStream;

  String? _cachedUserId;

  void _initializeStreams(String userId) {
    if (_cachedUserId == userId && 
        _paymentsStream != null && 
        _contractsStream != null && 
        _roomsStream != null) {
      return; // Streams already initialized for this user
    }
    
    _cachedUserId = userId;
    final firestoreService = FirestoreService();
    _paymentsStream = firestoreService.getPaymentsStream(
      ownerId: userId,
    );
    _contractsStream = firestoreService.getContractsStream(
      ownerId: userId,
    );
    _roomsStream = firestoreService.getRoomsStream(
      status: 'approved',
    );
  }

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

  // Filter payments by time period
  List<PaymentModel> _filterPaymentsByPeriod(List<PaymentModel> payments) {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (_selectedPeriod) {
      case TimePeriod.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
      case TimePeriod.lastMonth:
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 1);
        break;
      case TimePeriod.thisQuarter:
        final quarter = (now.month - 1) ~/ 3;
        startDate = DateTime(now.year, quarter * 3 + 1, 1);
        endDate = DateTime(now.year, quarter * 3 + 4, 1);
        break;
      case TimePeriod.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1);
        break;
      case TimePeriod.allTime:
        return payments;
    }

    return payments.where((p) {
      final date = p.paidDate ?? p.dueDate;
      return (date.isAfter(startDate!) || date.isAtSameMomentAs(startDate)) &&
          date.isBefore(endDate!);
    }).toList();
  }

  // Calculate monthly revenue for chart
  Map<String, double> _calculateMonthlyRevenue(List<PaymentModel> payments) {
    final Map<String, double> monthlyData = {};
    
    for (final payment in payments.where((p) => p.status == 'paid')) {
      final date = payment.paidDate ?? payment.dueDate;
      final monthKey = DateFormat('MM/yyyy').format(date);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + payment.amount;
    }
    
    return monthlyData;
  }

  // Get last 6 months for chart
  List<String> _getLast6Months() {
    final months = <String>[];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MM/yyyy').format(date));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    // Initialize streams for current user (will reuse if same user)
    _initializeStreams(currentUser.id);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Thống kê doanh thu',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Time period filter
          PopupMenuButton<TimePeriod>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: TimePeriod.thisMonth,
                child: Text('Tháng này'),
              ),
              const PopupMenuItem(
                value: TimePeriod.lastMonth,
                child: Text('Tháng trước'),
              ),
              const PopupMenuItem(
                value: TimePeriod.thisQuarter,
                child: Text('Quý này'),
              ),
              const PopupMenuItem(
                value: TimePeriod.thisYear,
                child: Text('Năm nay'),
              ),
              const PopupMenuItem(
                value: TimePeriod.allTime,
                child: Text('Tất cả'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time period indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _getPeriodLabel(),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Summary Cards - Use single StreamBuilder for payments to ensure realtime updates
            StreamBuilder<List<PaymentModel>>(
              stream: _paymentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allPayments = snapshot.data ?? [];
                final payments = _filterPaymentsByPeriod(allPayments);
                
                final totalRevenue = payments
                    .where((p) => p.status == 'paid')
                    .fold<double>(0, (sum, p) => sum + p.amount);
                final pendingAmount = payments
                    .where((p) => p.status == 'pending')
                    .fold<double>(0, (sum, p) => sum + p.amount);
                final overdueAmount = payments
                    .where((p) => p.isOverdue)
                    .fold<double>(0, (sum, p) => sum + p.amount);
                final paidCount = payments.where((p) => p.status == 'paid').length;
                final totalCount = payments.length;
                final paymentRate = totalCount > 0 ? (paidCount / totalCount * 100) : 0.0;

                return Column(
                  children: [
                    _buildStatCard(
                      context,
                      'Tổng doanh thu',
                      _formatCurrency(totalRevenue),
                      Colors.green,
                      Icons.attach_money,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Chờ thanh toán',
                            _formatCurrency(pendingAmount),
                            Colors.orange,
                            Icons.pending,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Quá hạn',
                            _formatCurrency(overdueAmount),
                            Colors.red,
                            Icons.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      context,
                      'Tỷ lệ thanh toán',
                      '${paymentRate.toStringAsFixed(1)}%',
                      paymentRate >= 80 ? Colors.green : paymentRate >= 50 ? Colors.orange : Colors.red,
                      Icons.trending_up,
                      subtitle: '$paidCount/$totalCount thanh toán',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Monthly Revenue Chart - Reuse same stream for realtime updates
            StreamBuilder<List<PaymentModel>>(
              stream: _paymentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allPayments = snapshot.data ?? [];
                final payments = _filterPaymentsByPeriod(allPayments);
                final monthlyData = _calculateMonthlyRevenue(payments);
                final months = _getLast6Months();
                final maxRevenue = monthlyData.values.isEmpty
                    ? 1.0
                    : monthlyData.values.reduce((a, b) => a > b ? a : b);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doanh thu theo tháng (6 tháng gần nhất)',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: months.map((month) {
                              final revenue = monthlyData[month] ?? 0.0;
                              final height = maxRevenue > 0 ? (revenue / maxRevenue) : 0.0;
                              
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Tooltip(
                                        message: _formatCurrency(revenue),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                          ),
                                          height: height * 160,
                                          width: double.infinity,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        month.split('/')[0],
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tổng: ${_formatCurrency(monthlyData.values.fold<double>(0, (a, b) => a + b))}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Rooms Statistics - Real-time updates
            StreamBuilder<List<RoomModel>>(
              stream: _roomsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allRooms = snapshot.data ?? [];
                
                return FutureBuilder<List<RoomModel>>(
                  future: _resolveAndFilterRooms(allRooms, currentUser.id),
                  builder: (context, roomsSnapshot) {
                    if (roomsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final myRooms = roomsSnapshot.data ?? [];
                    final totalRooms = myRooms.length;
                    final occupiedRooms = myRooms
                        .where((room) => room.occupants.isNotEmpty)
                        .length;
                    final availableRooms = totalRooms - occupiedRooms;

                    // Calculate average revenue per room - Reuse payments stream
                    return StreamBuilder<List<PaymentModel>>(
                      stream: _paymentsStream,
                      builder: (context, paymentSnapshot) {
                        final payments = paymentSnapshot.data ?? [];
                        final filteredPayments = _filterPaymentsByPeriod(payments);
                        final totalRevenue = filteredPayments
                            .where((p) => p.status == 'paid')
                            .fold<double>(0, (sum, p) => sum + p.amount);
                        final avgRevenuePerRoom = occupiedRooms > 0
                            ? totalRevenue / occupiedRooms
                            : 0.0;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thống kê phòng',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('Tổng số phòng:', totalRooms.toString()),
                            _buildInfoRow('Đã cho thuê:', occupiedRooms.toString()),
                            _buildInfoRow('Còn trống:', availableRooms.toString()),
                            _buildInfoRow(
                              'Tỷ lệ lấp đầy:',
                              totalRooms > 0
                                  ? '${((occupiedRooms / totalRooms) * 100).toStringAsFixed(1)}%'
                                  : '0%',
                            ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Trung bình doanh thu/phòng:',
                                  _formatCurrency(avgRevenuePerRoom),
                                ),
                          ],
                        ),
                      ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            // Contracts Statistics - Real-time updates
            StreamBuilder<List<ContractModel>>(
              stream: _contractsStream,
              builder: (context, snapshot) {
                final contracts = snapshot.data ?? [];
                final activeContracts = contracts
                    .where((c) => c.status == 'active')
                    .length;
                final expiredContracts = contracts
                    .where((c) => c.status == 'expired')
                    .length;
                final terminatedContracts = contracts
                    .where((c) => c.status == 'terminated')
                    .length;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thống kê hợp đồng',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Tổng hợp đồng:', contracts.length.toString()),
                        _buildInfoRow('Đang hoạt động:', activeContracts.toString()),
                        _buildInfoRow('Đã hết hạn:', expiredContracts.toString()),
                        _buildInfoRow('Đã chấm dứt:', terminatedContracts.toString()),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Recent Payments - Real-time updates
            StreamBuilder<List<PaymentModel>>(
              stream: _paymentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allPayments = snapshot.data ?? [];
                final recentPayments = allPayments
                  ..sort((a, b) => (b.paidDate ?? b.dueDate)
                      .compareTo(a.paidDate ?? a.dueDate));
                final displayPayments = recentPayments.take(5).toList();

                if (displayPayments.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                              'Thanh toán gần đây',
                              style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                            TextButton(
                              onPressed: () {
                                // TODO: Navigate to full payments list
                              },
                              child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                        const SizedBox(height: 8),
                        ...displayPayments.map((payment) => _buildPaymentItem(
                          context,
                          payment,
                          colorScheme,
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case TimePeriod.thisMonth:
        return 'Tháng này';
      case TimePeriod.lastMonth:
        return 'Tháng trước';
      case TimePeriod.thisQuarter:
        return 'Quý này';
      case TimePeriod.thisYear:
        return 'Năm nay';
      case TimePeriod.allTime:
        return 'Tất cả thời gian';
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon, {
    String? subtitle,
  }) {
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
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
    BuildContext context,
    PaymentModel payment,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final statusColor = payment.status == 'paid'
        ? Colors.green
        : payment.status == 'overdue'
            ? Colors.red
            : Colors.orange;
    final statusIcon = payment.status == 'paid'
        ? Icons.check_circle
        : payment.status == 'overdue'
            ? Icons.error
            : Icons.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(payment.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(payment.paidDate ?? payment.dueDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              payment.status == 'paid'
                  ? 'Đã thanh toán'
                  : payment.status == 'overdue'
                      ? 'Quá hạn'
                      : 'Chờ thanh toán',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
  }
}
