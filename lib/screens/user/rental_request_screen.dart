import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/rental_request_model.dart';

class RentalRequestScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RentalRequestScreen({super.key, required this.roomId});

  @override
  ConsumerState<RentalRequestScreen> createState() =>
      _RentalRequestScreenState();
}

class _RentalRequestScreenState extends ConsumerState<RentalRequestScreen> {
  final _messageController = TextEditingController();
  final _durationController = TextEditingController();
  DateTime? _startDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _sendRequest() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lời nhắn')),
      );
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày bắt đầu thuê')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập thời gian thuê hợp lệ (ít nhất 1 tháng)')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa đăng nhập')),
      );
      return;
    }
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Get room first
      final room = await FirestoreService().getRoom(widget.roomId);
      if (room == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy phòng')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      print('RentalRequestScreen: Room ownerId from DB: ${room.ownerId}');

      // Resolve actual ownerId if it's PLACEHOLDER_OWNER_ID
      final chatService = ChatService();
      final actualOwnerId = await chatService.resolveOwnerId(
        room.ownerId,
        room.id,
      );

      print('RentalRequestScreen: Resolved ownerId: $actualOwnerId');

      // Validate ownerId
      if (actualOwnerId.isEmpty || actualOwnerId == 'PLACEHOLDER_OWNER_ID') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể xác định người cho thuê. Vui lòng thử lại sau.',
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final request = RentalRequestModel(
        id: FirebaseFirestore.instance.collection('rental_requests').doc().id,
        userId: currentUser.id,
        roomId: widget.roomId,
        ownerId: actualOwnerId, // Use resolved ownerId
        message: _messageController.text.trim(),
        startDate: _startDate!,
        durationMonths: duration,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
      );

      print('RentalRequestScreen: Creating request with ownerId: ${request.ownerId}');

      await FirestoreService().createRentalRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu thuê phòng')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('RentalRequestScreen: Error creating request: $e');
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Yêu cầu thuê phòng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home_work_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gửi yêu cầu thuê phòng',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy điền thông tin để gửi yêu cầu thuê phòng này',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Start Date
              InkWell(
                onTap: _selectStartDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _startDate != null
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: _startDate != null
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày muốn bắt đầu thuê',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_startDate!)
                                  : 'Chọn ngày bắt đầu',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: _startDate != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant.withOpacity(0.6),
                                fontWeight: _startDate != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
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
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Duration
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Thời gian thuê (tháng)',
                  hintText: 'Ví dụ: 12',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.access_time_outlined,
                    color: colorScheme.primary,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: theme.textTheme.bodyLarge,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập thời gian thuê';
                  }
                  final duration = int.tryParse(value);
                  if (duration == null || duration < 1) {
                    return 'Thời gian thuê phải ít nhất 1 tháng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Message
              TextField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Lời nhắn',
                  hintText: 'Xin chào, tôi muốn thuê phòng này...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendRequest,
                  icon: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _isLoading ? 'Đang gửi...' : 'Gửi yêu cầu',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

