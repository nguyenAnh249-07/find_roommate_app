import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/roommate_request_model.dart';

class RoommateRequestScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoommateRequestScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoommateRequestScreen> createState() =>
      _RoommateRequestScreenState();
}

class _RoommateRequestScreenState
    extends ConsumerState<RoommateRequestScreen> {
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lời nhắn')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final room = await FirestoreService().getRoom(widget.roomId);
    if (room == null) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Resolve actual ownerId if it's PLACEHOLDER_OWNER_ID
      final chatService = ChatService();
      final actualOwnerId = await chatService.resolveOwnerId(
        room.ownerId,
        room.id,
      );

      // Validate that ownerId was resolved successfully
      if (actualOwnerId == 'PLACEHOLDER_OWNER_ID' || actualOwnerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể xác định chủ phòng. Vui lòng thử lại sau.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print('RoommateRequestScreen: Creating request with roomId: ${widget.roomId}, resolved ownerId: $actualOwnerId');

      final request = RoommateRequestModel(
        id: FirebaseFirestore.instance.collection('roommate_requests').doc().id,
        userId: currentUser.id,
        roomId: widget.roomId,
        ownerId: actualOwnerId,
        message: _messageController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
      );

      await FirestoreService().createRoommateRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu ở ghép')),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Yêu cầu ở ghép',
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
                  Icons.person_add_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gửi yêu cầu ở ghép',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy giới thiệu về bản thân và lý do bạn muốn ở ghép phòng này',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _messageController,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Lời nhắn',
                  hintText: 'Xin chào, tôi là...',
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

