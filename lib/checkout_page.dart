import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'map_picker_page.dart';
import 'models/order_model.dart';
import 'payment_page.dart';
import 'providers/cart_provider.dart';
import 'tracking_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  LatLng? _deliveryLocation;
  bool _isProcessing = false;

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      CupertinoPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result != null) {
      setState(() => _deliveryLocation = result);
    }
  }

  Future<void> _processPayment() async {
    if (_deliveryLocation == null) {
      _showError('Please pin your delivery location first.');
      return;
    }

    setState(() => _isProcessing = true);

    // Show loading dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            CupertinoActivityIndicator(radius: 15),
            SizedBox(height: 15),
            Text('Securing Payment Gateway...',
                style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );

    final cart = context.read<CartProvider>();
    final totalAmount = cart.total.ceil();

    final auth =
        'Basic ${base64Encode(utf8.encode(kXenditKey))}';

    try {
      final response = await http.post(
        Uri.parse(kXenditBaseUrl),
        headers: {
          'Authorization': auth,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'external_id':
              'lamonco_${DateTime.now().millisecondsSinceEpoch}',
          'amount': totalAmount,
          'description': 'LamonGo Food Order — ${cart.items.length} item(s)',
        }),
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close loader
      }

      final data = jsonDecode(response.body);

      if (data['invoice_url'] != null) {
        if (mounted) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => PaymentPage(url: data['invoice_url']),
            ),
          );
          _pollPaymentStatus(
            data['id'] as String,
            auth,
            cart,
            _deliveryLocation!,
          );
        }
      } else {
        setState(() => _isProcessing = false);
        _showError('Could not create invoice. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _isProcessing = false);
      _showError('Network error: $e');
    }
  }

  void _pollPaymentStatus(
    String invoiceId,
    String auth,
    CartProvider cart,
    LatLng location,
  ) {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('$kXenditBaseUrl/$invoiceId'),
          headers: {'Authorization': auth},
        );
        final data = jsonDecode(response.body);

        if (data['status'] == 'PAID') {
          timer.cancel();

          // Save order to Hive
          final box = Hive.box<OrderModel>(kBoxOrders);
          final order = OrderModel(
            itemNames:
                cart.items.map((e) => e.foodItem.name).toList(),
            itemQuantities:
                cart.items.map((e) => e.quantity).toList(),
            itemPrices:
                cart.items.map((e) => e.foodItem.price).toList(),
            totalAmount: cart.total,
            status: 'Order Confirmed',
            timestamp: DateTime.now(),
            deliveryLat: location.latitude,
            deliveryLng: location.longitude,
            xenditInvoiceId: invoiceId,
          );
          await box.add(order);

          cart.clearCart();

          if (mounted) {
            // Close PaymentPage WebView
            Navigator.of(context, rootNavigator: true)
                .popUntil((route) => route.isFirst == false
                    ? route.settings.name == '/checkout'
                    : true);
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(
                builder: (_) => TrackingPage(order: order),
              ),
              (route) => route.isFirst,
            );
          }
        } else if (data['status'] == 'EXPIRED') {
          timer.cancel();
          setState(() => _isProcessing = false);
        }
      } catch (e) {
        timer.cancel();
        setState(() => _isProcessing = false);
      }
    });
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Checkout'),
        backgroundColor: isDark
            ? kDarkBar.withValues(alpha: 0.9)
            : CupertinoColors.white.withValues(alpha: 0.9),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Order Summary ──────────────────────────────────
            _SectionHeader(title: 'Order Summary', textColor: textColor),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ...cart.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.foodItem.name} x${item.quantity}',
                                style: TextStyle(
                                    fontSize: 14, color: textColor),
                              ),
                            ),
                            Text(
                              '₱${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary),
                            ),
                          ],
                        ),
                      )),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
                      ),
                    ),
                    child: SizedBox(width: double.infinity),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: textColor)),
                        Text(
                          '₱${cart.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: kPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Delivery Location ──────────────────────────────
            _SectionHeader(
                title: 'Delivery Location', textColor: textColor),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _deliveryLocation != null
                        ? kPrimary
                        : CupertinoColors.systemGrey4,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _deliveryLocation != null
                          ? CupertinoIcons.location_fill
                          : CupertinoIcons.map_pin,
                      color: _deliveryLocation != null
                          ? kPrimary
                          : CupertinoColors.systemGrey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _deliveryLocation != null
                            ? 'Lat: ${_deliveryLocation!.latitude.toStringAsFixed(5)}\nLng: ${_deliveryLocation!.longitude.toStringAsFixed(5)}'
                            : 'Tap to pin your delivery location',
                        style: TextStyle(
                          fontSize: 13,
                          color: _deliveryLocation != null
                              ? textColor
                              : CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: CupertinoColors.systemGrey3,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Pay Button ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: _deliveryLocation != null ? kPrimary : CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(14),
                onPressed: _isProcessing || _deliveryLocation == null
                    ? null
                    : _processPayment,
                child: _isProcessing
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.creditcard,
                              color: CupertinoColors.white),
                          SizedBox(width: 8),
                          Text(
                            'Pay with Xendit',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color textColor;
  const _SectionHeader({required this.title, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


