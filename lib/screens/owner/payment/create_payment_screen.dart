import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/payment_model.dart';
import '../../../models/contract_model.dart';

class CreatePaymentScreen extends ConsumerStatefulWidget {
  final String? contractId;

  const CreatePaymentScreen({super.key, this.contractId});

  @override
  ConsumerState<CreatePaymentScreen> createState() =>
      _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends ConsumerState<CreatePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String? _selectedPaymentMethod;
  String? _selectedContractId;
  String? _selectedTenantId;
  bool _isLoading = false;

  final List<String> _paymentMethods = [
    'cash',
    'bank_transfer',
    'momo',
    'zalopay',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.contractId != null) {
      _selectedContractId = widget.contractId;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _createPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hạn thanh toán')),
      );
      return;
    }
    if (_selectedContractId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hợp đồng')),
      );
      return;
    }
    if (_selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn người thuê')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final contract = await _getContract(_selectedContractId!);
      if (contract == null) return;

      final payment = PaymentModel(
        id: FirebaseFirestore.instance.collection('payments').doc().id,
        contractId: _selectedContractId!,
        roomId: contract.roomId,
        tenantId: _selectedTenantId!,
        ownerId: currentUser.id,
        amount: double.parse(_amountController.text),
        dueDate: _dueDate!,
        paymentMethod: _selectedPaymentMethod ?? 'cash',
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
      );

      await FirestoreService().createPayment(payment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo hóa đơn thành công')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<ContractModel?> _getContract(String contractId) async {
    final contracts = await FirestoreService()
        .getContractsStream(roomId: null)
        .first;
    return contracts.firstWhere(
      (c) => c.id == contractId,
      orElse: () => throw Exception('Contract not found'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    // Get owner's contracts
    final contractsStream = FirestoreService().getContractsStream(
      ownerId: currentUser.id,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo hóa đơn'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contract Selection
              StreamBuilder(
                stream: contractsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final contracts = snapshot.data ?? [];

                  if (contracts.isEmpty) {
                    return const Text('Chưa có hợp đồng nào');
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedContractId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn hợp đồng',
                      prefixIcon: Icon(Icons.description),
                    ),
                    items: contracts.map((contract) {
                      return DropdownMenuItem(
                        value: contract.id,
                        child: Text('Hợp đồng ${contract.id.substring(0, 8)}...'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedContractId = value;
                        _selectedTenantId = null;
                        if (value != null) {
                          final contract = contracts.firstWhere(
                            (c) => c.id == value,
                          );
                          if (contract.tenantIds.isNotEmpty) {
                            _selectedTenantId = contract.tenantIds.first;
                          }
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Vui lòng chọn hợp đồng';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              // Tenant Selection (simplified)
              if (_selectedContractId != null)
                StreamBuilder(
                  stream: contractsStream,
                  builder: (context, snapshot) {
                    final contracts = snapshot.data ?? [];
                    if (contracts.isEmpty) return const SizedBox.shrink();

                    final contract = contracts.firstWhere(
                      (c) => c.id == _selectedContractId,
                      orElse: () => throw Exception('Contract not found'),
                    );

                    return DropdownButtonFormField<String>(
                      value: _selectedTenantId,
                      decoration: const InputDecoration(
                        labelText: 'Người thuê',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: contract.tenantIds.map((tenantId) {
                        return DropdownMenuItem(
                          value: tenantId,
                          child: Text('User: ${tenantId.substring(0, 8)}...'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedTenantId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vui lòng chọn người thuê';
                        }
                        return null;
                      },
                    );
                  },
                ),
              const SizedBox(height: 20),
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VNĐ)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số tiền';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Due Date
              InkWell(
                onTap: _selectDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Hạn thanh toán',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _dueDate != null
                        ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                        : 'Chọn hạn thanh toán',
                    style: TextStyle(
                      color: _dueDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Payment Method
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Phương thức thanh toán',
                  prefixIcon: Icon(Icons.payment),
                ),
                items: _paymentMethods.map((method) {
                  String label;
                  switch (method) {
                    case 'cash':
                      label = 'Tiền mặt';
                      break;
                    case 'bank_transfer':
                      label = 'Chuyển khoản';
                      break;
                    case 'momo':
                      label = 'MoMo';
                      break;
                    case 'zalopay':
                      label = 'ZaloPay';
                      break;
                    default:
                      label = method;
                  }
                  return DropdownMenuItem(
                    value: method,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPaymentMethod = value);
                },
              ),
              const SizedBox(height: 20),
              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo hóa đơn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

