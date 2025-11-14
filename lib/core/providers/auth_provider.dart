import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Use StreamProvider instead of FutureProvider to automatically refresh when auth state changes
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  
  // Watch auth state changes and map to user data stream
  return authService.authStateChanges.asyncExpand((user) async* {
    if (user == null) {
      yield null;
      return;
    }
    
    // Get user data from Firestore when auth state changes
    try {
      final userModel = await authService.getUserFromFirestore(user.uid);
      yield userModel;
      
      // Also listen to user data changes in Firestore
      yield* authService.getUserStream(user.uid);
    } catch (e) {
      print('Error fetching user data: $e');
      yield null;
    }
  });
});

final userStreamProvider = StreamProvider.family<UserModel?, String>((ref, userId) {
  final authService = ref.watch(authServiceProvider);
  return authService.getUserStream(userId);
});

