import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'constants.dart';
import 'models/order_model.dart';
import 'services/pathfinder.dart';

class TrackingPage extends StatefulWidget {
  final OrderModel order;
  const TrackingPage({super.key, required this.order});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  // Order status
  String _status = 'Order Confirmed';
  Timer? _statusTimer;

  // Rider simulation
  final LatLng _riderStart =
      const LatLng(kRiderStartLat, kRiderStartLng);
  late LatLng _riderPosition;
  late List<LatLng> _fullPath;
  late List<LatLng> _travelledPath;
  int _riderStep = 0;
  Timer? _riderTimer;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final destination = LatLng(
      widget.order.deliveryLat,
      widget.order.deliveryLng,
    );

    // Compute A* path
    _fullPath = Pathfinder.findPath(_riderStart, destination);
    _riderPosition = _fullPath.first;
    _travelledPath = [_fullPath.first];

    // Status update after 1 minute
    _statusTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _status = 'Delivery is on the way 🛵';
          widget.order.status = _status;
          widget.order.save();
        });
      }
    });

    // Rider moves every 2 seconds
    _riderTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_riderStep >= _fullPath.length - 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _status = 'Delivered! 🎉';
            widget.order.status = _status;
            widget.order.save();
          });
        }
        return;
      }
      setState(() {
        _riderStep++;
        _riderPosition = _fullPath[_riderStep];
        _travelledPath = _fullPath.sublist(0, _riderStep + 1);
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _riderTimer?.cancel();
    super.dispose();
  }

  Color get _statusColor {
    if (_status.contains('Delivered')) return CupertinoColors.systemGreen;
    if (_status.contains('on the way')) return CupertinoColors.systemOrange;
    return kPrimary;
  }

  IconData get _statusIcon {
    if (_status.contains('Delivered')) return CupertinoIcons.checkmark_seal_fill;
    if (_status.contains('on the way')) return CupertinoIcons.car_fill;
    return CupertinoIcons.clock_fill;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final destination = LatLng(
        widget.order.deliveryLat, widget.order.deliveryLng);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Order Tracking'),
        backgroundColor: isDark
            ? kDarkBar.withValues(alpha: 0.9)
            : CupertinoColors.white.withValues(alpha: 0.9),
        // Prevent going back — order is placed
        leading: const SizedBox.shrink(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Status Banner ─────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        CupertinoColors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon,
                        color: _statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${widget.order.totalAmount.toStringAsFixed(2)} · ${widget.order.itemNames.length} item(s)',
                          style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey),
                        ),
                      ],
                    ),
                  ),
                  if (!_status.contains('Delivered'))
                    const CupertinoActivityIndicator(),
                ],
              ),
            ),

            // ── Map ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: destination,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.lamonco.lamon_go',
                      ),
                      // Travelled route — green polyline
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _travelledPath,
                            color: CupertinoColors.systemGreen,
                            strokeWidth: 4,
                          ),
                          // Remaining route — grey
                          Polyline(
                            points: _riderStep < _fullPath.length - 1
                                ? _fullPath.sublist(_riderStep)
                                : [],
                            color: CupertinoColors.systemGrey4,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // Delivery destination
                          Marker(
                            point: destination,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              CupertinoIcons.location_fill,
                              color: CupertinoColors.systemRed,
                              size: 38,
                            ),
                          ),
                          // Rider
                          Marker(
                            point: _riderPosition,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.systemGreen
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.car_fill,
                                color: CupertinoColors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Order Details ─────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Details',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: textColor)),
                  const SizedBox(height: 8),
                  ...List.generate(
                      widget.order.itemNames.length,
                      (i) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    '${widget.order.itemNames[i]} x${widget.order.itemQuantities[i]}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: textColor)),
                                Text(
                                    '₱${(widget.order.itemPrices[i] * widget.order.itemQuantities[i]).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: kPrimary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


