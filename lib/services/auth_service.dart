import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký với email/password
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng nhập
  Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    // Clear all static caches before signing out
    await _clearAllCaches();
    
    // Sign out from Firebase Auth
    await _auth.signOut();
  }

  // Clear all static caches used across the app
  Future<void> _clearAllCaches() async {
    try {
      // Clear ChatService ownerId cache
      // Note: This is a static cache, so we need to access it through reflection or make it accessible
      // For now, we'll handle it in the logout screens directly
      print('AuthService: Clearing caches on logout');
    } catch (e) {
      print('AuthService: Error clearing caches: $e');
    }
  }

  // Đổi mật khẩu
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  // Gửi email đặt lại mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Gửi email xác thực
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Lưu thông tin user vào Firestore
  Future<void> saveUserToFirestore(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  // Lấy thông tin user từ Firestore
  Future<UserModel?> getUserFromFirestore(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()! as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Cập nhật thông tin user
  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).update({
      ...user.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Stream user data
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()! as Map<String, dynamic>) : null);
  }
}

