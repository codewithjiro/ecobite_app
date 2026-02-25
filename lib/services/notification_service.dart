import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Request Android 13+ runtime permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showDelivered(String orderSummary) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'ecobite_delivery',      // channel id
      'Delivery Updates',      // channel name
      channelDescription: 'Notifications for EcoBite order delivery status',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Order Delivered',
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000, // safe int32 range
      '🎉 Order Delivered!',
      'Your EcoBite order has arrived. $orderSummary Enjoy your meal! 🌿',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}

