import 'package:flutter/cupertino.dart';

// -------------------- COLORS --------------------
const Color kPrimary = Color(0xFF2E7D32);         // Deep forest green
const Color kPrimaryLight = Color(0xFFE8F5E9);    // Pale mint
const Color kAccent = Color(0xFF66BB6A);          // Fresh lime green
const Color kBackground = Color(0xFFF4F9F0);      // Soft ivory-green
const Color kDarkBackground = Color(0xFF0A1A0C);  // Deep forest dark
const Color kDarkCard = Color(0xFF1A2E1C);        // Dark green card
const Color kDarkBar = Color(0xFF1A2E1C);         // Dark green bar

// -------------------- XENDIT --------------------
const String kXenditKey =
    'xnd_development_kb2SqfRcnOXnqJjll8S43ZvB5PUAxtRnPwJ0pKRJa4a1D2j7hdzLe5jRSIVqX';
const String kXenditBaseUrl = 'https://api.xendit.co/v2/invoices';

// -------------------- HIVE BOXES --------------------
const String kBoxDatabase = 'database';
const String kBoxOrders = 'orders';

// -------------------- MAP --------------------
// Rider/restaurant fixed starting point
const double kRiderStartLat = 15.09426;
const double kRiderStartLng = 120.76941;

// Default map center (same area)
const double kMapCenterLat = 15.09426;
const double kMapCenterLng = 120.76941;

// -------------------- NUMBER FORMATTING --------------------
/// Formats a number with thousands comma separator.
/// e.g. 1100 → "1,100"  |  1234567.5 → "1,234,567.50"
String formatPrice(double amount, {bool decimals = false}) {
  final parts = (decimals
          ? amount.toStringAsFixed(2)
          : amount.toStringAsFixed(0))
      .split('.');
  // Insert commas every 3 digits from the right
  final buf = StringBuffer();
  final intPart = parts[0];
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  if (decimals && parts.length > 1) {
    buf.write('.');
    buf.write(parts[1]);
  }
  return buf.toString();
}
// showCupertinoDialog opens a new route with no theme ancestor,
// so dark mode and brand color are lost. This wrapper re-injects the full theme.
Future<T?> showThemedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  final theme = CupertinoTheme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return showCupertinoDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => CupertinoTheme(
      data: CupertinoThemeData(
        brightness: theme.brightness,
        primaryColor: kPrimary,                              // ← green buttons
        scaffoldBackgroundColor: isDark ? kDarkBackground : kBackground,
        barBackgroundColor: isDark ? kDarkBar : CupertinoColors.white,
        textTheme: CupertinoTextThemeData(
          primaryColor: kPrimary,                            // ← action text
          textStyle: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
      ),
      child: Builder(builder: builder),
    ),
  );
}

