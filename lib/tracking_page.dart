import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'constants.dart';
import 'models/order_model.dart';
import 'services/notification_service.dart';
import 'services/pathfinder.dart';

class TrackingPage extends StatefulWidget {
  final OrderModel order;
  const TrackingPage({super.key, required this.order});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

// ── Delivery pipeline ─────────────────────────────────────────────────────────
class _DeliveryStage {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _DeliveryStage({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _stages = [
  _DeliveryStage(
    label: 'Order Confirmed',
    subtitle: 'We received your order!',
    icon: CupertinoIcons.checkmark_circle_fill,
    color: kPrimary,
  ),
  _DeliveryStage(
    label: 'Preparing your order 👨‍🍳',
    subtitle: 'The kitchen is cooking your meal.',
    icon: CupertinoIcons.flame_fill,
    color: Color(0xFFF57C00),
  ),
  _DeliveryStage(
    label: 'Ready for pickup 📦',
    subtitle: 'Your order is packed and waiting for a rider.',
    icon: CupertinoIcons.bag_fill,
    color: Color(0xFF0288D1),
  ),
  _DeliveryStage(
    label: 'Rider is on the way 🛵',
    subtitle: 'Your rider has picked up your order.',
    icon: CupertinoIcons.car_fill,
    color: Color(0xFFF9A825),
  ),
  _DeliveryStage(
    label: 'Almost there! 📍',
    subtitle: 'Your rider is nearby.',
    icon: CupertinoIcons.location_fill,
    color: Color(0xFF7B1FA2),
  ),
  _DeliveryStage(
    label: 'Delivered! 🎉',
    subtitle: 'Enjoy your meal. Eat clean, tread lightly 🌿',
    icon: CupertinoIcons.checkmark_seal_fill,
    color: CupertinoColors.systemGreen,
  ),
];

// Seconds from order start for pipeline stages 0-3 (4 & 5 are rider-driven)
const _stageSecs = [0, 10, 20, 30, 0, 0];

class _TrackingPageState extends State<TrackingPage> {
  int _stageIndex = 0;
  final List<DateTime?> _stageTimes = List.filled(6, null);

  late List<LatLng> _fullPath;
  late List<LatLng> _travelledPath;
  late LatLng _riderStart;
  int _riderStep = 0;
  bool _riderMoving = false;
  bool _riderStarted = false; // guard against double-starting rider movement

  final List<Timer> _timers = [];
  final MapController _mapController = MapController();

  _DeliveryStage get _currentStage => _stages[_stageIndex];
  bool get _isDelivered => _stageIndex == 5;

  @override
  void initState() {
    super.initState();

    _riderStart = const LatLng(kRiderStartLat, kRiderStartLng);
    final destination = LatLng(
      widget.order.deliveryLat,
      widget.order.deliveryLng,
    );
    _fullPath = Pathfinder.findPath(_riderStart, destination);

    // ── Resume from saved state ──────────────────────────────────────
    final savedStatus = widget.order.status;
    // Guard: clamp riderStep so it never exceeds path bounds
    final maxStep = (_fullPath.length - 1).clamp(0, _fullPath.length - 1);
    final savedRiderStep = widget.order.riderStep.clamp(0, maxStep);
    final startTime = widget.order.orderStartTime ?? DateTime.now();
    final elapsed = DateTime.now().difference(startTime).inSeconds;

    // Restore stage from saved status string
    _stageIndex = _stageIndexFromStatus(savedStatus);
    _riderStep = savedRiderStep;
    _travelledPath = _fullPath.sublist(0, _riderStep + 1);

    // Seed stage timestamps for already-reached stages
    for (int i = 0; i <= _stageIndex; i++) {
      if (i <= 3) {
        _stageTimes[i] = startTime.add(Duration(seconds: _stageSecs[i]));
      } else {
        // Stages 4 & 5 approximate from elapsed
        _stageTimes[i] = startTime.add(Duration(seconds: elapsed - ((_stageIndex - i) * 10)));
      }
    }
    // Stage 0 is always the order start time
    _stageTimes[0] = startTime;

    if (_riderStep > 0 || _stageIndex >= 3) {
      _riderMoving = true;
    }

    // If already delivered, show final state — no timers needed
    if (_isDelivered) return;

    // ── Schedule remaining stage transitions ─────────────────────────
    for (int i = 1; i <= 3; i++) {
      final stageTime = _stageSecs[i];
      final remaining = stageTime - elapsed;
      if (_stageIndex < i) {
        final delay = remaining > 0 ? remaining : 0;
        final capturedI = i;
        _timers.add(Timer(Duration(seconds: delay), () {
          if (!mounted) return;
          _advanceTo(capturedI);
          if (capturedI == 3) _startRiderMovement();
        }));
      }
    }

    // If already in stage 3+ but not delivered, resume rider movement now
    if (_stageIndex >= 3 && !_isDelivered) {
      _riderMoving = true;
      _startRiderMovement();
    }
  }

  int _stageIndexFromStatus(String status) {
    if (status.contains('Delivered')) return 5;
    if (status.contains('Almost')) return 4;
    if (status.contains('on the way') || status.contains('Rider')) return 3;
    if (status.contains('pickup') || status.contains('Ready')) return 2;
    if (status.contains('Preparing')) return 1;
    return 0;
  }

  void _advanceTo(int index) {
    if (!mounted || _stageIndex >= index) return;
    setState(() {
      _stageIndex = index;
      _stageTimes[index] ??= DateTime.now(); // record real time
    });
    _saveStatus();

    // Fire push notification on delivery
    if (index == 5) {
      final summary = widget.order.itemNames.length == 1
          ? widget.order.itemNames.first
          : '${widget.order.itemNames.first} + ${widget.order.itemNames.length - 1} more';
      NotificationService.showDelivered(summary);
    }
  }

  void _saveStatus() {
    widget.order.status = _currentStage.label;
    widget.order.save();
  }

  void _startRiderMovement() {
    if (_riderStarted) return; // prevent double-start
    _riderStarted = true;
    setState(() => _riderMoving = true);
    final totalSteps = _fullPath.length - 1;
    if (_riderStep >= totalSteps) {
      _advanceTo(5);
      return;
    }

    // Zoom in on rider when it starts moving
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(_fullPath[_riderStep], 15);
      } catch (_) {}
    });

    // 150ms tick — fast but still smooth
    _timers.add(Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_riderStep >= totalSteps) {
        timer.cancel();
        _advanceTo(5);
        return;
      }

      _riderStep++;
      final progress = _riderStep / totalSteps;

      setState(() {
        _travelledPath = _fullPath.sublist(0, _riderStep + 1);
      });

      // Persist rider step every 10 steps
      if (_riderStep % 10 == 0) {
        widget.order.riderStep = _riderStep;
        widget.order.save();
      }

      // Almost there at 80%
      if (progress >= 0.80 && _stageIndex < 4) {
        _advanceTo(4);
      }

      // Follow rider on map
      try {
        _mapController.move(_fullPath[_riderStep], 15);
      } catch (_) {}
    }));
  }

  @override
  void dispose() {
    // Save final rider step before leaving
    widget.order.riderStep = _riderStep;
    widget.order.save();
    for (final t in _timers) { t.cancel(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final subColor = isDark ? const Color(0xFF8BAE8B) : CupertinoColors.systemGrey;
    final destination = LatLng(widget.order.deliveryLat, widget.order.deliveryLng);
    final riderPos = _riderMoving ? _fullPath[_riderStep] : _fullPath.first;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // ── Status banner ──────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _currentStage.color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pulsing icon
                  _PulsingIcon(
                    icon: _currentStage.icon,
                    color: _currentStage.color,
                    animate: !_isDelivered,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStage.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _currentStage.color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currentStage.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  if (!_isDelivered) const CupertinoActivityIndicator(),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Vertical timeline (scrollable if needed) ───────
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _DeliveryTimeline(
                  currentIndex: _stageIndex,
                  stageTimes: _stageTimes,
                  isDark: isDark,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Map ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      // Show midpoint between restaurant & destination so both are visible
                      initialCenter: LatLng(
                        (_riderStart.latitude + destination.latitude) / 2,
                        (_riderStart.longitude + destination.longitude) / 2,
                      ),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ecobite.app',
                      ),
                      PolylineLayer(
                        polylines: [
                          if (_travelledPath.length > 1)
                            Polyline(
                              points: _travelledPath,
                              color: kPrimary,
                              strokeWidth: 4,
                            ),
                          if (_riderStep < _fullPath.length - 1)
                            Polyline(
                              points: _fullPath.sublist(_riderStep),
                              color: CupertinoColors.systemGrey4,
                              strokeWidth: 3,
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // ── Restaurant / origin marker ──────────
                          Marker(
                            point: _riderStart,
                            width: 80,
                            height: 68,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimary.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.leaf_arrow_circlepath,
                                    color: CupertinoColors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Our Store',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ── Destination pin ─────────────────────
                          Marker(
                            point: destination,
                            width: 50,
                            height: 60,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              CupertinoIcons.location_fill,
                              color: Color(0xFFE53935),
                              size: 40,
                            ),
                          ),
                          // ── Rider (visible once on the way) ─────
                          if (_riderMoving)
                            Marker(
                              point: riderPos,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9A825),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF9A825)
                                          .withValues(alpha: 0.55),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '🛵',
                                  style: TextStyle(fontSize: 22),
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

            const SizedBox(height: 12),

            // ── Order summary ──────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Summary',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: subColor)),
                  const SizedBox(height: 8),
                  ...List.generate(
                    widget.order.itemNames.length,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.order.itemNames[i]} ×${widget.order.itemQuantities[i]}',
                              style: TextStyle(fontSize: 13, color: textColor),
                            ),
                          ),
                          Text(
                            '₱${formatPrice(widget.order.itemPrices[i] * widget.order.itemQuantities[i])}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: kPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                      height: 1,
                      color: isDark
                          ? const Color(0xFF2A3E2A)
                          : const Color(0xFFE8F5E9)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: textColor)),
                      Text(
                        '₱${formatPrice(widget.order.totalAmount, decimals: true)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: kPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Back to Home ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.house_fill,
                          color: CupertinoColors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Back to Home',
                          style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing icon ──────────────────────────────────────────────────────────────
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool animate;
  const _PulsingIcon(
      {required this.icon, required this.color, required this.animate});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingIcon old) {
    super.didUpdateWidget(old);
    if (!widget.animate) {
      _ctrl.stop();
      _ctrl.reset();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, color: widget.color, size: 26),
      ),
    );
  }
}

