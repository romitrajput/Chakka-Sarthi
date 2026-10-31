import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isMpinMode = true; // true: ID/mobile + MPIN. false: first-time login (User ID + mobile)
  bool _obscureUserId = true;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  bool _isRedirecting = false;
  String? _businessName;

  @override
  void initState() {
    super.initState();
    _loadSavedUserId();
    cachedBusinessName().then((name) {
      if (mounted && name != null) setState(() => _businessName = name);
    });
  }

  Future<void> _loadSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('logged_in_user_id');
    final remember = prefs.getBool('remember_me') ?? false;
    if (savedId != null && remember && mounted) {
      setState(() {
        _userIdController.text = savedId;
        _rememberMe = true;
        _isMpinMode = true;
      });
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _userIdController.text.trim();
    final secret = _passwordController.text.trim();

    setState(() => _isLoggingIn = true);

    if (_isMpinMode) {
      await ref.read(authStateProvider.notifier).loginWithMpin(
            userId,
            secret,
            remember: _rememberMe,
          );
    } else {
      await ref.read(authStateProvider.notifier).loginWithPassword(
            userId,
            secret,
            remember: _rememberMe,
          );
    }

    setState(() => _isLoggingIn = false);

    if (!mounted) return;

    final authState = ref.read(authStateProvider);

    if (authState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            authState.error.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final user = authState.value;
    if (user == null) return;

    // Show user info screen before redirecting
    if (mounted) {
      await _showUserInfoAndRedirect(user);
    }
  }

  /// Show user details with nice UI and then redirect to appropriate dashboard
  Future<void> _showUserInfoAndRedirect(UserModel user) async {
    if (!mounted) return;

    final isAdmin = user.role == 'admin';
    final destination = user.isFirstLogin ? '/set-mpin' : (isAdmin ? '/admin/dashboard' : '/driver/dashboard');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GestureDetector(
        onTap: () {},
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.successGreen,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Welcome message
                  Text(
                    isAdmin ? 'Welcome Admin!' : 'Welcome Driver!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have successfully logged in',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // User info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppColors.primaryDark.withValues(alpha: 0.1)
                                : AppColors.accentOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isAdmin ? 'ADMIN' : 'DRIVER',
                            style: TextStyle(
                              color: isAdmin ? AppColors.primaryDark : AppColors.accentOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // User ID row
                        _buildUserInfoRow(
                          Icons.person_outline,
                          'Login ID',
                          user.userId,
                        ),
                        const Divider(height: 24, indent: 0),

                        // Full name row
                        _buildUserInfoRow(
                          Icons.business_outlined,
                          'Name',
                          user.fullName,
                        ),
                        const Divider(height: 24, indent: 0),

                        // Mobile row
                        _buildUserInfoRow(
                          Icons.phone_outlined,
                          'Mobile',
                          user.mobile,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Loading indicator or Continue button
                  if (_isRedirecting)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _redirectToDashboard(destination, user),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryMid, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _redirectToDashboard(String destination, UserModel user) async {
    if (!mounted) return;

    setState(() => _isRedirecting = true);

    // Small delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.of(context).pop(); // Close dialog
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF14161F),
      body: Stack(
        children: [
          // ========== BACKGROUND: plain brand colour (old Sanjay Roadlines image removed) ==========
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenH * 0.38,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14161F), Color(0xFF2A2E3B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ========== BRAND: logo, app name and business name ==========
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenH * 0.30,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(screenW * 0.05),
                      child: Image.asset(
                        'assets/images/chakka_saarthi_icon.png',
                        width: screenW * 0.2,
                        height: screenW * 0.2,
                      ),
                    ),
                    SizedBox(height: screenH * 0.012),
                    Text(
                      _businessName ?? AppStrings.appName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenW * 0.055,
                        fontWeight: FontWeight.w800,
                        shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                      ),
                    ),
                    if (_businessName != null)
                      Text(
                        AppStrings.appName,
                        style: TextStyle(
                          color: const Color(0xFFFFD23F),
                          fontSize: screenW * 0.032,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ========== WHITE CARD: Asymmetric rounded top-left corner ==========
          Positioned(
            top: screenH * 0.30,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: _CardClipper(),
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    screenW * 0.07,
                    screenH * 0.04,
                    screenW * 0.07,
                    screenH * 0.02,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Back
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: screenW * 0.06,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        SizedBox(height: screenH * 0.003),
                        Text(
                          'Login to access your fleet operations',
                          style: TextStyle(
                            fontSize: screenW * 0.033,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        SizedBox(height: screenH * 0.018),

                        // User ID
                        _buildLabel(_isMpinMode ? 'User ID or Mobile Number' : 'User ID'),
                        SizedBox(height: screenH * 0.006),
                        TextFormField(
                          controller: _userIdController,
                          textCapitalization: TextCapitalization.characters,
                          obscureText: _obscureUserId,
                          enableSuggestions: false,
                          autocorrect: false,
                          style: TextStyle(
                              fontSize: screenW * 0.035, letterSpacing: 1),
                          decoration: _inputDecoration(
                            _isMpinMode ? 'Enter User ID or mobile number' : 'Enter your User ID',
                            Icons.person_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscureUserId ? 'Show' : 'Hide',
                              icon: Icon(
                                _obscureUserId
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureUserId = !_obscureUserId),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return _isMpinMode ? 'Enter your User ID or mobile number' : 'User ID is required';
                            }
                            final t = v.trim();
                            if (RegExp(r'^\d+$').hasMatch(t) && t.length != 10) {
                              return 'Mobile number must be 10 digits';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: screenH * 0.014),

                        // Password / MPIN
                        _buildLabel(
                            _isMpinMode ? 'MPIN' : 'Mobile Number'),
                        SizedBox(height: screenH * 0.006),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.number,
                          maxLength: _isMpinMode ? 4 : 10, // MPIN 4 digits, mobile 10 digits
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                              fontSize: screenW * 0.035, letterSpacing: 2),
                          decoration: _inputDecoration(
                            _isMpinMode
                                ? 'Enter 4-digit MPIN'
                                : 'Enter mobile number',
                            _isMpinMode
                                ? Icons.lock_outline
                                : Icons.phone_outlined,
                          ).copyWith(
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return _isMpinMode
                                  ? 'MPIN is required'
                                  : 'Mobile number is required';
                            }
                            if (_isMpinMode && v.length != 4) {
                              return 'MPIN must be exactly 4 digits';
                            }
                            if (!_isMpinMode && v.length != 10) {
                              return 'Mobile number must be 10 digits';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: screenH * 0.01),

                        // Remember me + Forgot User ID
                        Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppColors.primaryDark,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Remember me',
                                style: TextStyle(
                                    fontSize: screenW * 0.033,
                                    color: AppColors.textSecondary)),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please contact your admin to recover your User ID.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot User ID?',
                                style: TextStyle(
                                  fontSize: screenW * 0.033,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenH * 0.018),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: screenH * 0.058,
                          child: ElevatedButton(
                            onPressed:
                                (_isLoggingIn || authState.isLoading) ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandYellow,
                              foregroundColor: AppColors.onBrandYellow,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: (_isLoggingIn || authState.isLoading)
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: AppColors.onBrandYellow, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('LOGIN',
                                          style: TextStyle(
                                              fontSize: screenW * 0.04,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5)),
                                      SizedBox(width: screenW * 0.025),
                                      Icon(Icons.arrow_forward,
                                          size: screenW * 0.05),
                                    ],
                                  ),
                          ),
                        ),

                        // OR divider
                        SizedBox(height: screenH * 0.014),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.grey.shade300, thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: screenW * 0.04),
                              child: Text('OR',
                                  style: TextStyle(
                                      fontSize: screenW * 0.033,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Colors.grey.shade300, thickness: 1)),
                          ],
                        ),
                        SizedBox(height: screenH * 0.014),

                        // Login with MPIN button
                        SizedBox(
                          width: double.infinity,
                          height: screenH * 0.058,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isMpinMode = !_isMpinMode;
                                _passwordController.clear();
                                _obscurePassword = true;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(
                                  color: AppColors.primaryDark, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isMpinMode
                                      ? 'First time? Set up your MPIN'
                                      : 'Back to MPIN login',
                                  style: TextStyle(
                                    fontSize: screenW * 0.038,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: screenH * 0.008),
                        Center(
                          child: Text(
                            _isMpinMode
                                ? 'New user: log in once with User ID + mobile number'
                                : 'Already have an MPIN? Go back to MPIN login',
                            style: TextStyle(
                              fontSize: screenW * 0.03,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        SizedBox(height: screenH * 0.02),

                        // ===== Bottom features =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFeatureItem(
                                context,
                                Icons.local_shipping_outlined,
                                'Track Fleet\nAnytime'),
                            _buildFeatureItem(
                                context,
                                Icons.bar_chart_rounded,
                                'Improve\nEfficiency'),
                            _buildFeatureItem(
                                context,
                                Icons.verified_outlined,
                                'Drive\nSafer'),
                          ],
                        ),
                        SizedBox(height: screenH * 0.01),
                        Center(
                          child: Text(
                            '© 2026 Chakka Saarthi. All rights reserved.',
                            style: TextStyle(
                              fontSize: screenW * 0.028,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        SizedBox(height: screenH * 0.01),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
      BuildContext context, IconData icon, String label) {
    final screenW = MediaQuery.of(context).size.width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primaryDark, size: screenW * 0.065),
        SizedBox(height: MediaQuery.of(context).size.height * 0.005),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: screenW * 0.028,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
      ),
    );
  }
}

// Custom clipper for asymmetric rounded top-left corner
class _CardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = 40.0;

    // Start at bottom-left
    path.lineTo(0, size.height);
    // Bottom-right
    path.lineTo(size.width, size.height);
    // Top-right
    path.lineTo(size.width, radius);
    // Rounded top-right corner
    path.quadraticBezierTo(size.width, 0, size.width - radius, 0);
    // Top edge
    path.lineTo(radius, 0);
    // Rounded top-left corner (larger radius for asymmetric look)
    path.quadraticBezierTo(0, 0, 0, radius);
    // Back to start
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
