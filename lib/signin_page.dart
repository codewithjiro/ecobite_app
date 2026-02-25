import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'main.dart';
import 'models/order_model.dart';
import 'providers/cart_provider.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  final box = Hive.box('database');

  bool hidePassword = true;
  bool isProcessing = false;
  bool isBiometricEnabled = false;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBiometricState();
    }
  }

  void _loadBiometricState() {
    final enabled = box.get('biometrics') ?? false;
    setState(() => isBiometricEnabled = enabled);
  }

  void _showError(String title, String message) {
    showThemedDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Try Again'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() => isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (_username.text.trim() == box.get('username') &&
        _password.text.trim() == box.get('password')) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const EcoBiteApp()),
        );
      }
    } else {
      if (mounted) {
        setState(() => isProcessing = false);
        _showError('Login Failed', 'Incorrect username or password.');
      }
    }
  }

  Future<void> _handleBiometrics() async {
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isSupported = await auth.isDeviceSupported();

      if (!isSupported) {
        if (mounted) {
          _showError('Unavailable', 'Biometric authentication is not supported on this device.');
        }
        return;
      }

      // Check what biometrics are available
      final List<BiometricType> available = await auth.getAvailableBiometrics();
      final bool hasFaceId = available.contains(BiometricType.face);
      final bool hasFingerprint = available.contains(BiometricType.fingerprint);

      // biometricOnly: true when actual biometrics enrolled; false as fallback
      final bool useBiometricOnly = canCheckBiometrics && (hasFaceId || hasFingerprint);

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: hasFaceId
            ? 'Use Face ID to sign in to EcoBite'
            : hasFingerprint
                ? 'Use Touch ID to sign in to EcoBite'
                : 'Unlock your EcoBite account',
        options: AuthenticationOptions(
          biometricOnly: useBiometricOnly,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate && mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (_) => const EcoBiteApp()),
        );
      }
    } catch (e) {
      debugPrint('Biometric Auth Error: $e');
      // Silently fail auto-trigger — user can still tap the button or sign in manually
    }
  }

  Future<void> _handleResetWithBiometrics() async {
    // Biometrics disabled → require password instead
    if (!isBiometricEnabled) {
      _showPasswordForReset();
      return;
    }

    bool isAuthorized = false;
    try {
      final bool isSupported = await auth.isDeviceSupported();
      if (isSupported) {
        final List<BiometricType> available = await auth.getAvailableBiometrics();
        final bool useBiometricOnly = available.contains(BiometricType.face) ||
            available.contains(BiometricType.fingerprint);
        isAuthorized = await auth.authenticate(
          localizedReason: 'Verify your identity to reset app data',
          options: AuthenticationOptions(
            biometricOnly: useBiometricOnly,
            stickyAuth: true,
          ),
        );
      } else {
        isAuthorized = true;
      }
    } catch (e) {
      debugPrint('Reset Auth Error: $e');
      return;
    }

    if (isAuthorized && mounted) {
      _showResetConfirmation();
    }
  }

  // ── Full reset ─────────────────────────────────────────────────────────────
  Future<void> _performReset(BuildContext navContext) async {
    // 1. Clear both Hive boxes
    await Hive.box(kBoxDatabase).clear();
    await Hive.box<OrderModel>(kBoxOrders).clear();
    // 2. Reset in-memory cart while context is still mounted
    if (mounted) context.read<CartProvider>().clearCart();
    // 3. Navigate — use the widget's own context so we always have a valid navigator
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const SignupPage()),
        (route) => false,
      );
    }
  }

  void _showPasswordForReset() {
    final pwCtrl = TextEditingController();
    bool obscure = true;
    String? errorMsg;

    showThemedDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => CupertinoAlertDialog(
          title: const Text('Reset App Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Enter your password to permanently delete all app data. This cannot be undone.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: pwCtrl,
                placeholder: 'Password',
                obscureText: obscure,
                autofocus: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffix: CupertinoButton(
                  padding: const EdgeInsets.only(right: 6),
                  onPressed: () => setStateDialog(() => obscure = !obscure),
                  child: Icon(
                    obscure ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                    size: 18,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 6),
                Text(
                  errorMsg!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Reset Everything'),
              onPressed: () async {
                final saved = box.get('password') as String?;
                if (pwCtrl.text.trim() == saved) {
                  // Password correct — reset immediately, no second dialog
                  Navigator.of(ctx).pop();
                  await _performReset(ctx);
                } else {
                  setStateDialog(() => errorMsg = 'Incorrect password. Try again.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation() {
    showThemedDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reset App?'),
        content: const Text(
          'This will permanently delete your login credentials, '
              'biometric settings, and all app configurations. '
              'You will need to create a new account.',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _performReset(ctx);
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // ── Green hero top ──────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.44,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decorative ring behind SVG
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.white.withValues(alpha: 0.12),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/svg/sign_in.svg',
                          width: 72,
                          height: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'EcoBite',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Eat clean. Tread lightly. 🌿',
                      style: TextStyle(
                        color: CupertinoColors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Mint bottom card ────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            top: size.height * 0.36,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B3A1D),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to your account to continue.',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Username field
                    _AuthField(
                      controller: _username,
                      placeholder: 'Username',
                      icon: CupertinoIcons.person_fill,
                    ),
                    const SizedBox(height: 14),

                    // Password field
                    _AuthField(
                      controller: _password,
                      placeholder: 'Password',
                      icon: CupertinoIcons.lock_fill,
                      obscureText: hidePassword,
                      suffix: GestureDetector(
                        onTap: () => setState(() => hidePassword = !hidePassword),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(
                            hidePassword
                                ? CupertinoIcons.eye_fill
                                : CupertinoIcons.eye_slash_fill,
                            color: CupertinoColors.systemGrey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: kPrimary,
                        disabledColor: kPrimary,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: isProcessing ? null : _handleLogin,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isProcessing
                              ? const Row(
                                  key: ValueKey('loading'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CupertinoActivityIndicator(
                                        color: CupertinoColors.white, radius: 10),
                                    SizedBox(width: 10),
                                    Text('Signing in…',
                                        style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16)),
                                  ],
                                )
                              : const Text(
                                  key: ValueKey('idle'),
                                  'Sign In',
                                  style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16),
                                ),
                        ),
                      ),
                    ),

                    // Biometrics button
                    if (isBiometricEnabled) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(16),
                          color: kPrimary.withValues(alpha: 0.08),
                          onPressed: _handleBiometrics,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.viewfinder,
                                  color: kPrimary, size: 22),
                              const SizedBox(width: 8),
                              const Text(
                                'Sign in with Biometrics',
                                style: TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Reset link — subtle, at the bottom
                    Center(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _handleResetWithBiometrics,
                        child: const Text(
                          'Reset App Data',
                          style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                              decoration: TextDecoration.underline,
                              decorationColor: CupertinoColors.systemGrey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Shared auth text field ─────────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEEDC), width: 1.5),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        placeholderStyle: const TextStyle(
            color: CupertinoColors.systemGrey2, fontSize: 15),
        style: const TextStyle(
            color: Color(0xFF1B3A1D), fontSize: 15),
        obscureText: obscureText,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Icon(icon, color: kPrimary, size: 19),
        ),
        suffix: suffix,
        decoration: const BoxDecoration(color: CupertinoColors.transparent),
      ),
    );
  }
}

// ── ModernBackground (kept for signup_page compatibility) ─────────────────────
class ModernBackground extends StatelessWidget {
  final Widget child;
  const ModernBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        ),
      ),
      child: child,
    );
  }
}

// ── GlassTextField (kept for backward compat) ─────────────────────────────────
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: CupertinoColors.white.withValues(alpha: 0.7),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey2),
            style: const TextStyle(color: CupertinoColors.black),
            obscureText: obscureText,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(icon, color: CupertinoColors.systemGrey),
            ),
            suffix: suffix,
            decoration: BoxDecoration(
              color: CupertinoColors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }
}

