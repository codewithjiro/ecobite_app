import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'homepage.dart';
import 'models/order_model.dart';
import 'orders_page.dart';
import 'providers/cart_provider.dart';
import 'services/notification_service.dart';
import 'settings.dart';
import 'signin_page.dart';
import 'signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(OrderModelAdapter());
  await Hive.openBox(kBoxDatabase);
  await Hive.openBox<OrderModel>(kBoxOrders);
  await NotificationService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: const AuthGate(),
    ),
  );
}

// -------------------- AUTH GATE --------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _hasUser = false;

  @override
  void initState() {
    super.initState();
    _handleStartup();
  }

  Future<void> _handleStartup() async {
    await Future.delayed(const Duration(seconds: 3));
    final box = Hive.box('database');
    if (mounted) {
      setState(() {
        _hasUser = box.get('username') != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'EcoBite',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: kPrimary,
        scaffoldBackgroundColor: kBackground,
      ),
      home: _isLoading
          ? const SplashScreen()
          : (_hasUser ? const LoginPage() : const SignupPage()),
    );
  }
}

// -------------------- SPLASH SCREEN --------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Wave dots ────────────────────────────────────────────────────────────
  static const _dotCount  = 4;
  static const _dotSize   = 8.0;
  static const _waveMs    = 600;
  static const _staggerMs = 120;

  late final List<AnimationController> _dotCtrls;
  late final List<Animation<double>>   _dotOffsets;

  // ── Logo entrance ────────────────────────────────────────────────────────
  late final AnimationController _logoCtr;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _logoFade;

  // ── Tagline fade ─────────────────────────────────────────────────────────
  late final AnimationController _tagCtr;
  late final Animation<double>   _tagFade;

  // ── Floating circles ─────────────────────────────────────────────────────
  late final AnimationController _floatCtr;

  @override
  void initState() {
    super.initState();

    // Logo: scale 0.5 → 1.0 + fade in over 700ms
    _logoCtr = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtr, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtr, curve: Curves.easeIn));
    _logoCtr.forward();

    // Tagline: fade in after 500ms
    _tagCtr = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _tagFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _tagCtr, curve: Curves.easeIn));
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _tagCtr.forward();
    });

    // Floating animation
    _floatCtr = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);

    // Wave dots
    _dotCtrls = List.generate(_dotCount, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: _waveMs),
      );
      Future.delayed(Duration(milliseconds: 600 + i * _staggerMs), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
      return ctrl;
    });

    _dotOffsets = _dotCtrls.map((c) {
      return Tween<double>(begin: 0.0, end: -12.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    _logoCtr.dispose();
    _tagCtr.dispose();
    _floatCtr.dispose();
    for (final c in _dotCtrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // ── Gradient background ────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5E9),
                  Color(0xFFC8E6C9),
                  Color(0xFFB2DFDB),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Floating decorative circles ────────────────────
          AnimatedBuilder(
            animation: _floatCtr,
            builder: (_, __) => Stack(
              children: [
                Positioned(
                  top: size.height * 0.08 + (_floatCtr.value * 20),
                  right: size.width * 0.1,
                  child: _FloatingCircle(
                    size: 80,
                    color: kPrimary.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  top: size.height * 0.15 + (_floatCtr.value * -15),
                  left: size.width * 0.05,
                  child: _FloatingCircle(
                    size: 50,
                    color: kAccent.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.2 + (_floatCtr.value * 25),
                  left: size.width * 0.15,
                  child: _FloatingCircle(
                    size: 100,
                    color: kPrimary.withValues(alpha: 0.06),
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.12 + (_floatCtr.value * -18),
                  right: size.width * 0.08,
                  child: _FloatingCircle(
                    size: 60,
                    color: kAccent.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ───────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo (animated entrance) ───────────────────
                AnimatedBuilder(
                  animation: _logoCtr,
                  builder: (_, child) => Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  ),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kPrimary.withValues(alpha: 0.15),
                          kAccent.withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(
                        color: kPrimary.withValues(alpha: 0.2),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/svg/splash.svg',
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── App name ───────────────────────────────────
                AnimatedBuilder(
                  animation: _logoFade,
                  builder: (_, child) => Opacity(opacity: _logoFade.value, child: child),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [kPrimary, Color(0xFF1B5E20)],
                    ).createShader(bounds),
                    child: const Text(
                      'EcoBite',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Tagline (delayed fade) ─────────────────────
                AnimatedBuilder(
                  animation: _tagFade,
                  builder: (_, child) => Opacity(opacity: _tagFade.value, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Eat clean. Tread lightly. 🌿',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // ── Wave dots ──────────────────────────────────
                SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(_dotCount, (i) {
                      return AnimatedBuilder(
                        animation: _dotOffsets[i],
                        builder: (_, __) {
                          final offset = _dotOffsets[i].value;
                          final t = (-offset / 12.0).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Transform.translate(
                              offset: Offset(0, offset),
                              child: Container(
                                width: _dotSize,
                                height: _dotSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(kAccent, kPrimary, t)!,
                                      Color.lerp(const Color(0xFF81C784), kPrimary, t)!,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimary.withValues(alpha: t * 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating circle decoration ─────────────────────────────────────────────────
class _FloatingCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _FloatingCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// -------------------- ECO BACKGROUND (green gradient) --------------------
class EcoBackground extends StatelessWidget {
  final Widget child;
  const EcoBackground({super.key, required this.child});

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

// -------------------- MAIN APP AFTER LOGIN --------------------
class EcoBiteApp extends StatefulWidget {
  const EcoBiteApp({super.key});

  @override
  State<EcoBiteApp> createState() => _EcoBiteAppState();
}

class _EcoBiteAppState extends State<EcoBiteApp> {
  bool isDark = false;
  final box = Hive.box('database');

  @override
  void initState() {
    super.initState();
    isDark = box.get('isDark', defaultValue: false);
  }

  void toggleTheme(bool value) {
    setState(() => isDark = value);
    box.put('isDark', value);
  }

  Future<void> toggleBiometrics(bool value) async {
    // Turning OFF — allow freely
    if (!value) {
      box.put('biometrics', false);
      setState(() {});
      return;
    }

    // Turning ON — require Face ID / biometrics first
    final auth = LocalAuthentication();
    try {
      final bool isSupported = await auth.isDeviceSupported();
      if (!isSupported) {
        if (mounted) {
          showThemedDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Not Supported'),
              content: const Text('Biometric authentication is not available on this device.'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final List<BiometricType> available = await auth.getAvailableBiometrics();
      final bool useBiometricOnly = available.contains(BiometricType.face) ||
          available.contains(BiometricType.fingerprint);
      final bool hasFaceId = available.contains(BiometricType.face);

      final bool didAuth = await auth.authenticate(
        localizedReason: hasFaceId
            ? 'Use Face ID to enable biometric login'
            : 'Use Touch ID to enable biometric login',
        options: AuthenticationOptions(
          biometricOnly: useBiometricOnly,
          stickyAuth: true,
        ),
      );

      if (didAuth) {
        box.put('biometrics', true);
        setState(() {});
      }
      // If didAuth == false user cancelled — switch stays OFF, nothing saved
    } catch (e) {
      debugPrint('Biometrics toggle error: $e');
      // Auth error — leave switch OFF
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showThemedDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool biometricsEnabled = box.get('biometrics') ?? false;
    final Color bgColor = isDark ? kDarkBackground : kBackground;
    final Color barColor = isDark
        ? kDarkBar.withValues(alpha: 0.95)
        : CupertinoColors.white.withValues(alpha: 0.92);

    return CupertinoApp(
      title: 'EcoBite',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primaryColor: kPrimary,
        scaffoldBackgroundColor: bgColor,
        barBackgroundColor: barColor,
      ),
      home: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          activeColor: kPrimary,
          backgroundColor: barColor,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.leaf_arrow_circlepath),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder(
                valueListenable:
                    Hive.box<OrderModel>(kBoxOrders).listenable(),
                builder: (context, Box<OrderModel> box, _) {
                  final activeCount = box.values
                      .where((o) =>
                          o.status != 'Delivered! 🎉' &&
                          !o.status.contains('Delivered'))
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(CupertinoIcons.bag),
                        if (activeCount > 0)
                          Positioned(
                            top: -8,
                            right: -9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemRed,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                activeCount > 99 ? '99+' : '$activeCount',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings_solid),
              label: 'Settings',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          switch (index) {
            case 0:
              return const Homepage();
            case 1:
              return const OrdersPage();
            default:
              return SettingsPage(
                isDark: isDark,
                onThemeChanged: toggleTheme,
                isBiometricEnabled: biometricsEnabled,
                onBiometricsChanged: toggleBiometrics,
                onLogout: () => _showLogoutDialog(context),
              );
          }
        },
      ),
    );
  }
}