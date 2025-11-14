import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

class ChatService {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  // Static cache để chia sẻ giữa các instances
  static final Map<String, String> _ownerIdCache = {};
  
  // Clear cache (useful for logout)
  static void clearCache() {
    _ownerIdCache.clear();
    print('ChatService: Cache cleared');
  }

  // Resolve actual ownerId from roomId if receiverId is PLACEHOLDER_OWNER_ID
  // Public method so it can be used from UI
  Future<String> resolveOwnerId(String receiverId, String? roomId) async {
    // If receiverId is not PLACEHOLDER_OWNER_ID, return as is
    if (receiverId != 'PLACEHOLDER_OWNER_ID') {
      return receiverId;
    }

    // If no roomId, cannot resolve
    if (roomId == null) {
      return receiverId;
    }

    // Check cache first
    if (_ownerIdCache.containsKey(roomId)) {
      return _ownerIdCache[roomId]!;
    }

    try {
      // Try to get owner from room
      final room = await _firestoreService.getRoom(roomId);
      if (room != null && room.ownerId.isNotEmpty && room.ownerId != 'PLACEHOLDER_OWNER_ID') {
        _ownerIdCache[roomId] = room.ownerId;
        return room.ownerId;
      }

      // Try to get owner from post
      final posts = await FirebaseFirestore.instance
          .collection('posts')
          .where('roomId', isEqualTo: roomId)
          .limit(1)
          .get();
      
      if (posts.docs.isNotEmpty) {
        final postData = posts.docs.first.data();
        final postOwnerId = postData['ownerId'] as String?;
        if (postOwnerId != null && postOwnerId.isNotEmpty && postOwnerId != 'PLACEHOLDER_OWNER_ID') {
          _ownerIdCache[roomId] = postOwnerId;
          return postOwnerId;
        }
      }

      // Try to get owner from rental requests
      final rentalRequests = await FirebaseFirestore.instance
          .collection('rentalRequests')
          .where('roomId', isEqualTo: roomId)
          .limit(1)
          .get();
      
      if (rentalRequests.docs.isNotEmpty) {
        final requestData = rentalRequests.docs.first.data();
        final requestOwnerId = requestData['ownerId'] as String?;
        if (requestOwnerId != null && requestOwnerId.isNotEmpty && requestOwnerId != 'PLACEHOLDER_OWNER_ID') {
          _ownerIdCache[roomId] = requestOwnerId;
          print('ChatService: Resolved ownerId from rental request: $requestOwnerId');
          return requestOwnerId;
        }
      }

      // Try to get owner from roommate requests (approved ones)
      final roommateRequests = await FirebaseFirestore.instance
          .collection('roommate_requests')
          .where('roomId', isEqualTo: roomId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      
      if (roommateRequests.docs.isNotEmpty) {
        final requestData = roommateRequests.docs.first.data();
        final requestOwnerId = requestData['ownerId'] as String?;
        if (requestOwnerId != null && requestOwnerId.isNotEmpty && requestOwnerId != 'PLACEHOLDER_OWNER_ID') {
          _ownerIdCache[roomId] = requestOwnerId;
          print('ChatService: Resolved ownerId from roommate request: $requestOwnerId');
          return requestOwnerId;
        }
      }

      // Try to get owner from contracts
      final contracts = await FirebaseFirestore.instance
          .collection('contracts')
          .where('roomId', isEqualTo: roomId)
          .limit(1)
          .get();
      
      if (contracts.docs.isNotEmpty) {
        final contractData = contracts.docs.first.data();
        final contractOwnerId = contractData['ownerId'] as String?;
        if (contractOwnerId != null && contractOwnerId.isNotEmpty && contractOwnerId != 'PLACEHOLDER_OWNER_ID') {
          _ownerIdCache[roomId] = contractOwnerId;
          print('ChatService: Resolved ownerId from contract: $contractOwnerId');
          return contractOwnerId;
        }
      }

      // If still not found, log warning but don't cache PLACEHOLDER_OWNER_ID
      // This allows retry on next call
      print('ChatService: Warning - Could not resolve ownerId for roomId: $roomId');
      // Don't cache PLACEHOLDER_OWNER_ID to allow retry
      return receiverId;
    } catch (e) {
      print('ChatService: Error resolving ownerId: $e');
      return receiverId;
    }
  }

  // Batch resolve ownerId for multiple rooms (optimized with parallel queries)
  Future<Map<String, String>> batchResolveOwnerIds(List<RoomModel> rooms) async {
    final Map<String, String> resolvedMap = {};
    final List<String> roomIdsToResolve = [];

    // First pass: check cache and collect roomIds that need resolving
    for (final room in rooms) {
      // Skip if already resolved or not PLACEHOLDER_OWNER_ID
      if (room.ownerId != 'PLACEHOLDER_OWNER_ID') {
        resolvedMap[room.id] = room.ownerId;
        continue;
      }

      // Check cache first
      if (_ownerIdCache.containsKey(room.id)) {
        resolvedMap[room.id] = _ownerIdCache[room.id]!;
        continue;
      }

      // Add to list for batch resolve
      roomIdsToResolve.add(room.id);
    }

    // If no rooms need resolving, return early
    if (roomIdsToResolve.isEmpty) {
      return resolvedMap;
    }

    // Batch resolve all rooms in parallel
    final List<Future<void>> resolveTasks = roomIdsToResolve.map((roomId) async {
      final ownerId = await _resolveSingleOwnerId(roomId);
      resolvedMap[roomId] = ownerId;
    }).toList();

    // Wait for all resolves to complete in parallel
    await Future.wait(resolveTasks);

    return resolvedMap;
  }

  // Internal method to resolve a single ownerId
  Future<String> _resolveSingleOwnerId(String roomId) async {
    try {
      // Try to get owner from room (use getRoom which might be cached)
      final room = await _firestoreService.getRoom(roomId);
      if (room != null && room.ownerId.isNotEmpty && room.ownerId != 'PLACEHOLDER_OWNER_ID') {
        _ownerIdCache[roomId] = room.ownerId;
        return room.ownerId;
      }

      // Try to get owner from post (parallel query)
      final postFuture = FirebaseFirestore.instance
          .collection('posts')
          .where('roomId', isEqualTo: roomId)
          .limit(1)
          .get();
      
      // Try to get owner from rental requests (parallel query)
      final rentalRequestFuture = FirebaseFirestore.instance
          .collection('rentalRequests')
          .where('roomId', isEqualTo: roomId)
          .limit(1)
          .get();

      // Wait for both queries in parallel
      final results = await Future.wait([postFuture, rentalRequestFuture]);
      final posts = results[0] as QuerySnapshot;
      final rentalRequests = results[1] as QuerySnapshot;
      
      if (posts.docs.isNotEmpty) {
        final postData = posts.docs.first.data() as Map<String, dynamic>;
        final postOwnerId = postData['ownerId'] as String?;
        if (postOwnerId != null && postOwnerId.isNotEmpty && postOwnerId != 'PLACEHOLDER_OWNER_ID') {
          _ownerIdCache[roomId] = postOwnerId;
          return postOwnerId;
        }
      }

      if (rentalRequests.docs.isNotEmpty) {
        final requestData = rentalRequests.docs.first.data() as Map<String, dynamic>;
        final requestOwnerId = requestData['ownerId'] as String?;
        if (requestOwnerId != null && requestOwnerId.isNotEmpty && requestOwnerId != 'PLACEHOLDER_OWNER_ID') {
          _ownerIdCache[roomId] = requestOwnerId;
          return requestOwnerId;
        }
      }

      // Cache the result even if it's still PLACEHOLDER_OWNER_ID
      _ownerIdCache[roomId] = 'PLACEHOLDER_OWNER_ID';
      return 'PLACEHOLDER_OWNER_ID';
    } catch (e) {
      print('ChatService: Error resolving ownerId for $roomId: $e');
      return 'PLACEHOLDER_OWNER_ID';
    }
  }

  // Gửi tin nhắn
  Future<void> sendMessage({
    required String receiverId,
    required String text,
    String? roomId,
  }) async {
    final senderId = _authService.currentUser?.uid;
    if (senderId == null) return;

    // Resolve actual ownerId if receiverId is PLACEHOLDER_OWNER_ID
    final actualReceiverId = await resolveOwnerId(receiverId, roomId);

    final message = MessageModel(
      id: FirebaseFirestore.instance.collection('messages').doc().id,
      senderId: senderId,
      receiverId: actualReceiverId,
      text: text,
      createdAt: DateTime.now(),
      isRead: false,
      roomId: roomId,
    );

    await _firestoreService.sendMessage(message);
  }

  // Lấy danh sách tin nhắn giữa 2 user
  Stream<List<MessageModel>> getMessagesStream(String otherUserId) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }
    return _firestoreService.getMessagesStream(currentUserId, otherUserId);
  }

  // Đánh dấu tin nhắn đã đọc
  Future<void> markAsRead(String messageId) async {
    await _firestoreService.markMessageAsRead(messageId);
  }

  // Lấy danh sách conversations với thông tin user (cả sender và receiver)
  Stream<List<Map<String, dynamic>>> getConversationsStream() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      print('ChatService: No current user, returning empty stream');
      return Stream.value([]);
    }

    // Use Firestore snapshots for real-time updates instead of Timer
    // This will automatically update when messages change
    final controller = StreamController<List<Map<String, dynamic>>>();
    Timer? periodicTimer;
    StreamSubscription? sub1;
    StreamSubscription? sub2;
    bool hasEmitted = false;
    
    // Helper function to load and emit conversations
    Future<void> loadAndEmit() async {
      try {
        if (controller.isClosed) return;
        final conversations = await _loadConversations(currentUserId);
        if (!controller.isClosed) {
          hasEmitted = true;
          controller.add(conversations);
          print('ChatService: Loaded ${conversations.length} conversations');
        }
      } catch (error, stackTrace) {
        print('ChatService: Error loading conversations: $error');
        print('ChatService: Stack trace: $stackTrace');
        if (!controller.isClosed) {
          // Emit empty list on error, but ensure we emit at least once
          if (!hasEmitted) {
            hasEmitted = true;
            controller.add([]);
          }
        }
      }
    }
    
    // Load and emit immediately
    loadAndEmit();

    // Update periodically (less frequently - every 10 seconds instead of 2)
    periodicTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      loadAndEmit();
    });

    // Also listen to messages collection for real-time updates
    try {
      final messagesStream = FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: currentUserId)
          .snapshots();
      
      final receiverMessagesStream = FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .snapshots();

      sub1 = messagesStream.listen(
        (_) {
          if (!controller.isClosed) {
            loadAndEmit();
          }
        },
        onError: (error) {
          print('ChatService: Error in sender messages stream: $error');
        },
      );

      sub2 = receiverMessagesStream.listen(
        (_) {
          if (!controller.isClosed) {
            loadAndEmit();
          }
        },
        onError: (error) {
          print('ChatService: Error in receiver messages stream: $error');
        },
      );
    } catch (e) {
      print('ChatService: Error setting up message streams: $e');
    }

    // Clean up resources when stream is cancelled
    controller.onCancel = () {
      print('ChatService: Stream cancelled, cleaning up');
      periodicTimer?.cancel();
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream.distinct((prev, next) {
      // Only emit if conversations changed
      if (prev.length != next.length) return false;
      for (int i = 0; i < prev.length; i++) {
        final prevConv = prev[i];
        final nextConv = next[i];
        if (prevConv['user'].id != nextConv['user'].id) return false;
        final prevLastMsg = prevConv['lastMessage'] as MessageModel?;
        final nextLastMsg = nextConv['lastMessage'] as MessageModel?;
        if (prevLastMsg?.id != nextLastMsg?.id) return false;
        if (prevConv['unreadCount'] != nextConv['unreadCount']) return false;
      }
      return true;
    });
  }

  Future<List<Map<String, dynamic>>> _loadConversations(String currentUserId) async {
    try {
      print('ChatService: Loading conversations for user: $currentUserId');
      
      // Get messages where current user is sender
      final senderSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: currentUserId)
          .get();
      print('ChatService: Found ${senderSnapshot.docs.length} messages as sender');

      // Get messages where current user is receiver
      final receiverSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .get();
      print('ChatService: Found ${receiverSnapshot.docs.length} messages as receiver');

      // Get unique user IDs from both queries
      final receiverIds = <String>{};
      for (final doc in senderSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null || data.isEmpty) {
            print('ChatService: Message ${doc.id} has null or empty data');
            continue;
          }
          
          // Use doc.id if message.id is missing
          final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
          final messageData = Map<String, dynamic>.from(data);
          messageData['id'] = messageId;
          
          final message = MessageModel.fromMap(messageData);
          var receiverId = message.receiverId;
          print('ChatService: Processing message ${messageId}, receiverId: $receiverId, roomId: ${message.roomId}');
          
          // If receiverId is PLACEHOLDER_OWNER_ID, try to get owner from room or post
          if (receiverId == 'PLACEHOLDER_OWNER_ID' && message.roomId != null) {
            try {
              print('ChatService: Resolving PLACEHOLDER_OWNER_ID for roomId: ${message.roomId}');
              // First try to get owner from room
              final room = await _firestoreService.getRoom(message.roomId!);
              if (room != null) {
                print('ChatService: Room found, ownerId: ${room.ownerId}');
                if (room.ownerId.isNotEmpty && room.ownerId != 'PLACEHOLDER_OWNER_ID') {
                  receiverId = room.ownerId;
                  print('ChatService: Resolved owner from room: $receiverId');
                } else {
                  print('ChatService: Room ownerId is invalid, trying post...');
                  // If room.ownerId is still PLACEHOLDER_OWNER_ID, try to get from post
                  final posts = await FirebaseFirestore.instance
                      .collection('posts')
                      .where('roomId', isEqualTo: message.roomId!)
                      .limit(1)
                      .get();
                  
                  if (posts.docs.isNotEmpty) {
                    final postData = posts.docs.first.data();
                    final postOwnerId = postData['ownerId'] as String?;
                    print('ChatService: Post found, ownerId: $postOwnerId');
                    if (postOwnerId != null && postOwnerId.isNotEmpty && postOwnerId != 'PLACEHOLDER_OWNER_ID') {
                      receiverId = postOwnerId;
                      print('ChatService: Resolved owner from post: $receiverId');
                    } else {
                      print('ChatService: Post ownerId is also invalid, trying alternative methods...');
                      // Try alternative: query room directly by ID (not by ownerId)
                      try {
                        final roomDoc = await FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(message.roomId!)
                            .get();
                        
                        if (roomDoc.exists) {
                          final roomData = roomDoc.data();
                          final altOwnerId = roomData?['ownerId'] as String?;
                          if (altOwnerId != null && altOwnerId.isNotEmpty && altOwnerId != 'PLACEHOLDER_OWNER_ID') {
                            receiverId = altOwnerId;
                            print('ChatService: Found owner from direct room query: $receiverId');
                          } else {
                            // Last resort: try to find from rental/roommate requests
                            print('ChatService: Trying to find owner from requests...');
                            final rentalRequests = await FirebaseFirestore.instance
                                .collection('rentalRequests')
                                .where('roomId', isEqualTo: message.roomId!)
                                .limit(1)
                                .get();
                            
                            if (rentalRequests.docs.isNotEmpty) {
                              final requestData = rentalRequests.docs.first.data();
                              final requestOwnerId = requestData['ownerId'] as String?;
                              if (requestOwnerId != null && requestOwnerId.isNotEmpty && requestOwnerId != 'PLACEHOLDER_OWNER_ID') {
                                receiverId = requestOwnerId;
                                print('ChatService: Found owner from rental request: $receiverId');
                              }
                            }
                          }
                        }
                      } catch (e) {
                        print('ChatService: Error in alternative owner resolution: $e');
                      }
                    }
                  } else {
                    print('ChatService: No post found for roomId: ${message.roomId}');
                  }
                }
              } else {
                print('ChatService: Room not found for roomId: ${message.roomId}');
                // Try to find from post directly
                final posts = await FirebaseFirestore.instance
                    .collection('posts')
                    .where('roomId', isEqualTo: message.roomId!)
                    .limit(1)
                    .get();
                
                if (posts.docs.isNotEmpty) {
                  final postData = posts.docs.first.data();
                  final postOwnerId = postData['ownerId'] as String?;
                  if (postOwnerId != null && postOwnerId.isNotEmpty && postOwnerId != 'PLACEHOLDER_OWNER_ID') {
                    receiverId = postOwnerId;
                    print('ChatService: Resolved owner from post (room not found): $receiverId');
                  }
                }
              }
            } catch (e, stackTrace) {
              print('ChatService: Error resolving PLACEHOLDER_OWNER_ID: $e');
              print('ChatService: Stack trace: $stackTrace');
            }
          }
          
          // Filter out invalid IDs
          if (receiverId.isEmpty) {
            print('ChatService: Skipping message ${messageId} - receiverId is empty');
            continue;
          }
          if (receiverId == 'PLACEHOLDER_OWNER_ID') {
            print('ChatService: Skipping message ${messageId} - receiverId is still PLACEHOLDER_OWNER_ID');
            continue;
          }
          if (receiverId == currentUserId) {
            print('ChatService: Skipping message ${messageId} - receiverId equals currentUserId');
            continue;
          }
          
          print('ChatService: Adding receiverId to set: $receiverId');
          receiverIds.add(receiverId);
        } catch (e, stackTrace) {
          print('ChatService: Error parsing message receiverId: $e');
          print('ChatService: Stack trace: $stackTrace');
        }
      }

      final senderIds = <String>{};
      for (final doc in receiverSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null || data.isEmpty) {
            print('ChatService: Message ${doc.id} has null or empty data (receiver)');
            continue;
          }
          
          // Use doc.id if message.id is missing
          final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
          final messageData = Map<String, dynamic>.from(data);
          messageData['id'] = messageId;
          
          final message = MessageModel.fromMap(messageData);
          var senderId = message.senderId;
          print('ChatService: Processing message ${messageId} (as receiver), senderId: $senderId, roomId: ${message.roomId}');
          
          // If senderId is PLACEHOLDER_OWNER_ID, try to get owner from room or post
          if (senderId == 'PLACEHOLDER_OWNER_ID' && message.roomId != null) {
            try {
              print('ChatService: Resolving PLACEHOLDER_OWNER_ID for roomId: ${message.roomId} (receiver side)');
              // First try to get owner from room
              final room = await _firestoreService.getRoom(message.roomId!);
              if (room != null) {
                print('ChatService: Room found (receiver side), ownerId: ${room.ownerId}');
                if (room.ownerId.isNotEmpty && room.ownerId != 'PLACEHOLDER_OWNER_ID') {
                  senderId = room.ownerId;
                  print('ChatService: Resolved owner from room: $senderId');
                } else {
                  print('ChatService: Room ownerId is invalid, trying post...');
                  // If room.ownerId is still PLACEHOLDER_OWNER_ID, try to get from post
                  final posts = await FirebaseFirestore.instance
                      .collection('posts')
                      .where('roomId', isEqualTo: message.roomId!)
                      .limit(1)
                      .get();

                  if (posts.docs.isNotEmpty) {
                    final postData = posts.docs.first.data();
                    final postOwnerId = postData['ownerId'] as String?;
                    print('ChatService: Post found (receiver side), ownerId: $postOwnerId');
                    if (postOwnerId != null && postOwnerId.isNotEmpty && postOwnerId != 'PLACEHOLDER_OWNER_ID') {
                      senderId = postOwnerId;
                      print('ChatService: Resolved owner from post: $senderId');
                    } else {
                      print('ChatService: Post ownerId is also invalid, trying alternative methods...');
                      // Try alternative: query room directly by ID (not by ownerId)
                      try {
                        final roomDoc = await FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(message.roomId!)
                            .get();
                        
                        if (roomDoc.exists) {
                          final roomData = roomDoc.data();
                          final altOwnerId = roomData?['ownerId'] as String?;
                          if (altOwnerId != null && altOwnerId.isNotEmpty && altOwnerId != 'PLACEHOLDER_OWNER_ID') {
                            senderId = altOwnerId;
                            print('ChatService: Found owner from direct room query: $senderId');
                          } else {
                            // Last resort: try to find from rental/roommate requests
                            print('ChatService: Trying to find owner from requests...');
                            final rentalRequests = await FirebaseFirestore.instance
                                .collection('rentalRequests')
                                .where('roomId', isEqualTo: message.roomId!)
                                .limit(1)
                                .get();
                            
                            if (rentalRequests.docs.isNotEmpty) {
                              final requestData = rentalRequests.docs.first.data();
                              final requestOwnerId = requestData['ownerId'] as String?;
                              if (requestOwnerId != null && requestOwnerId.isNotEmpty && requestOwnerId != 'PLACEHOLDER_OWNER_ID') {
                                senderId = requestOwnerId;
                                print('ChatService: Found owner from rental request: $senderId');
                              }
                            }
                          }
                        }
                      } catch (e) {
                        print('ChatService: Error in alternative owner resolution: $e');
                      }
                    }
                  } else {
                    print('ChatService: No post found for roomId: ${message.roomId}');
                  }
                }
              } else {
                print('ChatService: Room not found for roomId: ${message.roomId} (receiver side)');
                // Try to find from post directly
                final posts = await FirebaseFirestore.instance
                    .collection('posts')
                    .where('roomId', isEqualTo: message.roomId!)
                    .limit(1)
                    .get();
                
                if (posts.docs.isNotEmpty) {
                  final postData = posts.docs.first.data();
                  final postOwnerId = postData['ownerId'] as String?;
                  if (postOwnerId != null && postOwnerId.isNotEmpty && postOwnerId != 'PLACEHOLDER_OWNER_ID') {
                    senderId = postOwnerId;
                    print('ChatService: Resolved owner from post (room not found): $senderId');
                  }
                }
              }
            } catch (e, stackTrace) {
              print('ChatService: Error resolving PLACEHOLDER_OWNER_ID: $e');
              print('ChatService: Stack trace: $stackTrace');
            }
          }
          
          // Filter out invalid IDs
          if (senderId.isEmpty) {
            print('ChatService: Skipping message ${messageId} - senderId is empty');
            continue;
          }
          if (senderId == 'PLACEHOLDER_OWNER_ID') {
            print('ChatService: Skipping message ${messageId} - senderId is still PLACEHOLDER_OWNER_ID');
            continue;
          }
          if (senderId == currentUserId) {
            print('ChatService: Skipping message ${messageId} - senderId equals currentUserId');
            continue;
          }
          
          print('ChatService: Adding senderId to set: $senderId');
          senderIds.add(senderId);
        } catch (e, stackTrace) {
          print('ChatService: Error parsing message senderId: $e');
          print('ChatService: Stack trace: $stackTrace');
        }
      }

      // Combine both sets
      final allUserIds = receiverIds.union(senderIds);
      print('ChatService: Found ${allUserIds.length} unique user IDs');

      final List<Map<String, dynamic>> conversations = [];
    
      for (final userId in allUserIds) {
        try {
          final user = await _authService.getUserFromFirestore(userId);
          if (user != null) {
            final lastMessage = await _getLastMessage(currentUserId, userId);
            final unreadCount = await _getUnreadCount(currentUserId, userId);
            
            conversations.add({
              'user': user,
              'lastMessage': lastMessage,
              'unreadCount': unreadCount,
            });
          } else {
            print('ChatService: User not found for ID: $userId');
          }
        } catch (e, stackTrace) {
          print('ChatService: Error loading conversation for user $userId: $e');
          print('ChatService: Stack trace: $stackTrace');
        }
      }
      
      // Sort by last message time (most recent first)
      conversations.sort((a, b) {
        final aTime = (a['lastMessage'] as MessageModel?)?.createdAt ?? DateTime(1970);
        final bTime = (b['lastMessage'] as MessageModel?)?.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      
      print('ChatService: Successfully loaded ${conversations.length} conversations');
      return conversations;
    } catch (e, stackTrace) {
      print('ChatService: Error in _loadConversations: $e');
      print('ChatService: Stack trace: $stackTrace');
      return [];
    }
  }

  Future<MessageModel?> _getLastMessage(String userId1, String userId2) async {
    try {
      // Query messages where userId1 is sender and userId2 is receiver
      QuerySnapshot query1;
      
      try {
        query1 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId1)
            .where('receiverId', isEqualTo: userId2)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
      } catch (e) {
        // If orderBy fails, try without orderBy
        query1 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId1)
            .where('receiverId', isEqualTo: userId2)
            .limit(1)
            .get();
      }

      // Query messages where userId2 is sender and userId1 is receiver
      QuerySnapshot query2;
      
      try {
        query2 = await FirebaseFirestore.instance
        .collection('messages')
            .where('senderId', isEqualTo: userId2)
            .where('receiverId', isEqualTo: userId1)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
      } catch (e) {
        // If orderBy fails, try without orderBy
        query2 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId2)
            .where('receiverId', isEqualTo: userId1)
            .limit(1)
            .get();
      }

      // Collect all messages
      final allMessages = <MessageModel>[];

      // Process query1 messages (userId1 -> userId2)
      for (final doc in query1.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null || data.isEmpty) continue;
          final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
          if (messageId.isEmpty) continue;
          final messageData = Map<String, dynamic>.from(data);
          messageData['id'] = messageId;
          allMessages.add(MessageModel.fromMap(messageData));
        } catch (e) {
          // Silently handle errors
        }
      }

      // Process query2 messages (userId2 -> userId1)
      for (final doc in query2.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null || data.isEmpty) continue;
          final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
          if (messageId.isEmpty) continue;
          final messageData = Map<String, dynamic>.from(data);
          messageData['id'] = messageId;
          allMessages.add(MessageModel.fromMap(messageData));
        } catch (e) {
          // Silently handle errors
        }
      }

      // Also query for PLACEHOLDER_OWNER_ID and resolve if userId2 is the owner
      try {
        final placeholderQuery1 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId1)
            .where('receiverId', isEqualTo: 'PLACEHOLDER_OWNER_ID')
            .get();
        
        for (final doc in placeholderQuery1.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data.isEmpty) continue;
            final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
            if (messageId.isEmpty) continue;
            final messageData = Map<String, dynamic>.from(data);
            messageData['id'] = messageId;
            final message = MessageModel.fromMap(messageData);
            
            // If roomId exists, check if room or post owner matches userId2
            if (message.roomId != null) {
              try {
                String? ownerId;
                
                // First try to get owner from room
                final room = await _firestoreService.getRoom(message.roomId!);
                if (room != null && room.ownerId.isNotEmpty && room.ownerId != 'PLACEHOLDER_OWNER_ID') {
                  ownerId = room.ownerId;
                } else {
                  // If room.ownerId is still PLACEHOLDER_OWNER_ID, try to get from post
                  final posts = await FirebaseFirestore.instance
                      .collection('posts')
                      .where('roomId', isEqualTo: message.roomId!)
                      .limit(1)
                      .get();
                  
                  if (posts.docs.isNotEmpty) {
                    final postData = posts.docs.first.data();
                    ownerId = postData['ownerId'] as String?;
                  }
                }
                
                if (ownerId != null && ownerId == userId2) {
                  allMessages.add(message);
                }
              } catch (e) {
                // Silently handle errors
              }
            }
          } catch (e) {
            // Silently handle errors
          }
        }

        final placeholderQuery2 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: 'PLACEHOLDER_OWNER_ID')
            .where('receiverId', isEqualTo: userId1)
            .get();
        
        for (final doc in placeholderQuery2.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data.isEmpty) continue;
            final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
            if (messageId.isEmpty) continue;
            final messageData = Map<String, dynamic>.from(data);
            messageData['id'] = messageId;
            final message = MessageModel.fromMap(messageData);
            
            // If roomId exists, check if room or post owner matches userId2
            if (message.roomId != null) {
              try {
                String? ownerId;
                
                // First try to get owner from room
                final room = await _firestoreService.getRoom(message.roomId!);
                if (room != null && room.ownerId.isNotEmpty && room.ownerId != 'PLACEHOLDER_OWNER_ID') {
                  ownerId = room.ownerId;
                } else {
                  // If room.ownerId is still PLACEHOLDER_OWNER_ID, try to get from post
                  final posts = await FirebaseFirestore.instance
                      .collection('posts')
                      .where('roomId', isEqualTo: message.roomId!)
                      .limit(1)
                      .get();
                  
                  if (posts.docs.isNotEmpty) {
                    final postData = posts.docs.first.data();
                    ownerId = postData['ownerId'] as String?;
                  }
                }
                
                if (ownerId != null && ownerId == userId2) {
                  allMessages.add(message);
                }
              } catch (e) {
                // Silently handle errors
              }
            }
          } catch (e) {
            // Silently handle errors
          }
        }
      } catch (e) {
        // Silently handle errors
      }

      // Return the most recent message
      if (allMessages.isEmpty) return null;
      
      allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allMessages.first;
    } catch (e) {
      // If orderBy fails, try without orderBy and sort in memory
      try {
        final query1 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId1)
            .where('receiverId', isEqualTo: userId2)
            .get();

        final query2 = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId2)
            .where('receiverId', isEqualTo: userId1)
            .get();

        final allMessages = <MessageModel>[];
        
        for (var doc in query1.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data.isEmpty) continue;
            final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
            if (messageId.isEmpty) continue;
            final messageData = Map<String, dynamic>.from(data);
            messageData['id'] = messageId;
            allMessages.add(MessageModel.fromMap(messageData));
          } catch (e) {
            // Silently handle errors
          }
        }
        
        for (var doc in query2.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data.isEmpty) continue;
            final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
            if (messageId.isEmpty) continue;
            final messageData = Map<String, dynamic>.from(data);
            messageData['id'] = messageId;
            allMessages.add(MessageModel.fromMap(messageData));
          } catch (e) {
            // Silently handle errors
          }
        }

        if (allMessages.isEmpty) return null;

        // Sort by createdAt and return the most recent
        allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return allMessages.first;
      } catch (e2) {
        return null;
      }
    }
  }

  Future<int> _getUnreadCount(String userId1, String userId2) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: userId2)
        .where('receiverId', isEqualTo: userId1)
        .where('isRead', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }
}

