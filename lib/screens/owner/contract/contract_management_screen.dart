import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/room_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/contract_model.dart';
import '../../../models/user_model.dart';
import 'create_contract_screen.dart';
import '../../user/contract_detail_screen.dart';

class ContractManagementScreen extends ConsumerStatefulWidget {
  final String? roomId;
  final bool isOwnerView;

  const ContractManagementScreen({
    super.key,
    this.roomId,
    this.isOwnerView = true,
  });

  @override
  ConsumerState<ContractManagementScreen> createState() =>
      _ContractManagementScreenState();
}

class _ContractManagementScreenState
    extends ConsumerState<ContractManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final contractsStream = FirestoreService().getContractsStream(
      ownerId: widget.isOwnerView ? currentUser.id : null,
      tenantId: !widget.isOwnerView ? currentUser.id : null,
      roomId: widget.roomId,
    );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.isOwnerView ? 'Quản lý hợp đồng' : 'Hợp đồng của tôi',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: widget.isOwnerView
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Tạo hợp đồng mới',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateContractScreen(roomId: widget.roomId),
                      ),
                    );
                  },
                ),
              ]
            : null,
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
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm hợp đồng...',
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
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _filterStatus == 'all',
                        onSelected: () {
                          setState(() => _filterStatus = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Đang hoạt động',
                        selected: _filterStatus == 'active',
                        color: Colors.green,
                        onSelected: () {
                          setState(() => _filterStatus = 'active');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Đã hết hạn',
                        selected: _filterStatus == 'expired',
                        color: Colors.orange,
                        onSelected: () {
                          setState(() => _filterStatus = 'expired');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Đã chấm dứt',
                        selected: _filterStatus == 'terminated',
                        color: Colors.red,
                        onSelected: () {
                          setState(() => _filterStatus = 'terminated');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contracts list
          Expanded(
            child: StreamBuilder<List<ContractModel>>(
        stream: contractsStream,
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
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi khi tải dữ liệu',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                var contracts = snapshot.data ?? [];

                // Apply filters
                final searchQuery = _searchController.text.toLowerCase();
                if (searchQuery.isNotEmpty) {
                  contracts = contracts.where((contract) {
                    // Search by room title or tenant names
                    // This will be filtered in the card widget
                    return true;
                  }).toList();
                }

                if (_filterStatus != 'all') {
                  contracts = contracts
                      .where((c) => c.status == _filterStatus)
                      .toList();
                }

          if (contracts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                          size: 80,
                    color: Colors.grey[400],
                  ),
                        const SizedBox(height: 24),
                  Text(
                    'Chưa có hợp đồng nào',
                          style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.isOwnerView)
                          Text(
                            'Nhấn nút + để tạo hợp đồng mới',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Stream will automatically refresh
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index];
                      return _ContractCard(
                        contract: contract,
                        searchQuery: searchQuery,
                        isOwnerView: widget.isOwnerView,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = selected
        ? (color ?? theme.colorScheme.primary)
        : theme.colorScheme.surface;
    final foregroundColor = selected
        ? (color != null ? Colors.white : theme.colorScheme.onPrimary)
        : theme.colorScheme.onSurface;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: backgroundColor,
      checkmarkColor: foregroundColor,
      labelStyle: TextStyle(
        color: foregroundColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : theme.colorScheme.outline.withOpacity(0.3),
      ),
    );
  }
}

class _ContractCard extends ConsumerWidget {
  final ContractModel contract;
  final String searchQuery;
  final bool isOwnerView;

  const _ContractCard({
    required this.contract,
    this.searchQuery = '',
    this.isOwnerView = true,
  });

  bool _matchesSearch() {
    if (searchQuery.isEmpty) return true;
    // Search will be done by room title in the widget
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_matchesSearch()) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final priceFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final roomAsync = ref.watch(roomDetailProvider(contract.roomId));

    // Check if contract is expired
    final isExpired = DateTime.now().isAfter(contract.endDate);
    final statusColor = _getStatusColor(contract.status);
    final statusLabel = _getStatusLabel(contract.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(contract.status),
            color: statusColor,
            size: 24,
          ),
        ),
        title: roomAsync.when(
          data: (room) {
            final roomTitle = room?.title ?? 'Đang tải...';
            // Highlight search query if matches
            if (searchQuery.isNotEmpty &&
                roomTitle.toLowerCase().contains(searchQuery)) {
              return RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  children: _highlightText(context, roomTitle, searchQuery),
                ),
              );
            }
            return Text(
              roomTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            );
          },
          loading: () => Text(
            'Đang tải...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          error: (_, __) => Text(
            'Lỗi tải phòng',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.red,
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${dateFormat.format(contract.startDate)} - ${dateFormat.format(contract.endDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      priceFormat.format(contract.monthlyRent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection(
                  context,
                  'Thông tin hợp đồng',
                  [
                    _buildInfoRow(
                      context,
                      Icons.attach_money,
                      'Giá thuê/tháng:',
                      priceFormat.format(contract.monthlyRent),
                    ),
                    _buildInfoRow(
                      context,
                      Icons.account_balance_wallet,
                      'Tiền cọc:',
                      priceFormat.format(contract.deposit),
                    ),
                    _buildInfoRow(
                      context,
                      Icons.people,
                      'Số người thuê:',
                      '${contract.tenantIds.length} người',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailSection(
                  context,
                  'Danh sách người thuê',
                  contract.tenantIds.map((tenantId) {
                    final tenantAsync = ref.watch(userStreamProvider(tenantId));
                    return tenantAsync.when(
                      data: (tenant) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: tenant?.avatarUrl != null
                              ? NetworkImage(tenant!.avatarUrl!)
                              : null,
                          child: tenant?.avatarUrl == null
                              ? Text(
                                  tenant?.fullName[0].toUpperCase() ?? '?',
                                  style: const TextStyle(fontSize: 16),
                                )
                              : null,
                        ),
                        title: Text(
                          tenant?.fullName ?? 'Đang tải...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          tenant?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      loading: () => const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircularProgressIndicator(strokeWidth: 2),
                        title: Text('Đang tải...'),
                      ),
                      error: (_, __) => const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.error),
                        title: Text('Lỗi'),
                      ),
                    );
                  }).toList(),
                ),
                if (contract.terms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    context,
                    'Điều khoản hợp đồng',
                    [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          contract.terms,
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ContractDetailScreen(contract: contract),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Xem chi tiết'),
                    ),
                    if (isOwnerView && contract.status == 'active')
                      TextButton.icon(
                        onPressed: () {
                          _showTerminateDialog(context, ref, contract);
                        },
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Chấm dứt'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
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

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightText(BuildContext context, String text, String query) {
    final theme = Theme.of(context);
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return spans;
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

  void _showTerminateDialog(
    BuildContext context,
    WidgetRef ref,
    ContractModel contract,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chấm dứt hợp đồng'),
        content: const Text(
          'Bạn có chắc chắn muốn chấm dứt hợp đồng này? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // TODO: Implement contract termination
                // await FirestoreService().updateContractStatus(contract.id, 'terminated');
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tính năng chấm dứt hợp đồng sẽ sớm được cập nhật'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: ${e.toString()}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Chấm dứt'),
          ),
        ],
      ),
    );
  }
}