// ── Vertical delivery timeline ────────────────────────────────────────────────
class _DeliveryTimeline extends StatelessWidget {
  final int currentIndex;
  final List<DateTime?> stageTimes;
  final bool isDark;

  const _DeliveryTimeline({
    required this.currentIndex,
    required this.stageTimes,
    required this.isDark,
  });

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}  $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final lineColor = isDark ? const Color(0xFF2A3E2A) : const Color(0xFFDCEEDC);
    final pendingTextColor = isDark
        ? const Color(0xFF4A6B4A)
        : CupertinoColors.systemGrey3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: List.generate(_stages.length, (i) {
          final reached = currentIndex >= i;
          final isActive = currentIndex == i;
          final isLast = i == _stages.length - 1;
          final stage = _stages[i];
          final ts = stageTimes.length > i ? stageTimes[i] : null;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: dot + connector line ─────────────────
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    // Dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: isActive ? 26 : 20,
                      height: isActive ? 26 : 20,
                      decoration: BoxDecoration(
                        color: reached ? stage.color : lineColor,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [BoxShadow(
                                color: stage.color.withValues(alpha: 0.4),
                                blurRadius: 8,
                              )]
                            : [],
                      ),
                      child: Icon(
                        reached ? stage.icon : CupertinoIcons.circle,
                        color: reached
                            ? CupertinoColors.white
                            : (isDark
                                ? const Color(0xFF2A3E2A)
                                : CupertinoColors.systemGrey4),
                        size: isActive ? 14 : 11,
                      ),
                    ),
                    // Connector line
                    if (!isLast)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 2,
                        height: 36,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: currentIndex > i ? stage.color : lineColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Right: stage info ───────────────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: isActive ? 3 : 4,
                    bottom: isLast ? 8 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stage label
                          Expanded(
                            child: Text(
                              stage.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isActive ? 13 : 12,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: reached
                                    ? (isActive ? stage.color : (isDark
                                        ? CupertinoColors.white
                                        : CupertinoColors.black))
                                    : pendingTextColor,
                              ),
                            ),
                          ),
                          // Timestamp
                          if (reached && ts != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _fmt(ts),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? stage.color
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (reached) ...[
                        const SizedBox(height: 2),
                        Text(
                          stage.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF8BAE8B)
                                : CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                      SizedBox(height: isLast ? 0 : 10),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}




