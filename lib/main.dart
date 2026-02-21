import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'homepage.dart';
import 'models/order_model.dart';
import 'orders_page.dart';
import 'providers/cart_provider.dart';
import 'settings.dart';
import 'signin_page.dart';
import 'signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(OrderModelAdapter());
  await Hive.openBox(kBoxDatabase);
  await Hive.openBox<OrderModel>(kBoxOrders);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
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
    await Future.delayed(const Duration(seconds: 2));
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
      title: 'LamonGo',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF2E86AB),
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
      ),
      home: _isLoading
          ? const SplashScreen()
          : (_hasUser ? const LoginPage() : const SignupPage()),
    );
  }
}

// -------------------- SPLASH SCREEN --------------------
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: ModernBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E86AB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2E86AB).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(CupertinoIcons.cube_box,
                    color: Color(0xFF2E86AB), size: 80),
              ),
              const SizedBox(height: 25),
              const Text(
                'LamonGo',
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  color: Color(0xFF2E86AB),
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const CupertinoActivityIndicator(color: Color(0xFF2E86AB)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- BACKGROUND WIDGET (used by splash) --------------------
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

// -------------------- MAIN APP AFTER LOGIN --------------------
class LamonGoApp extends StatefulWidget {
  const LamonGoApp({super.key});

  @override
  State<LamonGoApp> createState() => _LamonGoAppState();
}

class _LamonGoAppState extends State<LamonGoApp> {
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

  void toggleBiometrics(bool value) {
    box.put('biometrics', value);
    setState(() {});
  }

  void _showLogoutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
              );
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool biometricsEnabled = box.get('biometrics') ?? false;
    final Color bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F7FA);
    final Color barColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.9);

    return CupertinoApp(
      title: 'LamonGo',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primaryColor: const Color(0xFF2E86AB),
        scaffoldBackgroundColor: bgColor,
        barBackgroundColor: barColor,
      ),
      home: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          activeColor: const Color(0xFF2E86AB),
          backgroundColor: barColor,
          items: const [
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings_solid), label: 'Settings'),
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