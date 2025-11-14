import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/otp_service.dart';
import '../../../models/user_model.dart';
import '../../user/home_screen.dart';
import 'reset_password_screen.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String password;
  final String fullName;
  final String purpose; // 'register' or 'forgot_password'

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    required this.purpose,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState
    extends ConsumerState<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  int _otpExpiryTimer = 600; // 10 minutes in seconds
  Timer? _timer;
  Timer? _expiryTimer;
  bool _hasError = false;
  bool _isSuccess = false;
  late AnimationController _shakeController;
  late AnimationController _successController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startExpiryTimer();
    _setupShakeAnimation();
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.elasticOut,
      ),
    );
    _successOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.easeIn,
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startExpiryTimer() {
    _otpExpiryTimer = 600; // 10 minutes
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_otpExpiryTimer > 0) {
            _otpExpiryTimer--;
          } else {
            timer.cancel();
            // OTP expired
            if (!_isLoading) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    // Clear error state when user starts typing
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }

    // Normal input - single digit
    if (value.length <= 1) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

      // Auto-submit when all fields are filled
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final code = _controllers.map((c) => c.text).join();
        if (code.length == 6 && !_isLoading && mounted) {
          _verifyOTP();
        }
      });
    }
  }

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      final pastedText = clipboardData!.text!;
      final digits = pastedText.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (digits.length >= 6) {
        // Fill all fields with pasted text
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = digits[i];
        }
        _focusNodes[5].unfocus();
        
        // Auto-verify after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isLoading) {
            _verifyOTP();
          }
        });
      } else if (digits.isNotEmpty) {
        // Fill available fields
        for (int i = 0; i < digits.length && i < 6; i++) {
          _controllers[i].text = digits[i];
        }
        final nextIndex = digits.length >= 6 ? 5 : digits.length;
        if (nextIndex < 6) {
          _focusNodes[nextIndex].requestFocus();
        }
      }
    }
  }

  void _clearAllFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _verifyOTP() async {
    // Join và normalize OTP code (trim, remove spaces)
    final rawCode = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .join();
    
    // Remove all non-digit characters to be safe
    final code = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    
    print('🔍 Raw OTP Code from controllers: "$rawCode"');
    print('🔍 Normalized OTP Code: "$code" (length: ${code.length})');
    print('🔍 Controller values: ${_controllers.map((c) => '"${c.text}"').toList()}');
        
    if (code.length != 6) {
      print('❌ Code length is not 6: ${code.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập đủ 6 chữ số (hiện tại: ${code.length})'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final otpService = OTPService();
      print('🔍 Verifying OTP - Email: ${widget.email}, Code: "$code", Purpose: ${widget.purpose}');
      print('🔍 Code bytes: ${code.codeUnits}');
      
      final isValid = await otpService.verifyOTP(
        widget.email.trim(),
        code,
        widget.purpose,
      );

      print('✅ OTP Verification Result: $isValid');

      if (!isValid) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
          
          _shakeController.forward(from: 0).then((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _shakeController.reset();
              }
            });
          });
          
          // Clear fields and refocus first after a delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _clearAllFields();
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Mã OTP không đúng hoặc đã hết hạn. Vui lòng kiểm tra lại.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Show success animation
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
        _successController.forward();
      }

      // Wait for animation then proceed
      await Future.delayed(const Duration(milliseconds: 1500));

      if (widget.purpose == 'register') {
        // Tạo tài khoản
        final authService = ref.read(authServiceProvider);
        final credential = await authService.signUpWithEmail(
          widget.email,
          widget.password,
        );

        if (credential?.user != null) {
          // Tạo user trong Firestore
          final user = UserModel(
            id: credential!.user!.uid,
            email: widget.email,
            emailVerified: true,
            fullName: widget.fullName,
            role: 'user',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: 'active',
          );

          await authService.saveUserToFirestore(user);

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        }
      } else if (widget.purpose == 'forgot_password') {
        // Chuyển sang màn hình đặt lại mật khẩu
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(email: widget.email),
            ),
          );
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

  Future<void> _resendOTP() async {
    if (!mounted) return;
    setState(() => _isResending = true);

    try {
      final otpService = OTPService();
      await otpService.createOTP(widget.email, widget.purpose);

      if (mounted) {
        _startResendTimer();
        _startExpiryTimer(); // Reset expiry timer
        _clearAllFields();
        setState(() {
          _hasError = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã gửi lại mã OTP thành công'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.purpose == 'register') {
              // Go back to register screen
              Navigator.of(context).pop();
            } else {
              // Go back to forgot password screen
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                  const SizedBox(height: 20),
                  // Icon with animation
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title
              Text(
                    'Nhập mã xác thực',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
                  const SizedBox(height: 12),
                  // Description
              Text(
                    'Chúng tôi đã gửi mã OTP đến',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
                  const SizedBox(height: 8),
                  // Email (with selection support)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: SelectableText(
                          widget.email,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // Go back to change email
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Đổi',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // OTP Expiry Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _otpExpiryTimer < 60
                          ? colorScheme.errorContainer.withOpacity(0.3)
                          : colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: _otpExpiryTimer < 60
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mã OTP còn hiệu lực: ${_formatTime(_otpExpiryTimer)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _otpExpiryTimer < 60
                                ? colorScheme.error
                                : colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // OTP Input Fields with shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                        final hasValue = _controllers[index].text.isNotEmpty;
                        final isFocused = _focusNodes[index].hasFocus;
                        
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              left: index == 0 ? 0 : 6,
                              right: index == 5 ? 0 : 6,
                            ),
                            child: GestureDetector(
                              onTap: () => _focusNodes[index].requestFocus(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _hasError
                                      ? colorScheme.errorContainer.withOpacity(0.3)
                                      : isFocused
                                          ? colorScheme.primaryContainer.withOpacity(0.6)
                                          : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _hasError
                                        ? colorScheme.error
                                        : isFocused
                                            ? colorScheme.primary
                                            : hasValue
                                                ? colorScheme.primary.withOpacity(0.4)
                                                : colorScheme.outlineVariant,
                                    width: isFocused || _hasError ? 2 : hasValue ? 1.5 : 1,
                                  ),
                                  boxShadow: isFocused
                                      ? [
                                          BoxShadow(
                                            color: colorScheme.primary.withOpacity(0.25),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                                    cursorColor: colorScheme.primary,
                                    cursorWidth: 2.5,
                                    showCursor: isFocused,
                                    autofocus: index == 0 && !hasValue,
                                    textInputAction: index < 5
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(1),
                                    ],
                                    style: TextStyle(
                                      fontSize: 32,
                        fontWeight: FontWeight.bold,
                                      color: _hasError
                                          ? colorScheme.error
                                          : colorScheme.onSurface,
                                      letterSpacing: 0,
                                      height: 1.0,
                      ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                        counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                    ),
                                    onChanged: (value) {
                                      // Remove any non-digit characters
                                      if (value.isNotEmpty && !RegExp(r'^\d$').hasMatch(value)) {
                                        _controllers[index].clear();
                                        return;
                                      }
                                      _onChanged(index, value);
                                    },
                                    onTap: () {
                                      // Select all when tapped
                                      _controllers[index].selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: _controllers[index].text.length,
                                      );
                                    },
                                    onSubmitted: (value) {
                                      // Move to next field if value entered
                                      if (value.isNotEmpty && index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                    ),
                  );
                }),
                    ),
              ),
              const SizedBox(height: 32),
                  // Paste button
                  TextButton.icon(
                    onPressed: _handlePaste,
                    icon: Icon(Icons.paste_outlined, size: 18),
                    label: const Text('Dán mã OTP'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Error message
                  if (_hasError)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mã OTP không đúng. Vui lòng thử lại.',
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 40),
                  const SizedBox(height: 8),
              // Verify Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              final code = _controllers.map((c) => c.text).join();
                              if (code.length == 6) {
                                _verifyOTP();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Vui lòng nhập đủ 6 chữ số'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                style: ElevatedButton.styleFrom(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                ),
                child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : const Text(
                              'Xác thực',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Resend OTP section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Không nhận được mã? ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_resendTimer > 0)
                        Text(
                          'Gửi lại sau ${_resendTimer}s',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
              TextButton(
                onPressed: _isResending ? null : _resendOTP,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                child: _isResending
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Gửi lại mã',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            // Loading overlay
            if (_isLoading && !_isSuccess)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Đang xác thực...',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Success overlay
            if (_isSuccess)
              AnimatedBuilder(
                animation: _successController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _successOpacityAnimation.value,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Transform.scale(
                          scale: _successScaleAnimation.value,
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 64,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Xác thực thành công!',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.purpose == 'register'
                                        ? 'Đang tạo tài khoản...'
                                        : 'Đang đổi mật khẩu...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
              ),
            ],
          ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

