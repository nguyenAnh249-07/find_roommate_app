import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/post_model.dart';
import '../models/roommate_request_model.dart';
import '../models/rental_request_model.dart';
import '../models/contract_model.dart';
import '../models/payment_model.dart';
import '../models/message_model.dart';
import '../models/category_model.dart';
import '../models/owner_request_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== ROOMS ==========
  // Lấy tất cả phòng trọ (dành cho admin)
  Stream<List<RoomModel>> getAllRoomsStream() {
    try {
      return _firestore
          .collection('rooms')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        try {
          // Use a Map to remove duplicates by room ID
          final roomsMap = <String, RoomModel>{};
          
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null || data.isEmpty) continue;
              
              // Use doc.id as the primary ID, fallback to room.id if doc.id is not set
              final roomId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
              if (roomId.isEmpty) {
                print('Warning: Room document ${doc.id} has no ID');
                continue;
              }
              
              // Update data to use doc.id if different
              final roomData = Map<String, dynamic>.from(data);
              roomData['id'] = roomId;
              
              final room = RoomModel.fromMap(roomData);
              // Use room.id as key to ensure uniqueness
              // If a room with the same ID already exists, keep the first one
              if (!roomsMap.containsKey(room.id)) {
                roomsMap[room.id] = room;
              } else {
                print('Warning: Duplicate room ID found: ${room.id}, document ID: ${doc.id}');
              }
            } catch (e) {
              print('Error parsing room ${doc.id}: $e');
              continue;
            }
          }
          
          // Convert map values to list and sort
          final rooms = roomsMap.values.toList();
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return rooms;
        } catch (e) {
          print('Error in getAllRoomsStream: $e');
          return <RoomModel>[];
        }
      }).handleError((error) {
        print('Error in getAllRoomsStream: $error');
        // Fallback: query without orderBy if index doesn't exist
        return _firestore
            .collection('rooms')
            .snapshots()
            .map((snapshot) {
          try {
            // Use a Map to remove duplicates by room ID
            final roomsMap = <String, RoomModel>{};
            
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) continue;
                
                // Use doc.id as the primary ID, fallback to room.id if doc.id is not set
                final roomId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
                if (roomId.isEmpty) {
                  print('Warning: Room document ${doc.id} has no ID');
                  continue;
                }
                
                // Update data to use doc.id if different
                final roomData = Map<String, dynamic>.from(data);
                roomData['id'] = roomId;
                
                final room = RoomModel.fromMap(roomData);
                // Use room.id as key to ensure uniqueness
                if (!roomsMap.containsKey(room.id)) {
                  roomsMap[room.id] = room;
                } else {
                  print('Warning: Duplicate room ID found: ${room.id}, document ID: ${doc.id}');
                }
              } catch (e) {
                print('Error parsing room ${doc.id}: $e');
                continue;
              }
            }
            
            // Convert map values to list and sort
            final rooms = roomsMap.values.toList();
            rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            return rooms;
          } catch (e) {
            print('Error in getAllRoomsStream fallback: $e');
            return <RoomModel>[];
          }
        });
      });
    } catch (e) {
      print('Error setting up getAllRoomsStream: $e');
      // Fallback: query without orderBy
      return _firestore
          .collection('rooms')
          .snapshots()
          .map((snapshot) {
        try {
          // Use a Map to remove duplicates by room ID
          final roomsMap = <String, RoomModel>{};
          
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null || data.isEmpty) continue;
              
              final room = RoomModel.fromMap(data);
              // Use room.id as key to ensure uniqueness
              if (!roomsMap.containsKey(room.id)) {
                roomsMap[room.id] = room;
              } else {
                print('Warning: Duplicate room ID found: ${room.id}');
              }
            } catch (e) {
              print('Error parsing room ${doc.id}: $e');
              continue;
            }
          }
          
          // Convert map values to list and sort
          final rooms = roomsMap.values.toList();
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return rooms;
        } catch (e) {
          print('Error in getAllRoomsStream fallback: $e');
          return <RoomModel>[];
        }
      });
    }
  }

  // Lấy danh sách phòng với filter
  Stream<List<RoomModel>> getRoomsStream({
    String? city,
    String? district,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    String? roomType,
    bool? allowRoommate,
    String? status,
    String? searchQuery,
  }) {
    Query query = _firestore.collection('rooms');
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    if (district != null) {
      query = query.where('district', isEqualTo: district);
    }
    if (roomType != null) {
      query = query.where('roomType', isEqualTo: roomType);
    }
    if (allowRoommate != null) {
      query = query.where('allowRoommate', isEqualTo: allowRoommate);
    }

    try {
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
          .map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null || data.isEmpty) return null;
                  return RoomModel.fromMap(data);
                } catch (e) {
                  print('Error parsing room ${doc.id}: $e');
                  return null;
                }
              })
            .where((room) {
                if (room == null) return false;
                // Price filter
              if (minPrice != null && room.price < minPrice) return false;
              if (maxPrice != null && room.price > maxPrice) return false;
                // Area filter
              if (minArea != null && room.area < minArea) return false;
              if (maxArea != null && room.area > maxArea) return false;
                // Search query filter
                if (searchQuery != null && searchQuery.isNotEmpty) {
                  final query = searchQuery.toLowerCase();
                  final matchesTitle = room.title.toLowerCase().contains(query);
                  final matchesDescription = room.description.toLowerCase().contains(query);
                  final matchesAddress = room.address.toLowerCase().contains(query);
                  final matchesDistrict = room.district.toLowerCase().contains(query);
                  final matchesCity = room.city.toLowerCase().contains(query);
                  if (!matchesTitle && !matchesDescription && !matchesAddress && !matchesDistrict && !matchesCity) {
                    return false;
                  }
                }
              return true;
            })
              .cast<RoomModel>()
              .toList();
        } catch (e) {
          print('Error in getRoomsStream: $e');
          return <RoomModel>[];
        }
      }).handleError((error) {
        print('Error in getRoomsStream: $error');
        // Try without orderBy if index doesn't exist
        try {
          return _firestore
              .collection('rooms')
              .snapshots()
              .map((snapshot) {
            try {
              final rooms = snapshot.docs
                  .map((doc) {
                    try {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null || data.isEmpty) return null;
                      final room = RoomModel.fromMap(data);
                      // Apply filters
                      if (status != null && room.status != status) return null;
                      if (city != null && room.city != city) return null;
                      if (district != null && room.district != district) return null;
                      if (roomType != null && room.roomType != roomType) return null;
                      if (allowRoommate != null && room.allowRoommate != allowRoommate) return null;
                  if (minPrice != null && room.price < minPrice) return null;
                  if (maxPrice != null && room.price > maxPrice) return null;
                  if (minArea != null && room.area < minArea) return null;
                  if (maxArea != null && room.area > maxArea) return null;
                  // Search query filter
                  if (searchQuery != null && searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    final matchesTitle = room.title.toLowerCase().contains(query);
                    final matchesDescription = room.description.toLowerCase().contains(query);
                    final matchesAddress = room.address.toLowerCase().contains(query);
                    final matchesDistrict = room.district.toLowerCase().contains(query);
                    final matchesCity = room.city.toLowerCase().contains(query);
                    if (!matchesTitle && !matchesDescription && !matchesAddress && !matchesDistrict && !matchesCity) {
                      return null;
                    }
                  }
                  return room;
                } catch (e) {
                  print('Error parsing room ${doc.id}: $e');
                  return null;
                }
              })
              .where((room) => room != null)
              .cast<RoomModel>()
              .toList();
          // Sort in memory
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rooms;
            } catch (e) {
              print('Error in getRoomsStream fallback: $e');
              return <RoomModel>[];
            }
          });
        } catch (e) {
          return Stream.value(<RoomModel>[]);
        }
      });
    } catch (e) {
      print('Error setting up getRoomsStream query: $e');
      // Fallback: query without orderBy
      return _firestore
          .collection('rooms')
          .snapshots()
          .map((snapshot) {
        try {
          final rooms = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null || data.isEmpty) return null;
                  final room = RoomModel.fromMap(data);
                  // Apply filters
                  if (status != null && room.status != status) return null;
                  if (city != null && room.city != city) return null;
                  if (district != null && room.district != district) return null;
                  if (roomType != null && room.roomType != roomType) return null;
                  if (allowRoommate != null && room.allowRoommate != allowRoommate) return null;
                  if (minPrice != null && room.price < minPrice) return null;
                  if (maxPrice != null && room.price > maxPrice) return null;
                  if (minArea != null && room.area < minArea) return null;
                  if (maxArea != null && room.area > maxArea) return null;
                  // Search query filter
                  if (searchQuery != null && searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    final matchesTitle = room.title.toLowerCase().contains(query);
                    final matchesDescription = room.description.toLowerCase().contains(query);
                    final matchesAddress = room.address.toLowerCase().contains(query);
                    final matchesDistrict = room.district.toLowerCase().contains(query);
                    final matchesCity = room.city.toLowerCase().contains(query);
                    if (!matchesTitle && !matchesDescription && !matchesAddress && !matchesDistrict && !matchesCity) {
                      return null;
                    }
                  }
                  return room;
                } catch (e) {
                  print('Error parsing room ${doc.id}: $e');
                  return null;
                }
              })
              .where((room) => room != null)
              .cast<RoomModel>()
              .toList();
          // Sort in memory
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rooms;
        } catch (e) {
          print('Error in getRoomsStream fallback: $e');
          return <RoomModel>[];
        }
      });
    }
  }

  // Lấy chi tiết phòng
  Future<RoomModel?> getRoom(String roomId) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    return doc.exists ? RoomModel.fromMap(doc.data()! as Map<String, dynamic>) : null;
  }

  // Tạo phòng mới
  Future<void> createRoom(RoomModel room) async {
    await _firestore.collection('rooms').doc(room.id).set(room.toMap());
  }

  // Cập nhật phòng
  Future<void> updateRoom(RoomModel room) async {
    await _firestore.collection('rooms').doc(room.id).update({
      ...room.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Xóa phòng
  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).delete();
  }

  // ========== POSTS ==========
  Stream<List<PostModel>> getPostsStream({
    String? status,
    String? roomId,
    String? ownerId,
  }) {
    Query query = _firestore.collection('posts');
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (roomId != null) {
      query = query.where('roomId', isEqualTo: roomId);
    }
    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) return null;
                return PostModel.fromMap(data);
              } catch (e) {
                print('Error parsing post ${doc.id}: $e');
                return null;
              }
            })
            .where((post) => post != null)
            .cast<PostModel>()
            .toList();
      } catch (e) {
        print('Error in getPostsStream: $e');
        return <PostModel>[];
      }
    }).handleError((error) {
      print('Error in getPostsStream: $error');
    });
  }

  Future<void> createPost(PostModel post) async {
    await _firestore.collection('posts').doc(post.id).set(post.toMap());
  }

  Future<void> updatePostStatus(
    String postId,
    String status, {
    String? adminNote,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (adminNote != null) {
      updateData['adminNote'] = adminNote;
    }
    await _firestore.collection('posts').doc(postId).update(updateData);
  }

  // ========== ROOMMATE REQUESTS ==========
  Stream<List<RoommateRequestModel>> getRoommateRequestsStream({
    String? userId,
    String? ownerId,
    String? roomId,
    String? status,
  }) {
    Query query = _firestore.collection('roommate_requests');
    
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    if (roomId != null) {
      query = query.where('roomId', isEqualTo: roomId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RoommateRequestModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> createRoommateRequest(RoommateRequestModel request) async {
    await _firestore.collection('roommate_requests').doc(request.id).set(request.toMap());
  }

  Future<void> updateRoommateRequestStatus(
    String requestId,
    String status,
  ) async {
    await _firestore.collection('roommate_requests').doc(requestId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ========== RENTAL REQUESTS ==========
  Stream<List<RentalRequestModel>> getRentalRequestsStream({
    String? userId,
    String? ownerId,
    String? roomId,
    String? status,
  }) {
    Query query = _firestore.collection('rental_requests');
    
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    if (roomId != null) {
      query = query.where('roomId', isEqualTo: roomId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) {
                  print('Warning: Rental request document ${doc.id} has null or empty data');
                  return null;
                }
                // Ensure id is set from doc.id if not present in data
                final requestData = Map<String, dynamic>.from(data);
                if (!requestData.containsKey('id') || requestData['id'] == null || requestData['id'].toString().isEmpty) {
                  requestData['id'] = doc.id;
                }
                return RentalRequestModel.fromMap(requestData);
              } catch (e) {
                print('Error parsing rental request ${doc.id}: $e');
                return null;
              }
            })
            .where((request) => request != null)
            .cast<RentalRequestModel>()
            .toList();
      } catch (e) {
        print('Error in getRentalRequestsStream: $e');
        return <RentalRequestModel>[];
      }
    }).handleError((error) {
      print('Error in getRentalRequestsStream: $error');
      // Try without orderBy if index doesn't exist
      try {
        Query fallbackQuery = _firestore.collection('rental_requests');
        if (userId != null) {
          fallbackQuery = fallbackQuery.where('userId', isEqualTo: userId);
        }
        if (ownerId != null) {
          fallbackQuery = fallbackQuery.where('ownerId', isEqualTo: ownerId);
        }
        if (roomId != null) {
          fallbackQuery = fallbackQuery.where('roomId', isEqualTo: roomId);
        }
        if (status != null) {
          fallbackQuery = fallbackQuery.where('status', isEqualTo: status);
        }
        return fallbackQuery.snapshots().map((snapshot) {
          try {
            final requests = snapshot.docs
                .map((doc) {
                  try {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null || data.isEmpty) return null;
                    final requestData = Map<String, dynamic>.from(data);
                    if (!requestData.containsKey('id') || requestData['id'] == null || requestData['id'].toString().isEmpty) {
                      requestData['id'] = doc.id;
                    }
                    final request = RentalRequestModel.fromMap(requestData);
                    // Apply filters in memory
                    if (status != null && request.status != status) return null;
                    if (userId != null && request.userId != userId) return null;
                    if (ownerId != null && request.ownerId != ownerId) return null;
                    if (roomId != null && request.roomId != roomId) return null;
                    return request;
                  } catch (e) {
                    print('Error parsing rental request ${doc.id} in fallback: $e');
                    return null;
                  }
                })
                .where((request) => request != null)
                .cast<RentalRequestModel>()
                .toList();
            // Sort in memory
            requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return requests;
          } catch (e) {
            print('Error in getRentalRequestsStream fallback: $e');
            return <RentalRequestModel>[];
          }
        });
      } catch (e) {
        return Stream.value(<RentalRequestModel>[]);
      }
    });
  }

  Future<void> createRentalRequest(RentalRequestModel request) async {
    await _firestore.collection('rental_requests').doc(request.id).set(request.toMap());
  }

  Future<void> updateRentalRequestStatus(
    String requestId,
    String status,
  ) async {
    await _firestore.collection('rental_requests').doc(requestId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ========== CONTRACTS ==========
  Stream<List<ContractModel>> getContractsStream({
    String? ownerId,
    String? tenantId,
    String? roomId,
  }) {
    Query query = _firestore.collection('contracts');
    
    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    if (tenantId != null) {
      query = query.where('tenantIds', arrayContains: tenantId);
    }
    if (roomId != null) {
      query = query.where('roomId', isEqualTo: roomId);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) return null;
                return ContractModel.fromMap(data);
              } catch (e) {
                print('Error parsing contract ${doc.id}: $e');
                return null;
              }
            })
            .where((contract) => contract != null)
            .cast<ContractModel>()
            .toList();
      } catch (e) {
        print('Error in getContractsStream: $e');
        return <ContractModel>[];
      }
    }).handleError((error) {
      print('Error in getContractsStream: $error');
    });
  }

  Future<void> createContract(ContractModel contract) async {
    await _firestore.collection('contracts').doc(contract.id).set(contract.toMap());
  }

  // ========== PAYMENTS ==========
  Stream<List<PaymentModel>> getPaymentsStream({
    String? ownerId,
    String? tenantId,
    String? contractId,
    String? status,
  }) {
    Query query = _firestore.collection('payments');
    
    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    if (tenantId != null) {
      query = query.where('tenantId', isEqualTo: tenantId);
    }
    if (contractId != null) {
      query = query.where('contractId', isEqualTo: contractId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) return null;
                return PaymentModel.fromMap(data);
              } catch (e) {
                print('Error parsing payment ${doc.id}: $e');
                return null;
              }
            })
            .where((payment) => payment != null)
            .cast<PaymentModel>()
            .toList();
      } catch (e) {
        print('Error in getPaymentsStream: $e');
        return <PaymentModel>[];
      }
    }).handleError((error) {
      print('Error in getPaymentsStream: $error');
    });
  }

  Future<void> createPayment(PaymentModel payment) async {
    await _firestore.collection('payments').doc(payment.id).set(payment.toMap());
  }

  Future<void> updatePaymentStatus(String paymentId, String status) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': status,
      'paidDate': status == 'paid' ? DateTime.now().toIso8601String() : null,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ========== MESSAGES ==========
  Stream<List<MessageModel>> getMessagesStream(String userId1, String userId2) {
    // Combine both streams using StreamController
    final controller = StreamController<List<MessageModel>>();
    final allMessages = <String, MessageModel>{}; // Use Map to avoid duplicates
    
    void updateMessages() {
      final sortedMessages = allMessages.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      controller.add(sortedMessages);
    }
    
    StreamSubscription? sub1;
    StreamSubscription? sub2;
    
    // Try with orderBy first
    try {
      final stream1 = _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId1)
          .where('receiverId', isEqualTo: userId2)
          .orderBy('createdAt', descending: false)
          .snapshots();
      
      final stream2 = _firestore
        .collection('messages')
          .where('senderId', isEqualTo: userId2)
          .where('receiverId', isEqualTo: userId1)
        .orderBy('createdAt', descending: false)
          .snapshots();
      
      sub1 = stream1.listen((snapshot) {
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data.isEmpty) continue;
            
            // Use doc.id as the primary ID, fallback to message.id if doc.id is not set
            final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
            if (messageId.isEmpty) {
              print('Warning: Message document ${doc.id} has no ID');
              continue;
            }
            
            // Update data to use doc.id if different
            final messageData = Map<String, dynamic>.from(data);
            messageData['id'] = messageId;
            
            final message = MessageModel.fromMap(messageData);
            
            // Only add if senderId and receiverId match (to avoid duplicates)
            if ((message.senderId == userId1 && message.receiverId == userId2) ||
                (message.senderId == userId2 && message.receiverId == userId1)) {
              allMessages[message.id] = message;
            }
          } catch (e) {
            print('Error parsing message ${doc.id}: $e');
            print('Message data: ${doc.data()}');
          }
        }
        updateMessages();
      }, onError: (error) {
        print('Error in stream1: $error');
        // Try query without orderBy
        try {
          _firestore
              .collection('messages')
              .where('senderId', isEqualTo: userId1)
              .where('receiverId', isEqualTo: userId2)
              .snapshots()
              .listen((snapshot) {
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) continue;
                final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
                if (messageId.isEmpty) continue;
                final messageData = Map<String, dynamic>.from(data);
                messageData['id'] = messageId;
                final message = MessageModel.fromMap(messageData);
                if ((message.senderId == userId1 && message.receiverId == userId2) ||
                    (message.senderId == userId2 && message.receiverId == userId1)) {
                  allMessages[message.id] = message;
                }
              } catch (e) {
                print('Error parsing message in fallback: $e');
              }
            }
            updateMessages();
          });
        } catch (e) {
          print('Error setting up fallback stream1: $e');
        }
      });
      
      sub2 = stream2.listen((snapshot) {
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data.isEmpty) continue;
            
            // Use doc.id as the primary ID
            final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
            if (messageId.isEmpty) {
              print('Warning: Message document ${doc.id} has no ID');
              continue;
            }
            
            // Update data to use doc.id
            final messageData = Map<String, dynamic>.from(data);
            messageData['id'] = messageId;
            
            final message = MessageModel.fromMap(messageData);
            
            // Only add if senderId and receiverId match
            if ((message.senderId == userId1 && message.receiverId == userId2) ||
                (message.senderId == userId2 && message.receiverId == userId1)) {
              allMessages[message.id] = message;
            }
          } catch (e) {
            print('Error parsing message ${doc.id}: $e');
            print('Message data: ${doc.data()}');
          }
        }
        updateMessages();
      }, onError: (error) {
        print('Error in stream2: $error');
        // Try query without orderBy
        try {
          _firestore
              .collection('messages')
              .where('senderId', isEqualTo: userId2)
              .where('receiverId', isEqualTo: userId1)
        .snapshots()
              .listen((snapshot) {
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) continue;
                final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
                if (messageId.isEmpty) continue;
                final messageData = Map<String, dynamic>.from(data);
                messageData['id'] = messageId;
                final message = MessageModel.fromMap(messageData);
                if ((message.senderId == userId1 && message.receiverId == userId2) ||
                    (message.senderId == userId2 && message.receiverId == userId1)) {
                  allMessages[message.id] = message;
                }
              } catch (e) {
                print('Error parsing message in fallback: $e');
              }
            }
            updateMessages();
          });
        } catch (e) {
          print('Error setting up fallback stream2: $e');
        }
      });
    } catch (e) {
      print('Error setting up message streams: $e');
      // If orderBy fails, try without orderBy
      try {
        final stream1Fallback = _firestore
            .collection('messages')
            .where('senderId', isEqualTo: userId1)
            .where('receiverId', isEqualTo: userId2)
            .snapshots();
        
        final stream2Fallback = _firestore
            .collection('messages')
            .where('senderId', isEqualTo: userId2)
            .where('receiverId', isEqualTo: userId1)
            .snapshots();
        
        sub1 = stream1Fallback.listen((snapshot) {
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null || data.isEmpty) continue;
              final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
              if (messageId.isEmpty) continue;
              final messageData = Map<String, dynamic>.from(data);
              messageData['id'] = messageId;
              final message = MessageModel.fromMap(messageData);
              if ((message.senderId == userId1 && message.receiverId == userId2) ||
                  (message.senderId == userId2 && message.receiverId == userId1)) {
                allMessages[message.id] = message;
              }
            } catch (e) {
              print('Error parsing message in fallback setup: $e');
            }
          }
          updateMessages();
        });
        
        sub2 = stream2Fallback.listen((snapshot) {
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null || data.isEmpty) continue;
              final messageId = doc.id.isNotEmpty ? doc.id : (data['id'] as String? ?? '');
              if (messageId.isEmpty) continue;
              final messageData = Map<String, dynamic>.from(data);
              messageData['id'] = messageId;
              final message = MessageModel.fromMap(messageData);
              if ((message.senderId == userId1 && message.receiverId == userId2) ||
                  (message.senderId == userId2 && message.receiverId == userId1)) {
                allMessages[message.id] = message;
              }
            } catch (e) {
              print('Error parsing message in fallback setup: $e');
            }
          }
          updateMessages();
        });
      } catch (e2) {
        print('Error in fallback setup: $e2');
      }
    }
    
    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };
    
    return controller.stream;
  }

  Future<void> sendMessage(MessageModel message) async {
    await _firestore.collection('messages').doc(message.id).set(message.toMap());
  }

  Future<void> markMessageAsRead(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({
      'isRead': true,
    });
  }

  // Lấy danh sách conversations
  Stream<List<String>> getConversationsStream(String userId) {
    return _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>).receiverId)
            .toSet()
            .toList());
  }

  // ========== CATEGORIES ==========
  Stream<List<CategoryModel>> getCategoriesStream({
    String? type,
    String? status,
  }) {
    Query query = _firestore.collection('categories');
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('name', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> createCategory(CategoryModel category) async {
    await _firestore.collection('categories').doc(category.id).set(category.toMap());
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _firestore.collection('categories').doc(category.id).update({
      ...category.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).delete();
  }

  // ========== SAVED ROOMS (Favorites) ==========
  Future<void> saveRoom(String userId, String roomId) async {
    await _firestore.collection('users').doc(userId).update({
      'savedRooms': FieldValue.arrayUnion([roomId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unsaveRoom(String userId, String roomId) async {
    await _firestore.collection('users').doc(userId).update({
      'savedRooms': FieldValue.arrayRemove([roomId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> isRoomSaved(String userId, String roomId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;
    final userData = userDoc.data() as Map<String, dynamic>?;
    final savedRooms = userData?['savedRooms'] as List<dynamic>?;
    return savedRooms?.contains(roomId) ?? false;
  }

  Stream<List<RoomModel>> getSavedRoomsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userSnapshot) async {
      if (!userSnapshot.exists) return <RoomModel>[];
      final userData = userSnapshot.data() as Map<String, dynamic>?;
      final savedRoomIds = userData?['savedRooms'] as List<dynamic>?;
      
      if (savedRoomIds == null || savedRoomIds.isEmpty) {
        return <RoomModel>[];
      }

      final rooms = <RoomModel>[];
      for (final roomId in savedRoomIds) {
        try {
          final room = await getRoom(roomId.toString());
          if (room != null) {
            rooms.add(room);
          }
        } catch (e) {
          print('Error loading saved room $roomId: $e');
        }
      }
      return rooms;
    });
  }

  // ========== OWNER REQUESTS ==========
  Stream<List<OwnerRequestModel>> getOwnerRequestsStream({
    String? userId,
    String? status,
  }) {
    Query query = _firestore.collection('owner_requests');
    
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) return null;
                return OwnerRequestModel.fromMap(data);
              } catch (e) {
                print('Error parsing owner request ${doc.id}: $e');
                return null;
              }
            })
            .where((request) => request != null)
            .cast<OwnerRequestModel>()
            .toList();
      } catch (e) {
        print('Error in getOwnerRequestsStream: $e');
        return <OwnerRequestModel>[];
      }
    }).handleError((error) {
      print('Error in getOwnerRequestsStream: $error');
    });
  }

  Future<void> createOwnerRequest(OwnerRequestModel request) async {
    await _firestore.collection('owner_requests').doc(request.id).set(request.toMap());
  }

  Future<void> updateOwnerRequestStatus(
    String requestId,
    String status,
    String adminId,
    String? adminNote,
  ) async {
    await _firestore.collection('owner_requests').doc(requestId).update({
      'status': status,
      'adminId': adminId,
      'adminNote': adminNote,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<OwnerRequestModel?> getOwnerRequest(String requestId) async {
    final doc = await _firestore.collection('owner_requests').doc(requestId).get();
    return doc.exists ? OwnerRequestModel.fromMap(doc.data()! as Map<String, dynamic>) : null;
  }

  Future<OwnerRequestModel?> getOwnerRequestByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('owner_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return OwnerRequestModel.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting owner request by userId: $e');
      return null;
    }
  }
}

