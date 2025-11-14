import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../user/home_screen.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../owner/owner_dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    print('🔄 LoginScreen initState');
    _resetState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state khi màn hình được hiển thị lại
    print('🔄 LoginScreen didChangeDependencies');
    if (!_isLoading) {
      _resetState();
    }
  }

  void _resetState() {
    print('🔄 Resetting login screen state');
    _isLoading = false;
    _obscurePassword = true;
    _emailController.clear();
    _passwordController.clear();
    _formKey.currentState?.reset();
    print('✅ Login screen state reset complete');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    print('🔐 Login attempt started: _isLoading=$_isLoading');
    
    // Prevent multiple login attempts
    if (_isLoading) {
      print('⚠️ Login already in progress, aborting');
      return;
    }
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }
    
    if (!mounted) {
      print('❌ Widget not mounted');
      return;
    }

    // Check if already logged in
    final authService = ref.read(authServiceProvider);
    if (authService.currentUser != null) {
      print('✅ Already logged in, skipping');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Đang đăng nhập...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      print('🔐 Calling signInWithEmail...');
      final credential = await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      print('🔐 SignIn result: ${credential?.user != null ? "Success" : "Failed"}');

      if (!mounted) {
        print('❌ Widget not mounted after sign in');
        return;
      }

      // Close dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (credential?.user != null) {
        print('✅ Login successful, waiting for user data...');
        
        // Wait for user data to be loaded
        int attempts = 0;
        const maxAttempts = 30; // Increase to 3 seconds
        UserModel? userModel;
        
        while (attempts < maxAttempts && mounted && userModel == null) {
          await Future.delayed(const Duration(milliseconds: 100));
          
          final currentUserAsync = ref.read(currentUserProvider);
          userModel = currentUserAsync.value;
          
          if (userModel != null) {
            print('✅ User data loaded: ${userModel.email}, role: ${userModel.role}');
            break;
          }
          
          attempts++;
          print('⏳ Waiting for user data... attempt $attempts/$maxAttempts');
        }
        
        if (userModel == null) {
          print('⚠️ User data not loaded after ${maxAttempts * 100}ms');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        
        // Reset loading state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        
        // Navigate to appropriate screen based on user role
        if (mounted && userModel != null) {
          print('✅ Navigating to dashboard for role: ${userModel.role}');
          
          // Pop all routes and navigate to the appropriate dashboard
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) {
                switch (userModel!.role) {
                  case 'admin':
                    return const AdminDashboardScreen();
                  case 'owner':
                    return const OwnerDashboardScreen();
                  case 'user':
                  default:
                    return const HomeScreen();
                }
              },
            ),
            (route) => false, // Remove all previous routes
          );
        }
        
        print('✅ Login process complete');
      } else {
        // Login failed
        print('❌ Login failed: credential is null');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đăng nhập thất bại: Không thể xác thực'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Login error: $e');
      
      if (!mounted) return;
      
      // Close dialog if still open
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (popError) {
        print('⚠️ Error closing dialog: $popError');
      }
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập thất bại: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Listen to auth state changes
    ref.listen(authStateProvider, (previous, next) {
      print('🔔 Auth state changed');
      if (!mounted) return;
      
      next.whenData((user) {
        if (user == null && !_isLoading) {
          print('🔄 User is null, resetting state');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isLoading) {
              setState(() {
                _resetState();
              });
            }
          });
        }
      });
    });
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.home_work_outlined,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Find Roommate',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tìm phòng trọ và bạn ở ghép',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    if (!value.contains('@')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: const Text('Quên mật khẩu?'),
                  ),
                ),
                const SizedBox(height: 32),
                // Login Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? '),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text('Đăng ký ngay'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}