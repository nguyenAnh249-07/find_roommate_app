import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../owner/contract/contract_management_screen.dart';
import '../owner/payment/payment_management_screen.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() =>
      _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen> {
  int _selectedIndex = 0;

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
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Quản lý của tôi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _MyContractsTab(),
          _MyPaymentsTab(),
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
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Hợp đồng',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment),
            label: 'Thanh toán',
          ),
        ],
      ),
    );
  }
}

class _MyContractsTab extends StatelessWidget {
  const _MyContractsTab();

  @override
  Widget build(BuildContext context) {
    return const ContractManagementScreen(isOwnerView: false);
  }
}

class _MyPaymentsTab extends StatelessWidget {
  const _MyPaymentsTab();

  @override
  Widget build(BuildContext context) {
    return const PaymentManagementScreen(isOwnerView: false);
  }
}

