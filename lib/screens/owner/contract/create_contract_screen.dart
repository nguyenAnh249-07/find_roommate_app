import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/contract_model.dart';
import '../../../models/room_model.dart';
import '../../../models/rental_request_model.dart';
import '../../../models/user_model.dart';

class CreateContractScreen extends ConsumerStatefulWidget {
  final String? roomId;
  final String? preSelectedUserId; // For roommate requests

  const CreateContractScreen({
    super.key,
    this.roomId,
    this.preSelectedUserId,
  });

  @override
  ConsumerState<CreateContractScreen> createState() =>
      _CreateContractScreenState();
}

class _CreateContractScreenState extends ConsumerState<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _monthlyRentController = TextEditingController();
  final _depositController = TextEditingController();
  final _termsController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _selectedTenantIds = [];
  String? _selectedRoomId;
  bool _isLoading = false;

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

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      _selectedRoomId = widget.roomId;
    }
    if (widget.preSelectedUserId != null) {
      _selectedTenantIds.add(widget.preSelectedUserId!);
    }
  }

  @override
  void dispose() {
    _monthlyRentController.dispose();
    _depositController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Chọn ngày bắt đầu hợp đồng',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Auto-set end date to 12 months from start date if not set
        if (_endDate == null || _endDate!.isBefore(picked)) {
          _endDate = DateTime(
            picked.year + 1,
            picked.month,
            picked.day,
          );
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày bắt đầu trước'),
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 365)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Chọn ngày kết thúc hợp đồng',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      if (picked.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ngày kết thúc phải sau ngày bắt đầu'),
          ),
        );
        return;
      }
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectTenants() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null || _selectedRoomId == null) return;

    // Get approved rental requests for selected room
    final rentalRequests = await FirebaseFirestore.instance
        .collection('rental_requests')
        .where('roomId', isEqualTo: _selectedRoomId)
        .where('status', isEqualTo: 'approved')
        .get();

    // Get approved roommate requests for selected room
    final roommateRequests = await FirebaseFirestore.instance
        .collection('roommate_requests')
        .where('roomId', isEqualTo: _selectedRoomId)
        .where('status', isEqualTo: 'approved')
        .get();

    // Get room occupants as potential tenants
    final room = await FirestoreService().getRoom(_selectedRoomId!);
    final roomOccupants = room?.occupants ?? [];

    // If no requests and no occupants, show message
    if (rentalRequests.docs.isEmpty && 
        roommateRequests.docs.isEmpty && 
        roomOccupants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có người thuê hoặc ở ghép nào cho phòng này'),
          ),
        );
      }
      return;
    }

    final tenantRequests = rentalRequests.docs
        .map((doc) => RentalRequestModel.fromMap(doc.data()))
        .toList();

    // Get all users
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();

    final allUsers = usersSnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => user.role == 'user')
        .toList();

    // Collect user IDs from roommate requests and room occupants
    final Set<String> availableUserIds = {};
    for (final doc in roommateRequests.docs) {
      final userId = doc.data()['userId'] as String?;
      if (userId != null) {
        availableUserIds.add(userId);
      }
    }
    availableUserIds.addAll(roomOccupants);

    // Show tenant selection dialog
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _TenantSelectionDialog(
        currentTenants: Set.from(_selectedTenantIds),
        rentalRequests: tenantRequests,
        allUsers: allUsers,
        availableUserIds: availableUserIds, // Add roommate users
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedTenantIds.clear();
        _selectedTenantIds.addAll(selected);
      });
    }
  }

  Future<void> _createContract() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày bắt đầu và kết thúc')),
      );
      return;
    }
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn phòng')),
      );
      return;
    }
    if (_selectedTenantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 người thuê')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final contract = ContractModel(
        id: FirebaseFirestore.instance.collection('contracts').doc().id,
        roomId: _selectedRoomId!,
        ownerId: currentUser.id,
        tenantIds: _selectedTenantIds,
        startDate: _startDate!,
        endDate: _endDate!,
        monthlyRent: double.parse(_monthlyRentController.text),
        deposit: double.parse(_depositController.text),
        terms: _termsController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
      );

      await FirestoreService().createContract(contract);

      // Update status của các rental request và roommate request liên quan thành 'approved'
      // Tìm các rental request có roomId và tenantId khớp với contract vừa tạo
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // Update rental requests
        final rentalRequestsSnapshot = await FirebaseFirestore.instance
            .collection('rental_requests')
            .where('roomId', isEqualTo: _selectedRoomId)
            .where('status', isEqualTo: 'pending')
            .get();

        // Filter các request có userId trong danh sách tenant đã chọn
        final relevantRentalRequests = rentalRequestsSnapshot.docs.where((doc) {
          final data = doc.data();
          final userId = data['userId'] as String?;
          return userId != null && _selectedTenantIds.contains(userId);
        }).toList();

        // Update status của các rental request liên quan
        for (final doc in relevantRentalRequests) {
          batch.update(
            doc.reference,
            {
              'status': 'approved',
              'updatedAt': DateTime.now().toIso8601String(),
            },
          );
        }
        
        // Update roommate requests
        final roommateRequestsSnapshot = await FirebaseFirestore.instance
            .collection('roommate_requests')
            .where('roomId', isEqualTo: _selectedRoomId)
            .where('status', isEqualTo: 'approved') // Already approved, but ensure consistency
            .get();

        // Filter các request có userId trong danh sách tenant đã chọn
        final relevantRoommateRequests = roommateRequestsSnapshot.docs.where((doc) {
          final data = doc.data();
          final userId = data['userId'] as String?;
          return userId != null && _selectedTenantIds.contains(userId);
        }).toList();

        // Note: Roommate requests are already approved when navigating here,
        // but we ensure they remain approved
        for (final doc in relevantRoommateRequests) {
          batch.update(
            doc.reference,
            {
              'status': 'approved',
              'updatedAt': DateTime.now().toIso8601String(),
            },
          );
        }
        await batch.commit();

        print('✅ Updated ${relevantRentalRequests.length} rental request(s) and ${relevantRoommateRequests.length} roommate request(s) to approved status');
      } catch (e) {
        print('⚠️ Error updating rental request status: $e');
        // Không throw error vì contract đã được tạo thành công
        // Chỉ log để debug
      }

      // Cập nhật số người trong phòng (occupants)
      try {
        final firestoreService = FirestoreService();
        final room = await firestoreService.getRoom(_selectedRoomId!);
        
        if (room != null) {
          // Tạo danh sách occupants mới: thêm các tenantIds chưa có vào danh sách
          final updatedOccupants = List<String>.from(room.occupants);
          for (final tenantId in _selectedTenantIds) {
            if (!updatedOccupants.contains(tenantId)) {
              updatedOccupants.add(tenantId);
            }
          }
          
          // Cảnh báo nếu vượt quá capacity (nhưng vẫn cho phép cập nhật)
          if (updatedOccupants.length > room.capacity) {
            print('⚠️ Warning: Room occupants (${updatedOccupants.length}) exceeds capacity (${room.capacity})');
          }
          
          // Cập nhật phòng với danh sách occupants mới
          final updatedRoom = room.copyWith(
            occupants: updatedOccupants,
            updatedAt: DateTime.now(),
          );
          
          await firestoreService.updateRoom(updatedRoom);
          
          print('✅ Updated room occupants: ${updatedOccupants.length}/${room.capacity}');
        } else {
          print('⚠️ Room not found: $_selectedRoomId');
        }
      } catch (e) {
        print('⚠️ Error updating room occupants: $e');
        // Không throw error vì contract đã được tạo thành công
        // Chỉ log để debug
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo hợp đồng thành công')),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    // Get owner's rooms - get all rooms and filter by ownerId
    // Don't filter by status so owner can create contracts for pending/approved rooms
    final roomsStream = FirestoreService().getAllRoomsStream();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo hợp đồng'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Room Selection
              StreamBuilder<List<RoomModel>>(
                stream: roomsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Lỗi: ${snapshot.error}'),
                    );
                  }

                  final allRooms = snapshot.data ?? [];
                  
                  // Resolve ownerId and filter rooms
                  return FutureBuilder<List<RoomModel>>(
                    future: _resolveAndFilterRooms(allRooms, currentUser.id),
                    builder: (context, roomsSnapshot) {
                      if (roomsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      // Filter by status (approved/pending)
                      final ownerRooms = (roomsSnapshot.data ?? [])
                          .where((room) => 
                              room.status == 'approved' || room.status == 'pending')
                          .toList();

                  if (ownerRooms.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có phòng nào',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vui lòng tạo phòng trước khi tạo hợp đồng',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedRoomId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chọn phòng',
                      prefixIcon: Icon(Icons.home),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return ownerRooms.map<Widget>((room) {
                        return Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            room.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        );
                      }).toList();
                    },
                    items: ownerRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room.id,
                        child: Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedRoomId = value);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Vui lòng chọn phòng';
                      }
                      return null;
                    },
                  );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              // Start Date
              InkWell(
                onTap: _selectStartDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày bắt đầu',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _startDate != null
                        ? DateFormat('dd/MM/yyyy').format(_startDate!)
                        : 'Chọn ngày bắt đầu',
                    style: TextStyle(
                      color: _startDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // End Date
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày kết thúc',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat('dd/MM/yyyy').format(_endDate!)
                        : 'Chọn ngày kết thúc',
                    style: TextStyle(
                      color: _endDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Monthly Rent
              TextFormField(
                controller: _monthlyRentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá thuê/tháng (VNĐ)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập giá thuê';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Deposit
              TextFormField(
                controller: _depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tiền cọc (VNĐ)',
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiền cọc';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Terms
              TextFormField(
                controller: _termsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Điều khoản hợp đồng',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập điều khoản';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Tenant Selection
              InkWell(
                onTap: _selectTenants,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Chọn người thuê',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          if (_selectedTenantIds.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => _selectedTenantIds.clear());
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      if (_selectedTenantIds.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Chọn người thuê từ yêu cầu đã duyệt',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        FutureBuilder<List<UserModel>>(
                          future: Future.wait(
                            _selectedTenantIds.map((id) async {
                              final doc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(id)
                                  .get();
                              return doc.exists
                                  ? UserModel.fromMap(doc.data()!)
                                  : null;
                            }),
                          ).then((users) => users.whereType<UserModel>().toList()),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 20,
                                child: LinearProgressIndicator(),
                              );
                            }
                            final users = snapshot.data ?? [];
                            if (users.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: users.map((user) {
                                    return Chip(
                                      label: Text(
                                        user.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      avatar: CircleAvatar(
                                        radius: 12,
                                        backgroundImage: user.avatarUrl != null
                                            ? NetworkImage(user.avatarUrl!)
                                            : null,
                                        child: user.avatarUrl == null
                                            ? Text(
                                                user.fullName[0].toUpperCase(),
                                                style: const TextStyle(fontSize: 12),
                                              )
                                            : null,
                                      ),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedTenantIds.remove(user.id);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_selectedTenantIds.isEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Chọn phòng trước, sau đó chọn từ danh sách yêu cầu đã duyệt',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createContract,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo hợp đồng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenantSelectionDialog extends StatefulWidget {
  final Set<String> currentTenants;
  final List<RentalRequestModel> rentalRequests;
  final List<UserModel> allUsers;
  final Set<String>? availableUserIds; // For roommate users and room occupants

  const _TenantSelectionDialog({
    required this.currentTenants,
    required this.rentalRequests,
    required this.allUsers,
    this.availableUserIds,
  });

  @override
  State<_TenantSelectionDialog> createState() => _TenantSelectionDialogState();
}

class _TenantSelectionDialogState extends State<_TenantSelectionDialog> {
  late Set<String> _selectedTenants;

  @override
  void initState() {
    super.initState();
    _selectedTenants = Set.from(widget.currentTenants);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Map user IDs to users
    final userMap = {
      for (var user in widget.allUsers) user.id: user
    };

    // Get unique tenant IDs from rental requests
    final tenantIdsFromRental = widget.rentalRequests
        .map((r) => r.userId)
        .toSet();
    
    // Combine with roommate users and room occupants
    final allTenantIds = <String>{...tenantIdsFromRental};
    if (widget.availableUserIds != null) {
      allTenantIds.addAll(widget.availableUserIds!);
    }
    
    final tenantIds = allTenantIds.toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn người thuê',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.availableUserIds != null && widget.availableUserIds!.isNotEmpty
                    ? 'Chọn từ danh sách yêu cầu đã duyệt và người ở ghép'
                    : 'Chọn từ danh sách yêu cầu đã duyệt',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: tenantIds.length,
                itemBuilder: (context, index) {
                  final tenantId = tenantIds[index];
                  final user = userMap[tenantId];
                  
                  // Try to find rental request, but it might be from roommate or occupants
                  final request = widget.rentalRequests
                      .where((r) => r.userId == tenantId)
                      .firstOrNull;

                  if (user == null) return const SizedBox.shrink();

                  final isSelected = _selectedTenants.contains(tenantId);
                  final isFromRoommate = widget.availableUserIds?.contains(tenantId) == true && 
                                         !tenantIdsFromRental.contains(tenantId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedTenants.add(tenantId);
                          } else {
                            _selectedTenants.remove(tenantId);
                          }
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      isThreeLine: false,
                      secondary: CircleAvatar(
                        radius: 20,
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                user.fullName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 14),
                              )
                            : null,
                      ),
                      title: Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (request != null)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          dateFormat.format(request.startDate),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${request.durationMonths} tháng',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else if (isFromRoommate)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add,
                                    size: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Người ở ghép',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selectedTenants),
                    child: Text('Chọn (${_selectedTenants.length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

