import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/room_provider.dart';
import '../../models/contract_model.dart';
import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../services/firestore_service.dart';
import '../common/room/room_detail_screen.dart';

class ContractDetailScreen extends ConsumerWidget {
  final ContractModel contract;

  const ContractDetailScreen({
    super.key,
    required this.contract,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final priceFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final roomAsync = ref.watch(roomDetailProvider(contract.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    final statusColor = _getStatusColor(contract.status);
    final statusLabel = _getStatusLabel(contract.status);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Chi tiết hợp đồng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.1),
                      statusColor.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(contract.status),
                        color: statusColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trạng thái hợp đồng',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusLabel,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Room Information
            Text(
              'Thông tin phòng',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomDetailScreen(roomId: contract.roomId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: roomAsync.when(
                    data: (room) {
                      if (room == null) {
                        return const ListTile(
                          leading: Icon(Icons.error_outline),
                          title: Text('Không tìm thấy phòng'),
                        );
                      }
                      return Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: colorScheme.surfaceContainerHighest,
                            ),
                            child: room.images.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      room.images.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.home,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.home,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${room.address}, ${room.district}, ${room.city}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      );
                    },
                    loading: () => const ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Đang tải thông tin phòng...'),
                    ),
                    error: (_, __) => const ListTile(
                      leading: Icon(Icons.error_outline),
                      title: Text('Lỗi tải thông tin phòng'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Contract Information
            Text(
              'Thông tin hợp đồng',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      context,
                      Icons.calendar_today,
                      'Ngày bắt đầu',
                      dateFormat.format(contract.startDate),
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      Icons.event,
                      'Ngày kết thúc',
                      dateFormat.format(contract.endDate),
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      Icons.attach_money,
                      'Giá thuê/tháng',
                      priceFormat.format(contract.monthlyRent),
                      valueColor: colorScheme.primary,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      Icons.account_balance_wallet,
                      'Tiền cọc',
                      priceFormat.format(contract.deposit),
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      Icons.people,
                      'Số người thuê',
                      '${contract.tenantIds.length} người',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tenants List
            Text(
              'Danh sách người thuê',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: contract.tenantIds.map((tenantId) {
                    final tenantAsync = ref.watch(userStreamProvider(tenantId));
                    return tenantAsync.when(
                      data: (tenant) {
                        final isCurrentUser = currentUser?.id == tenantId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: tenant?.avatarUrl != null
                                ? NetworkImage(tenant!.avatarUrl!)
                                : null,
                            backgroundColor: isCurrentUser
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            child: tenant?.avatarUrl == null
                                ? Text(
                                    tenant?.fullName[0].toUpperCase() ?? '?',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrentUser
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tenant?.fullName ?? 'Đang tải...',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCurrentUser)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Bạn',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            tenant?.email ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                      loading: () => const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircularProgressIndicator(strokeWidth: 2),
                        title: Text('Đang tải...'),
                      ),
                      error: (_, __) => const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.error_outline),
                        title: Text('Lỗi tải thông tin'),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (contract.terms.isNotEmpty) ...[
              const SizedBox(height: 24),
              // Terms
              Text(
                'Điều khoản hợp đồng',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    contract.terms,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Contract Dates
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thông tin bổ sung',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.access_time,
                      'Ngày tạo hợp đồng',
                      dateFormat.format(contract.createdAt),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      Icons.update,
                      'Cập nhật lần cuối',
                      dateFormat.format(contract.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
            // Payments Section (only for users)
            if (currentUser != null && contract.tenantIds.contains(currentUser.id)) ...[
              const SizedBox(height: 24),
              _PaymentsSection(
                contractId: contract.id,
                tenantId: currentUser.id,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Đang hoạt động';
      case 'expired':
        return 'Đã hết hạn';
      case 'terminated':
        return 'Đã chấm dứt';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'expired':
        return Icons.access_time;
      case 'terminated':
        return Icons.cancel;
      default:
        return Icons.description;
    }
  }
}

class _PaymentsSection extends ConsumerWidget {
  final String contractId;
  final String tenantId;

  const _PaymentsSection({
    required this.contractId,
    required this.tenantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final priceFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    
    final paymentsStream = FirestoreService().getPaymentsStream(
      contractId: contractId,
      tenantId: tenantId,
    );

    return StreamBuilder<List<PaymentModel>>(
      stream: paymentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final payments = snapshot.data ?? [];

        if (payments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch sử thanh toán',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: payments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final payment = entry.value;
                  final isLast = index == payments.length - 1;
                  
                  final paymentStatusColor = _getPaymentStatusColor(payment.status);
                  final paymentStatusLabel = _getPaymentStatusLabel(payment.status);
                  final isOverdue = payment.isOverdue;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: paymentStatusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getPaymentStatusIcon(payment.status),
                                color: paymentStatusColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          payment.description.isNotEmpty
                                              ? payment.description
                                              : 'Thanh toán tiền thuê',
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOverdue
                                              ? Colors.red.withOpacity(0.1)
                                              : paymentStatusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isOverdue ? 'Quá hạn' : paymentStatusLabel,
                                          style: TextStyle(
                                            color: isOverdue
                                                ? Colors.red
                                                : paymentStatusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_money,
                                        size: 16,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        priceFormat.format(payment.amount),
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hạn thanh toán: ${dateFormat.format(payment.dueDate)}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isOverdue
                                              ? Colors.red
                                              : colorScheme.onSurfaceVariant,
                                          fontWeight: isOverdue
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (payment.paidDate != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Đã thanh toán: ${dateFormat.format(payment.paidDate!)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (payment.paymentMethod.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.payment,
                                          size: 14,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Phương thức: ${_getPaymentMethodLabel(payment.paymentMethod)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) Divider(height: 1, color: colorScheme.outlineVariant),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Đã thanh toán';
      case 'overdue':
        return 'Quá hạn';
      case 'pending':
        return 'Chờ thanh toán';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'overdue':
        return Icons.error;
      case 'pending':
        return Icons.access_time;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'bank_transfer':
        return 'Chuyển khoản';
      case 'momo':
        return 'MoMo';
      case 'zalopay':
        return 'ZaloPay';
      default:
        return method;
    }
  }
}

