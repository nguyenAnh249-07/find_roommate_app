import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/room_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/roommate_request_model.dart';
import 'contract/create_contract_screen.dart';

class ManageRoommateRequestsScreen extends ConsumerWidget {
  const ManageRoommateRequestsScreen({super.key});

  // Helper method to resolve ownerId and filter requests (resolve for each request individually)
  Future<List<RoommateRequestModel>> _resolveAndFilterRequests(
    List<RoommateRequestModel> requests,
    String currentUserId,
  ) async {
    final chatService = ChatService();
    
    // Resolve ownerId for each request individually
    // This ensures accuracy even if requests have different ownerIds for the same roomId
    final List<Future<RoommateRequestModel?>> resolveTasks = requests.map((request) async {
      // Resolve ownerId for this specific request
      final actualOwnerId = await chatService.resolveOwnerId(
        request.ownerId,
        request.roomId,
      );
      
      // Only include if the resolved ownerId matches current user
      if (actualOwnerId == currentUserId) {
        return request;
      }
      return null;
    }).toList();
    
    final results = await Future.wait(resolveTasks);
    
    // Filter out null values (requests that don't belong to current user)
    return results.whereType<RoommateRequestModel>().toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Center(child: Text('Chưa đăng nhập'));
    }

    // Load all pending requests, then filter by resolved ownerId
    final requestsStream = FirestoreService().getRoommateRequestsStream(
      status: 'pending',
    );

    return StreamBuilder<List<RoommateRequestModel>>(
      stream: requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRequests = snapshot.data ?? [];

        // Resolve ownerId and filter requests
        return FutureBuilder<List<RoommateRequestModel>>(
          future: _resolveAndFilterRequests(allRequests, currentUser.id),
          builder: (context, filteredSnapshot) {
            if (filteredSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = filteredSnapshot.data ?? [];

            if (requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có yêu cầu nào',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RequestCard(request: request);
              },
            );
          },
        );
      },
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final RoommateRequestModel request;

  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _isLoading = false;

  Future<void> _handleRequest(String status) async {
    setState(() => _isLoading = true);

    try {
      await FirestoreService().updateRoommateRequestStatus(
        widget.request.id,
        status,
      );

      if (status == 'approved') {
        // Add user to room occupants (check capacity first)
        final room = await FirestoreService().getRoom(widget.request.roomId);
        if (room != null) {
          // Check if room has capacity
          if (room.occupants.length >= room.capacity) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Phòng đã đầy, không thể thêm người ở ghép'),
                  backgroundColor: Colors.red,
                ),
              );
              // Revert the status update
              await FirestoreService().updateRoommateRequestStatus(
                widget.request.id,
                'pending',
              );
            }
            return;
          }
          
          // Check if user is already in occupants
          if (room.occupants.contains(widget.request.userId)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Người dùng đã có trong danh sách người ở'),
                ),
              );
            }
            return;
          }
          
          // Add user to occupants
          final updatedOccupants = [...room.occupants, widget.request.userId];
          await FirestoreService().updateRoom(
            room.copyWith(occupants: updatedOccupants),
          );
          
          // Auto-reject other pending requests for the same room if room is now full
          if (updatedOccupants.length >= room.capacity) {
            final allRequests = await FirestoreService()
                .getRoommateRequestsStream(
                  roomId: widget.request.roomId,
                  status: 'pending',
                )
                .first;
            
            // Reject all other pending requests for this room
            final otherRequests = allRequests
                .where((r) => r.id != widget.request.id && r.status == 'pending')
                .toList();
            
            for (final otherRequest in otherRequests) {
              try {
                await FirestoreService().updateRoommateRequestStatus(
                  otherRequest.id,
                  'rejected',
                );
              } catch (e) {
                print('Error auto-rejecting request ${otherRequest.id}: $e');
              }
            }
            
            if (mounted && otherRequests.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã tự động từ chối ${otherRequests.length} yêu cầu khác vì phòng đã đầy',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
          
          // Navigate to create contract screen for roommate
          // Pre-select the approved user
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateContractScreen(
                  roomId: widget.request.roomId,
                  preSelectedUserId: widget.request.userId,
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Đã duyệt yêu cầu'
                  : 'Đã từ chối yêu cầu',
            ),
          ),
        );
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
    final userAsync = ref.watch(userStreamProvider(widget.request.userId));
    final roomAsync = ref.watch(roomDetailProvider(widget.request.roomId));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            userAsync.when(
              data: (user) {
                if (user == null) {
                  return const ListTile(
                    leading: CircleAvatar(child: Icon(Icons.person)),
                    title: Text('Đang tải...'),
                  );
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(user.fullName[0].toUpperCase())
                        : null,
                  ),
                  title: Text(user.fullName),
                  subtitle: Text(user.email),
                );
              },
              loading: () => const ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Đang tải...'),
              ),
              error: (_, __) => const ListTile(
                leading: Icon(Icons.error),
                title: Text('Lỗi'),
              ),
            ),
            const SizedBox(height: 8),
            roomAsync.when(
              data: (room) {
                if (room == null) {
                  return const Text('Đang tải thông tin phòng...');
                }
                return Text(
                  'Phòng: ${room.title}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                );
              },
              loading: () => const Text('Đang tải...'),
              error: (_, __) => const Text('Lỗi'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.request.message),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _handleRequest('rejected'),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _handleRequest('approved'),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Duyệt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

