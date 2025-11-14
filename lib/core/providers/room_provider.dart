import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../../models/room_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final roomsProvider = StreamProvider.family<List<RoomModel>, Map<String, dynamic>>((ref, filters) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getRoomsStream(
    city: filters['city'],
    district: filters['district'],
    minPrice: filters['minPrice'],
    maxPrice: filters['maxPrice'],
    minArea: filters['minArea'],
    maxArea: filters['maxArea'],
    roomType: filters['roomType'],
    allowRoommate: filters['allowRoommate'],
    status: filters['status'] ?? 'approved',
    searchQuery: filters['search'],
  );
});

final roomDetailProvider = FutureProvider.family<RoomModel?, String>((ref, roomId) async {
  final service = ref.watch(firestoreServiceProvider);
  return await service.getRoom(roomId);
});

