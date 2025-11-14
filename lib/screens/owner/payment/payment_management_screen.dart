import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../core/providers/room_provider.dart';
import '../../../models/payment_model.dart';
import 'create_payment_screen.dart';

class PaymentManagementScreen extends ConsumerWidget {
  final String? contractId;
  final bool isOwnerView;

  const PaymentManagementScreen({
    super.key,
    this.contractId,
    this.isOwnerView = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    final paymentsStream = FirestoreService().getPaymentsStream(
      ownerId: isOwnerView ? currentUser.id : null,
      tenantId: !isOwnerView ? currentUser.id : null,
      contractId: contractId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnerView ? 'Quản lý thanh toán' : 'Lịch sử thanh toán'),
        actions: isOwnerView
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreatePaymentScreen(contractId: contractId),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: paymentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có hóa đơn nào',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          // Group by status
          final pendingPayments = payments.where((p) => p.status == 'pending').toList();
          final paidPayments = payments.where((p) => p.status == 'paid').toList();
          final overduePayments = payments.where((p) => p.isOverdue).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overduePayments.isNotEmpty) ...[
                _buildSectionHeader(context, 'Quá hạn', Colors.red),
                ...overduePayments.map((payment) => _PaymentCard(
                      payment: payment,
                      isOwnerView: isOwnerView,
                    )),
                const SizedBox(height: 16),
              ],
              if (pendingPayments.isNotEmpty) ...[
                _buildSectionHeader(context, 'Chờ thanh toán', Colors.orange),
                ...pendingPayments.map((payment) => _PaymentCard(
                      payment: payment,
                      isOwnerView: isOwnerView,
                    )),
                const SizedBox(height: 16),
              ],
              if (paidPayments.isNotEmpty) ...[
                _buildSectionHeader(context, 'Đã thanh toán', Colors.green),
                ...paidPayments.map((payment) => _PaymentCard(
                      payment: payment,
                      isOwnerView: isOwnerView,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  final PaymentModel payment;
  final bool isOwnerView;

  const _PaymentCard({
    required this.payment,
    required this.isOwnerView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final priceFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final roomAsync = ref.watch(roomDetailProvider(payment.roomId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: payment.isOverdue ? Colors.red[50] : null,
      child: ExpansionTile(
        leading: Icon(
          _getStatusIcon(payment.status),
          color: _getStatusColor(payment.status),
        ),
        title: roomAsync.when(
          data: (room) => Text(room?.title ?? 'Đang tải...'),
          loading: () => const Text('Đang tải...'),
          error: (_, __) => const Text('Lỗi'),
        ),
        subtitle: Text(
          'Hạn: ${dateFormat.format(payment.dueDate)}',
          style: TextStyle(
            color: payment.isOverdue ? Colors.red : null,
            fontWeight: payment.isOverdue ? FontWeight.bold : null,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Số tiền:', priceFormat.format(payment.amount)),
                _buildInfoRow('Phương thức:', _getPaymentMethodText(payment.paymentMethod)),
                if (payment.paidDate != null)
                  _buildInfoRow('Ngày thanh toán:', dateFormat.format(payment.paidDate!)),
                _buildInfoRow('Mô tả:', payment.description),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(payment.status),
                      backgroundColor: _getStatusColor(payment.status),
                    ),
                    if (isOwnerView && payment.status == 'pending')
                      ElevatedButton(
                        onPressed: () => _markAsPaid(context, ref),
                        child: const Text('Đánh dấu đã thanh toán'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'overdue':
        return Icons.error;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.payment;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodText(String method) {
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

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    try {
      await FirestoreService().updatePaymentStatus(payment.id, 'paid');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đánh dấu đã thanh toán')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    }
  }
}

