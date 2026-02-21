import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'signin_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final box = Hive.box('database');
  bool hidePassword = true;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Oops'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  void _handleSignup() {
    if (_username.text.trim().isEmpty || _password.text.trim().isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    box.put('username', _username.text.trim());
    box.put('password', _password.text.trim());
    box.put('biometrics', false);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Account created successfully!\nPlease sign in to continue.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Sign In'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(builder: (context) => const LoginPage()),
              );
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF2D3436);

    return CupertinoPageScaffold(
      child: ModernBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create\nAccount',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign up to start using LamonGo delivery.',
                  style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
                ),
                const SizedBox(height: 40),
                GlassTextField(
                  controller: _username,
                  placeholder: 'Username',
                  icon: CupertinoIcons.person,
                ),
                const SizedBox(height: 15),
                GlassTextField(
                  controller: _password,
                  placeholder: 'Password',
                  icon: CupertinoIcons.lock,
                  obscureText: hidePassword,
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      hidePassword ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                      color: CupertinoColors.systemGrey,
                    ),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _handleSignup,
                    borderRadius: BorderRadius.circular(15),
                    child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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