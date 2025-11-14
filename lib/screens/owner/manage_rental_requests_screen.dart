import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/room_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/rental_request_model.dart';
import 'contract/create_contract_screen.dart';

class ManageRentalRequestsScreen extends ConsumerStatefulWidget {
  const ManageRentalRequestsScreen({super.key});

  // Clear cache (useful for logout)
  static void clearCache() {
    _ManageRentalRequestsScreenState.clearCacheInternal();
    print('ManageRentalRequestsScreen: Cache cleared');
  }

  @override
  ConsumerState<ManageRentalRequestsScreen> createState() =>
      _ManageRentalRequestsScreenState();
}

class _ManageRentalRequestsScreenState extends ConsumerState<ManageRentalRequestsScreen> {
  // Cache để tránh resolve lại ownerId không cần thiết
  static final Map<String, String> _ownerIdCache = {};
  static String? _lastCurrentUserId;
  
  // Internal method to clear cache (can be called from static method)
  static void clearCacheInternal() {
    _ownerIdCache.clear();
    _lastCurrentUserId = null;
  }
  
  // Stream controller for refresh
  Stream<List<RentalRequestModel>>? _cachedStream;
  String? _cachedUserId;
  
  // Force refresh by clearing cache and recreating stream
  void _refreshData() {
    setState(() {
      _ownerIdCache.clear();
      _cachedStream = null;
    });
  }

