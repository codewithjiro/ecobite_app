import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'models/order_model.dart';
import 'tracking_page.dart';

// ── Exact stage labels from tracking_page.dart ────────────────────────────────
const _sPreparing  = 'Preparing your order 👨‍🍳';
const _sReady      = 'Ready for pickup 📦';
const _sOnTheWay   = 'Rider is on the way 🛵';
const _sAlmostThere = 'Almost there! 📍';
const _sDelivered  = 'Delivered! 🎉';

bool _statusIsDelivered(String s) => s == _sDelivered || s.contains('Delivered');

/// Maps a saved status string → 0-based pipeline index (0..5)
int _statusToStep(String s) {
  if (s == _sDelivered   || s.contains('Delivered'))    return 5;
  if (s == _sAlmostThere || s.contains('Almost'))       return 4;
  if (s == _sOnTheWay    || s.contains('on the way'))   return 3;
  if (s == _sReady       || s.contains('pickup'))       return 2;
  if (s == _sPreparing   || s.contains('Preparing'))    return 1;
  return 0; // Confirmed / unknown
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  // 0 = All, 1 = Active, 2 = Delivered
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBackground : kBackground;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: ValueListenableBuilder(
        valueListenable: Hive.box<OrderModel>(kBoxOrders).listenable(),
        builder: (context, Box<OrderModel> box, _) {
          final all       = box.values.toList().reversed.toList();
          final active    = all.where((o) => !_statusIsDelivered(o.status)).toList();
          final delivered = all.where((o) =>  _statusIsDelivered(o.status)).toList();

          final List<OrderModel> shown = switch (_selectedSegment) {
            1 => active,
            2 => delivered,
            _ => all,
          };

          return CustomScrollView(
            slivers: [
              // ── Nav bar ───────────────────────────────────────────────
              CupertinoSliverNavigationBar(
                largeTitle: const Text(
                  'My Orders',
                  style: TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                middle: const Text(
                  'My Orders',
                  style: TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                alwaysShowMiddle: false,
                backgroundColor: isDark
                    ? kDarkBar.withValues(alpha: 0.95)
                    : CupertinoColors.white.withValues(alpha: 0.95),
                border: null,
              ),

              // ── Segmented control ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _selectedSegment,
                      thumbColor: kPrimary,
                      backgroundColor: isDark
                          ? kDarkCard
                          : CupertinoColors.systemGrey5,
                      children: {
                        0: _segLabel('All',       all.length,       _selectedSegment == 0, isDark),
                        1: _segLabel('Active',    active.length,    _selectedSegment == 1, isDark),
                        2: _segLabel('Delivered', delivered.length, _selectedSegment == 2, isDark),
                      },
                      onValueChanged: (v) {
                        if (v != null) setState(() => _selectedSegment = v);
                      },
                    ),
                  ),
                ),
              ),

              // ── Order list / empty state ──────────────────────────────
              if (shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    segment: _selectedSegment,
                    isDark: isDark,
                  ),
                )
              else ..._buildGroupedSliver(shown, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _segLabel(String label, int count, bool selected, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? CupertinoColors.white
                  : isDark
                      ? CupertinoColors.white.withValues(alpha: 0.65)
                      : CupertinoColors.black.withValues(alpha: 0.6),
              letterSpacing: selected ? 0.2 : 0,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? CupertinoColors.white.withValues(alpha: 0.25)
                    : isDark
                        ? kAccent.withValues(alpha: 0.2)
                        : kPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? CupertinoColors.white
                      : isDark
                          ? kAccent
                          : kPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ── Groups orders by day, injects date-separator slivers ────────────────
  List<Widget> _buildGroupedSliver(List<OrderModel> orders, bool isDark) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build a flat list of (separator | card) widgets, then wrap in slivers
    final List<Widget> flat = [];
    String? lastLabel;

    for (final order in orders) {
      final d     = order.timestamp;
      final day   = DateTime(d.year, d.month, d.day);
      final diff  = today.difference(day).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Yesterday'
              : _fullDate(d);

      if (label != lastLabel) {
        flat.add(_DateSeparator(label: label, isDark: isDark));
        lastLabel = label;
      }

      flat.add(_OrderCard(
        order: order,
        isDark: isDark,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => TrackingPage(order: order)),
        ),
      ));
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => flat[i],
            childCount: flat.length,
          ),
        ),
      ),
    ];
  }

  String _fullDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
} // end _OrdersPageState


