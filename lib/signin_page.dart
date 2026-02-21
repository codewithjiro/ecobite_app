import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart'; // for LamonGoApp (after login)
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
    setState(() {
      isBiometricEnabled = box.get('biometrics') ?? false;
    });
  }

  void _showError(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Try Again'),
            onPressed: () => Navigator.pop(ctx),
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
          CupertinoPageRoute(builder: (context) => const LamonGoApp()),
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
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) {
        _showError('Unavailable', 'Biometrics not supported on this device.');
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock your LamonGo account',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate && mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const LamonGoApp()),
        );
      }
    } catch (e) {
      debugPrint('Auth Error: $e');
    }
  }

  Future<void> _handleResetWithBiometrics() async {
    // If biometrics is disabled, go straight to confirmation
    if (!isBiometricEnabled) {
      _showResetConfirmation();
      return;
    }

    // Biometrics is enabled — require Face ID before allowing reset
    bool isAuthorized = false;
    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canAuthenticate) {
        isAuthorized = await auth.authenticate(
          localizedReason: 'Verify your identity to reset app data',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
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

  void _showResetConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Reset App?'),
        content: const Text(
          'This will permanently delete your login credentials, '
              'biometric settings, and all app configurations. '
              'You will need to create a new account.',
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await box.clear();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  CupertinoPageRoute(builder: (context) => const SignupPage()),
                );
              }
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color textColor = CupertinoColors.black;

    return CupertinoPageScaffold(
      child: ModernBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.cube_box_fill,
                        size: 80, color: Color(0xFF2E86AB)),
                    const SizedBox(height: 20),
                    const Text('Welcome Back',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                    const Text('Please sign in to continue',
                        style: TextStyle(color: CupertinoColors.systemGrey)),
                    const SizedBox(height: 40),
                    GlassTextField(
                      controller: _username,
                      placeholder: 'Username',
                      icon: CupertinoIcons.person_fill,
                    ),
                    const SizedBox(height: 15),
                    GlassTextField(
                      controller: _password,
                      placeholder: 'Password',
                      obscureText: hidePassword,
                      icon: CupertinoIcons.lock_fill,
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          hidePassword ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                          color: CupertinoColors.systemGrey,
                        ),
                        onPressed: () => setState(() => hidePassword = !hidePassword),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: isProcessing ? null : _handleLogin,
                        borderRadius: BorderRadius.circular(15),
                        child: isProcessing
                            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                            : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isBiometricEnabled)
                      CupertinoButton(
                        onPressed: _handleBiometrics,
                        child: const Icon(CupertinoIcons.viewfinder,
                            size: 45, color: Color(0xFF2E86AB)),
                      ),
                    const SizedBox(height: 10),
                    CupertinoButton(
                      child: const Text('Reset App Data',
                          style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                      onPressed: _handleResetWithBiometrics,
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------- REUSABLE WIDGETS (copied to avoid circular import) --------------------
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
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
        ),
      ),
      child: child,
    );
  }
}

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