  // Helper method để transform stream với filter và resolve ownerId
  Stream<List<RentalRequestModel>> _getFilteredRequestsStream(
    Stream<List<RentalRequestModel>> sourceStream,
    String currentUserId,
  ) {
    final chatService = ChatService();
    
    return sourceStream.asyncMap((allRequests) async {
      // Clear cache nếu user thay đổi
      if (_lastCurrentUserId != currentUserId) {
        _ownerIdCache.clear();
        _lastCurrentUserId = currentUserId;
      }

      print('ManageRentalRequests: Loading ${allRequests.length} requests for user: $currentUserId');

      if (allRequests.isEmpty) {
        print('ManageRentalRequests: No requests found');
        return <RentalRequestModel>[];
      }

      // Tạo map để lưu resolved ownerId cho mỗi request
      final Map<String, String> resolvedOwnerIds = {};
      
      // Nhóm requests theo roomId để xử lý batch
      final Map<String, List<RentalRequestModel>> requestsByRoomId = {};
      for (final request in allRequests) {
        requestsByRoomId.putIfAbsent(request.roomId, () => []).add(request);
      }

      // Xác định các roomId cần resolve (chỉ khi ownerId là PLACEHOLDER_OWNER_ID hoặc chưa có trong cache)
      final List<String> roomIdsToResolve = [];
      
      for (final roomId in requestsByRoomId.keys) {
        final firstRequest = requestsByRoomId[roomId]!.first;
        
        // Nếu đã có trong cache, sử dụng cache
        if (_ownerIdCache.containsKey(roomId)) {
          resolvedOwnerIds[roomId] = _ownerIdCache[roomId]!;
          print('ManageRentalRequests: Using cached ownerId for $roomId: ${_ownerIdCache[roomId]}');
        } 
        // Nếu ownerId không phải PLACEHOLDER_OWNER_ID, sử dụng trực tiếp
        else if (firstRequest.ownerId != 'PLACEHOLDER_OWNER_ID' && firstRequest.ownerId.isNotEmpty) {
          resolvedOwnerIds[roomId] = firstRequest.ownerId;
          print('ManageRentalRequests: Using direct ownerId for $roomId: ${firstRequest.ownerId}');
        }
        // Cần resolve
        else {
          roomIdsToResolve.add(roomId);
        }
      }

      print('ManageRentalRequests: Need to resolve ${roomIdsToResolve.length} roomIds out of ${requestsByRoomId.length}');

      // Batch resolve các roomIds cần resolve
      if (roomIdsToResolve.isNotEmpty) {
        final List<Future<void>> resolveTasks = roomIdsToResolve.map((roomId) async {
          try {
            final request = requestsByRoomId[roomId]!.first;
            print('ManageRentalRequests: Resolving roomId: $roomId, original ownerId: ${request.ownerId}');
            
            final actualOwnerId = await chatService.resolveOwnerId(
              request.ownerId,
              roomId,
            );
            
            print('ManageRentalRequests: Resolved ownerId for $roomId: $actualOwnerId');
            
            // Lưu vào cache và resolved map
            _ownerIdCache[roomId] = actualOwnerId;
            resolvedOwnerIds[roomId] = actualOwnerId;
          } catch (e) {
            print('ManageRentalRequests: Error resolving roomId $roomId: $e');
            // Fallback to original ownerId from request
            final request = requestsByRoomId[roomId]!.first;
            resolvedOwnerIds[roomId] = request.ownerId;
          }
        }).toList();
        
        await Future.wait(resolveTasks);
      }

      // Filter requests theo resolved ownerId
      final filteredRequests = allRequests.where((request) {
        // Lấy ownerId đã resolve cho roomId này
        final actualOwnerId = resolvedOwnerIds[request.roomId] ?? request.ownerId;
        
        final matches = actualOwnerId == currentUserId;
        
        if (!matches) {
          print('ManageRentalRequests: Filtered out request ${request.id} (roomId: ${request.roomId}): resolvedOwnerId=$actualOwnerId, currentUserId=$currentUserId');
        } else {
          print('ManageRentalRequests: Keeping request ${request.id} (roomId: ${request.roomId}): resolvedOwnerId=$actualOwnerId matches currentUserId');
        }
        
        return matches;
      }).toList();

      print('ManageRentalRequests: Filtered to ${filteredRequests.length} requests');

      return filteredRequests;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    print('ManageRentalRequests: Current user ID: ${currentUser.id}');

    // Initialize or reuse cached stream for realtime updates
    if (_cachedStream == null || _cachedUserId != currentUser.id) {
      _cachedUserId = currentUser.id;
      
      // Load all pending requests, then filter by resolved ownerId
      final requestsStream = FirestoreService().getRentalRequestsStream(
        status: 'pending',
      ).map((requests) {
        print('ManageRentalRequests: Received ${requests.length} requests from stream');
        return requests;
      });

      // Transform stream với filter và resolve
      _cachedStream = _getFilteredRequestsStream(
        requestsStream,
        currentUser.id,
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Yêu cầu thuê phòng',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              _refreshData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
          // Wait a bit for stream to update
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<List<RentalRequestModel>>(
          stream: _cachedStream,
          builder: (context, snapshot) {
        print('ManageRentalRequests: StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('ManageRentalRequests: Stream error: ${snapshot.error}');
        }
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
                  'Lỗi khi tải dữ liệu: ${snapshot.error}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];

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
                  'Chưa có yêu cầu thuê phòng nào',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RentalRequestCard(request: request);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RentalRequestCard extends ConsumerStatefulWidget {
  final RentalRequestModel request;

  const _RentalRequestCard({required this.request});

  @override
  ConsumerState<_RentalRequestCard> createState() =>
      _RentalRequestCardState();
}

class _RentalRequestCardState extends ConsumerState<_RentalRequestCard> {
  bool _isLoading = false;

  Future<void> _handleRequest(String status) async {
    setState(() => _isLoading = true);

    try {
      if (status == 'rejected') {
        // Chỉ update status khi từ chối (vì không tạo contract)
        await FirestoreService().updateRentalRequestStatus(
          widget.request.id,
          status,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã từ chối yêu cầu'),
            ),
          );
        }
      } else if (status == 'approved') {
        // Khi approve, chỉ navigate đến màn hình tạo contract
        // Status sẽ được update khi tạo contract thành công
        if (mounted) {
          final room = await FirestoreService().getRoom(widget.request.roomId);
          if (room != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateContractScreen(roomId: room.id),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không tìm thấy phòng'),
              ),
            );
          }
        }
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
    final dateFormat = DateFormat('dd/MM/yyyy');
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
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Bắt đầu: ${dateFormat.format(widget.request.startDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Thời gian: ${widget.request.durationMonths} tháng',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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

