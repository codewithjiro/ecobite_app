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
import 'models/saved_address.dart';
import 'payment_page.dart';
import 'providers/cart_provider.dart';
import 'saved_addresses_page.dart';
import 'tracking_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  LatLng? _deliveryLocation;
  String? _deliveryLabel;
  bool _isProcessing = false;
  Timer? _pollTimer; // track so we can cancel on dispose

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Auto-select the default saved address if one exists
    final saved = _loadSavedAddresses();
    final defaultAddr = saved.where((a) => a.isDefault).isNotEmpty
        ? saved.firstWhere((a) => a.isDefault)
        : (saved.isNotEmpty ? saved.first : null);
    if (defaultAddr != null) {
      _deliveryLocation = LatLng(defaultAddr.lat, defaultAddr.lng);
      _deliveryLabel = defaultAddr.label;
    }
  }

  List<SavedAddress> _loadSavedAddresses() {
    final box = Hive.box(kBoxDatabase);
    final raw = box.get(kSavedAddressesKey) as String?;
    return SavedAddress.decodeList(raw);
  }

  // Opens a bottom-sheet picker: saved addresses + "Use new location" option
  Future<void> _pickDeliveryLocation() async {
    final saved = _loadSavedAddresses();

    if (saved.isEmpty) {
      // No saved addresses — go straight to map
      final result = await Navigator.push<MapPickerResult>(
        context,
        CupertinoPageRoute(builder: (_) => const MapPickerPage()),
      );
      if (result != null) {
        setState(() {
          _deliveryLocation = result.location;
          _deliveryLabel = result.address ?? '📍 Pinned location';
        });
      }
      return;
    }

    // Show picker sheet
    final brightness = CupertinoTheme.of(context).brightness;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoThemeData(brightness: brightness),
        child: _AddressPickerSheet(
          savedAddresses: saved,
          currentLocation: _deliveryLocation,
          currentLabel: _deliveryLabel,
          onSelected: (LatLng loc, String label) {
            setState(() {
              _deliveryLocation = loc;
              _deliveryLabel = label;
            });
            Navigator.of(ctx).pop();
          },
          onPickNew: () async {
            Navigator.of(ctx).pop();
            final result = await Navigator.push<MapPickerResult>(
              context,
              CupertinoPageRoute(builder: (_) => const MapPickerPage()),
            );
            if (result != null && mounted) {
              setState(() {
                _deliveryLocation = result.location;
                _deliveryLabel = result.address ?? '📍 Pinned location';
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_deliveryLocation == null) {
      _showError('Please select a delivery location first.');
      return;
    }

    final cart = context.read<CartProvider>();

    // Guard: nothing selected to checkout
    if (cart.selectedItems.isEmpty) {
      _showError('Please select at least one item to check out.');
      return;
    }

    setState(() => _isProcessing = true);

    // Show loading dialog
    showThemedDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            CupertinoActivityIndicator(radius: 15),
            SizedBox(height: 15),
            Text('Creating payment invoice...',
                style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );

    final totalAmount = cart.selectedTotal.ceil();

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
              'ecobite_${DateTime.now().millisecondsSinceEpoch}',
          'amount': totalAmount,
          'description': 'EcoBite Order — ${cart.selectedItems.length} item(s)',
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out. Check your connection.'),
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close loader
      }

      final data = jsonDecode(response.body);

      if (data['invoice_url'] != null) {
        if (mounted) {
          final invoiceId = data['id'] as String?;
          if (invoiceId == null) {
            setState(() => _isProcessing = false);
            _showError('Invalid payment response. Please try again.');
            return;
          }
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => PaymentPage(url: data['invoice_url']),
            ),
          );
          _pollPaymentStatus(
            invoiceId,
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
    _pollTimer?.cancel(); // cancel any existing timer before starting new one
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) { timer.cancel(); return; }
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
                cart.selectedItems.map((e) => e.foodItem.name).toList(),
            itemQuantities:
                cart.selectedItems.map((e) => e.quantity).toList(),
            itemPrices:
                cart.selectedItems.map((e) => e.foodItem.price).toList(),
            itemAddons: cart.selectedItems.map((e) {
              if (e.selectedAddons.isEmpty) return '';
              return e.selectedAddons
                  .map((a) => '${a.name}:${a.price}')
                  .join(',');
            }).toList(),
            totalAmount: cart.selectedTotal,
            status: 'Order Confirmed',
            timestamp: DateTime.now(),
            deliveryLat: location.latitude,
            deliveryLng: location.longitude,
            xenditInvoiceId: invoiceId,
            riderStep: 0,
            orderStartTime: DateTime.now(),
          );
          await box.add(order);

          cart.clearSelected();

          if (mounted) {
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
          if (mounted) setState(() => _isProcessing = false);
        }
      } catch (e) {
        timer.cancel();
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  void _showError(String message) {
    showThemedDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
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
                  ...cart.selectedItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.foodItem.name} x${item.quantity}',
                                    style: TextStyle(
                                        fontSize: 14, color: textColor),
                                  ),
                                ),
                                Text(
                                  '₱${formatPrice(item.subtotal)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: kPrimary),
                                ),
                              ],
                            ),
                            if (item.selectedAddons.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.selectedAddons
                                    .map((a) => '+ ${a.name} (₱${formatPrice(a.price)})')
                                    .join(', '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
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
                          '₱${formatPrice(cart.selectedTotal, decimals: true)}',
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
              onTap: _pickDeliveryLocation,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _deliveryLocation != null
                            ? kPrimary.withValues(alpha: 0.12)
                            : CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _deliveryLocation != null
                            ? CupertinoIcons.location_fill
                            : CupertinoIcons.map_pin,
                        color: _deliveryLocation != null
                            ? kPrimary
                            : CupertinoColors.systemGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _deliveryLocation != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _deliveryLabel ?? '📍 Pinned location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_deliveryLocation!.latitude.toStringAsFixed(5)}, ${_deliveryLocation!.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Select or pin your delivery location',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey),
                            ),
                    ),
                    Icon(
                      _deliveryLocation != null
                          ? CupertinoIcons.pencil
                          : CupertinoIcons.chevron_right,
                      color: _deliveryLocation != null
                          ? kPrimary
                          : CupertinoColors.systemGrey3,
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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Address Picker Sheet ──────────────────────────────────────────────────────
class _AddressPickerSheet extends StatelessWidget {
  final List<SavedAddress> savedAddresses;
  final LatLng? currentLocation;
  final String? currentLabel;
  final void Function(LatLng, String) onSelected;
  final VoidCallback onPickNew;

  const _AddressPickerSheet({
    required this.savedAddresses,
    required this.currentLocation,
    required this.currentLabel,
    required this.onSelected,
    required this.onPickNew,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            'Deliver to',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a saved address or pin a new one.',
            style: TextStyle(
                fontSize: 13, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 16),

          // Saved address options
          ...savedAddresses.map((addr) {
            final isSelected = currentLocation != null &&
                (currentLocation!.latitude - addr.lat).abs() < 0.00001 &&
                (currentLocation!.longitude - addr.lng).abs() < 0.00001;

            return GestureDetector(
              onTap: () =>
                  onSelected(LatLng(addr.lat, addr.lng), addr.label),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kPrimary.withValues(alpha: 0.08)
                      : (isDark
                          ? const Color(0xFF1F3520)
                          : const Color(0xFFF6FBF6)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? kPrimary
                        : (isDark
                            ? const Color(0xFF2A3E2A)
                            : const Color(0xFFDCEEDC)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimary
                            : kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.location_fill,
                        color: isSelected
                            ? CupertinoColors.white
                            : kPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  addr.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (addr.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            addr.coordString,
                            style: const TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.systemGrey),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(CupertinoIcons.checkmark_circle_fill,
                          color: kPrimary, size: 20),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 4),

          // Use new location
          GestureDetector(
            onTap: onPickNew,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2A3E2A)
                      : const Color(0xFFDCEEDC),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.map_pin_ellipse,
                        color: CupertinoColors.systemGrey, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Use a new location',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  const Icon(CupertinoIcons.chevron_right,
                      color: CupertinoColors.systemGrey3, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


