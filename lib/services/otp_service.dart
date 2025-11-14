import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/otp_model.dart';

class OTPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // SMTP Configuration - Gmail SMTP
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String smtpUsername = 'truongzxs@gmail.com';
  static const String smtpPassword = 'rovg rwkr ubur iego';

  // Tạo OTP 6 chữ số
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Tạo và lưu OTP vào Firestore
  Future<OTPModel> createOTP(String email, String purpose) async {
    // Normalize email - lowercase và trim
    final normalizedEmail = email.trim().toLowerCase();
    
    // Đánh dấu tất cả OTP cũ của cùng email + purpose là đã dùng
    await _invalidateOldOTPs(normalizedEmail, purpose);
    
    final code = _generateOTP();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10)); // OTP hết hạn sau 10 phút

    final otp = OTPModel(
      id: _firestore.collection('otps').doc().id,
      email: normalizedEmail,
      code: code,
      createdAt: now,
      expiresAt: expiresAt,
      isUsed: false,
      purpose: purpose,
    );

    // Lưu vào Firestore
    await _firestore.collection('otps').doc(otp.id).set(otp.toMap());

    print('✅ Created new OTP: $code for email: $normalizedEmail, purpose: $purpose');

    // Gửi email
    await _sendOTPEmail(email, code, purpose);

    return otp;
  }

  // Đánh dấu tất cả OTP cũ là đã dùng hoặc xóa chúng
  Future<void> _invalidateOldOTPs(String email, String purpose) async {
    try {
      final query = await _firestore
          .collection('otps')
          .where('email', isEqualTo: email)
          .where('purpose', isEqualTo: purpose)
          .where('isUsed', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) {
        print('📋 No old OTPs to invalidate for email: $email, purpose: $purpose');
        return;
      }

      print('🗑️ Invalidating ${query.docs.length} old OTP(s) for email: $email, purpose: $purpose');

      // Option 1: Đánh dấu là đã dùng (giữ lại để audit)
      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'isUsed': true});
      }
      await batch.commit();

      // Option 2: Xóa hoàn toàn (uncomment nếu muốn xóa thay vì đánh dấu)
      // final deleteBatch = _firestore.batch();
      // for (var doc in query.docs) {
      //   deleteBatch.delete(doc.reference);
      // }
      // await deleteBatch.commit();

      print('✅ Invalidated ${query.docs.length} old OTP(s)');
    } catch (e) {
      print('⚠️ Error invalidating old OTPs: $e');
      // Không throw error để không ảnh hưởng đến việc tạo OTP mới
    }
  }

  // Gửi OTP qua email SMTP
  Future<void> _sendOTPEmail(String email, String code, String purpose) async {
    try {
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: smtpUsername,
        password: smtpPassword.replaceAll(' ', ''), // Loại bỏ khoảng trắng nếu có
        ssl: false,
        allowInsecure: true,
      );

      final purposeText = purpose == 'register' 
          ? 'đăng ký tài khoản' 
          : 'đặt lại mật khẩu';

      final message = Message()
        ..from = Address(smtpUsername, 'Find Roommate App')
        ..recipients.add(email)
        ..subject = 'Mã OTP $purposeText - Find Roommate App'
        ..html = '''
          <h2>Mã OTP của bạn</h2>
          <p>Xin chào,</p>
          <p>Bạn đang thực hiện $purposeText. Mã OTP của bạn là:</p>
          <h1 style="color: #009688; font-size: 32px; letter-spacing: 8px;">$code</h1>
          <p>Mã này có hiệu lực trong <strong>10 phút</strong>.</p>
          <p>Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email này.</p>
          <p>Trân trọng,<br>Find Roommate App</p>
        ''';

      await send(message, smtpServer);
      print('✅ OTP email đã được gửi đến $email');
    } catch (e) {
      print('❌ Lỗi gửi email OTP: $e');
      throw Exception('Không thể gửi email OTP: $e');
    }
  }

  // Xác thực OTP
  Future<bool> verifyOTP(String email, String code, String purpose) async {
    try {
      // Normalize inputs - trim và remove spaces
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedCode = code.trim().replaceAll(RegExp(r'[^0-9]'), '');
      
      print('🔍 OTP Service - Email: $normalizedEmail, Code: $normalizedCode, Purpose: $purpose');
      
      if (normalizedCode.length != 6) {
        print('❌ Invalid code length: ${normalizedCode.length}');
        return false;
      }

      QueryDocumentSnapshot? doc;
      
      try {
        // Try with orderBy first
        final query = await _firestore
            .collection('otps')
            .where('email', isEqualTo: normalizedEmail)
            .where('purpose', isEqualTo: purpose)
            .where('isUsed', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      } catch (e) {
        print('⚠️ Query with orderBy failed, trying without orderBy: $e');
        // Fallback: query without orderBy and sort in memory
        final tempQuery = await _firestore
            .collection('otps')
            .where('email', isEqualTo: normalizedEmail)
            .where('purpose', isEqualTo: purpose)
            .where('isUsed', isEqualTo: false)
            .get();
        
        if (tempQuery.docs.isNotEmpty) {
          // Sort by createdAt in memory
          final sortedDocs = tempQuery.docs.toList();
          sortedDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['createdAt'] != null 
                ? DateTime.parse(aData['createdAt']) 
                : DateTime(1970);
            final bDate = bData['createdAt'] != null 
                ? DateTime.parse(bData['createdAt']) 
                : DateTime(1970);
            return bDate.compareTo(aDate); // descending
          });
          
          doc = sortedDocs.first;
        }
      }

      if (doc == null) {
        print('❌ No OTP found for email: $normalizedEmail, purpose: $purpose');
        // Debug: Check if there are any OTPs for this email
        final allOtps = await _firestore
            .collection('otps')
            .where('email', isEqualTo: normalizedEmail)
            .limit(5)
            .get();
        print('📋 All OTPs for email $normalizedEmail: ${allOtps.docs.map((d) => d.data()).toList()}');
        return false;
      }
      final otpData = doc.data() as Map<String, dynamic>;
      print('📄 OTP Data from Firestore: $otpData');
      print('📄 Raw code from Firestore: "${otpData['code']}" (type: ${otpData['code']?.runtimeType})');
      
      final otp = OTPModel.fromMap(otpData);

      print('🔍 OTP from DB - Code: "${otp.code}" (length: ${otp.code.length}, bytes: ${otp.code.codeUnits})');
      print('🔍 OTP from DB - IsValid: ${otp.isValid}, ExpiresAt: ${otp.expiresAt}');
      print('🔍 OTP from DB - IsUsed: ${otp.isUsed}, CreatedAt: ${otp.createdAt}');

      if (!otp.isValid) {
        print('❌ OTP is expired or invalid');
        return false;
      }

      // So sánh code (normalize cả hai)
      final dbCode = otp.code.trim().replaceAll(RegExp(r'[^0-9]'), '');
      print('🔍 Comparing codes:');
      print('   DB Code: "$dbCode" (length: ${dbCode.length}, bytes: ${dbCode.codeUnits})');
      print('   Input Code: "$normalizedCode" (length: ${normalizedCode.length}, bytes: ${normalizedCode.codeUnits})');
      print('   Are equal: ${dbCode == normalizedCode}');
      
      // Debug: So sánh từng ký tự
      if (dbCode.length == normalizedCode.length) {
        for (int i = 0; i < dbCode.length; i++) {
          final dbChar = dbCode[i];
          final inputChar = normalizedCode[i];
          if (dbChar != inputChar) {
            print('   ❌ Character mismatch at index $i: DB="$dbChar" (${dbChar.codeUnitAt(0)}) vs Input="$inputChar" (${inputChar.codeUnitAt(0)})');
          }
        }
      }
      
      if (dbCode != normalizedCode) {
        print('❌ Code mismatch - DB: "$dbCode", Input: "$normalizedCode"');
        return false;
      }

      // Đánh dấu OTP đã sử dụng
      await _firestore.collection('otps').doc(otp.id).update({
        'isUsed': true,
      });

      print('✅ OTP verified successfully');
      return true;
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return false;
    }
  }

  // Xóa các OTP đã hết hạn (cleanup job)
  Future<void> cleanupExpiredOTPs() async {
    final now = DateTime.now();
    final query = await _firestore
        .collection('otps')
        .where('expiresAt', isLessThan: now.toIso8601String())
        .get();

    final batch = _firestore.batch();
    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