// ─────────────────────────────────────────────────────────────────────────────
// Date Separator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final String label;
  final bool   isDark;
  const _DateSeparator({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark
                        ? CupertinoColors.white.withValues(alpha: 0.0)
                        : CupertinoColors.black.withValues(alpha: 0.0),
                    isDark
                        ? CupertinoColors.white.withValues(alpha: 0.08)
                        : CupertinoColors.black.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? kDarkCard
                  : kPrimaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? kAccent.withValues(alpha: 0.15)
                    : kPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  label == 'Today'
                      ? CupertinoIcons.calendar_today
                      : label == 'Yesterday'
                          ? CupertinoIcons.clock
                          : CupertinoIcons.calendar,
                  size: 12,
                  color: isDark ? kAccent : kPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? CupertinoColors.white.withValues(alpha: 0.8)
                        : kPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark
                        ? CupertinoColors.white.withValues(alpha: 0.08)
                        : CupertinoColors.black.withValues(alpha: 0.08),
                    isDark
                        ? CupertinoColors.white.withValues(alpha: 0.0)
                        : CupertinoColors.black.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Card
// ─────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isDark;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor  = isDark ? kDarkCard : CupertinoColors.white;
    final textColor  = isDark ? CupertinoColors.white : CupertinoColors.black;
    final subtleColor = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
    final isDelivered = _statusIsDelivered(order.status);
    final stepIndex   = _statusToStep(order.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isDelivered
                  ? CupertinoColors.black.withValues(alpha: 0.04)
                  : kPrimary.withValues(alpha: 0.09),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
          border: isDelivered
              ? Border.all(
                  color: isDark
                      ? CupertinoColors.white.withValues(alpha: 0.06)
                      : CupertinoColors.black.withValues(alpha: 0.05),
                )
              : Border.all(
                  color: kPrimary.withValues(alpha: 0.14), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isDelivered
                          ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                          : kPrimaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isDelivered
                          ? CupertinoIcons.checkmark_seal_fill
                          : CupertinoIcons.bag_fill,
                      size: 19,
                      color: isDelivered
                          ? CupertinoColors.systemGreen
                          : kPrimary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(order.timestamp),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${order.itemNames.length} item${order.itemNames.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(stepIndex: stepIndex, status: order.status),
                ],
              ),
            ),

            // ── Separator ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  color: isDark
                      ? CupertinoColors.white.withValues(alpha: 0.07)
                      : CupertinoColors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),

            // ── Item list (max 3 shown) ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(
                  order.itemNames.length > 3 ? 3 : order.itemNames.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            order.itemNames[i],
                            style: TextStyle(fontSize: 13, color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? CupertinoColors.white.withValues(alpha: 0.08)
                                : kBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x${order.itemQuantities[i]}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: subtleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (order.itemNames.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 30, bottom: 6),
                child: Text(
                  '+${order.itemNames.length - 3} more items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),

            // ── Progress tracker (active orders only) ─────────────────
            if (!isDelivered) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Container(
                  height: 1,
                  color: isDark
                      ? CupertinoColors.white.withValues(alpha: 0.07)
                      : CupertinoColors.black.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _OrderProgress(stepIndex: stepIndex),
              ),
            ],

            const SizedBox(height: 14),

            // ── Footer ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.white.withValues(alpha: 0.04)
                    : kBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.arrow_right_circle_fill,
                        size: 14,
                        color: kPrimary.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isDelivered ? 'View details' : 'Track order',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₱${formatPrice(order.totalAmount, decimals: true)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ap  = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$min $ap';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar — 4 visible milestones from the 6-stage pipeline
//   Confirmed(0) → Preparing(1) → On the way(3) → Arriving(4)
// ─────────────────────────────────────────────────────────────────────────────
class _OrderProgress extends StatelessWidget {
  /// Raw pipeline index 0..5
  final int stepIndex;
  const _OrderProgress({required this.stepIndex});

  // Map pipeline index → compact 0-3 progress step
  int get _compact {
    if (stepIndex >= 4) return 3; // Almost there
    if (stepIndex >= 3) return 2; // On the way
    if (stepIndex >= 1) return 1; // Preparing
    return 0;                     // Confirmed
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Confirmed', 'Preparing', 'On the way', 'Arriving'];
    final cur    = _compact;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = (i ~/ 2) < cur;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                decoration: BoxDecoration(
                  color: passed ? kPrimary : CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }

        final si       = i ~/ 2;
        final isDone   = si < cur;
        final isActive = si == cur;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? kPrimary
                    : isActive
                        ? kPrimaryLight
                        : CupertinoColors.systemGrey5,
                border: Border.all(
                  color: isActive
                      ? kPrimary
                      : CupertinoColors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(CupertinoIcons.checkmark,
                        size: 11, color: CupertinoColors.white)
                    : isActive
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPrimary,
                            ),
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              labels[si],
              style: TextStyle(
                fontSize: 9,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? kPrimary : CupertinoColors.systemGrey,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge — driven by stepIndex for consistent colour/icon
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final int    stepIndex;
  final String status;
  const _StatusBadge({required this.stepIndex, required this.status});

  // Short display label
  String get _label {
    return switch (stepIndex) {
      5 => 'Delivered',
      4 => 'Almost there',
      3 => 'On the way',
      2 => 'Ready',
      1 => 'Preparing',
      _ => 'Confirmed',
    };
  }

  Color get _color {
    return switch (stepIndex) {
      5 => CupertinoColors.systemGreen,
      4 => CupertinoColors.systemPurple,
      3 => CupertinoColors.systemOrange,
      2 => CupertinoColors.systemBlue,
      1 => const Color(0xFFF57C00),
      _ => kPrimary,
    };
  }

  IconData get _icon {
    return switch (stepIndex) {
      5 => CupertinoIcons.checkmark_seal_fill,
      4 => CupertinoIcons.location_fill,
      3 => CupertinoIcons.arrow_right_circle_fill,
      2 => CupertinoIcons.bag_fill,
      1 => CupertinoIcons.flame_fill,
      _ => CupertinoIcons.checkmark_circle_fill,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 10, color: _color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  /// 0 = All, 1 = Active, 2 = Delivered
  final int  segment;
  final bool isDark;
  const _EmptyState({required this.segment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final icon = segment == 2
        ? CupertinoIcons.checkmark_seal
        : CupertinoIcons.bag;

    final title = switch (segment) {
      2 => 'No delivered orders yet',
      1 => 'No active orders',
      _ => 'No orders yet',
    };

    final sub = switch (segment) {
      2 => 'Completed orders will show up here.',
      1 => 'Your active orders will appear here.',
      _ => 'Place an order and track it in real time.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: isDark ? kDarkCard : kPrimaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 50,
                color: kPrimary.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? CupertinoColors.white
                    : CupertinoColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

