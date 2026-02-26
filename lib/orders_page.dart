import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'models/order_model.dart';
import 'tracking_page.dart';

// ── Exact stage labels from tracking_page.dart ────────────────────────────────
const _sPreparing   = 'Preparing your order 👨‍🍳';
const _sReady       = 'Ready for pickup 📦';
const _sOnTheWay    = 'Rider is on the way 🛵';
const _sAlmostThere = 'Almost there! 📍';
const _sDelivered   = 'Delivered! 🎉';

bool _statusIsDelivered(String s) => s == _sDelivered || s.contains('Delivered');

/// Maps a saved status string → 0-based pipeline index (0..5)
int _statusToStep(String s) {
  if (s == _sDelivered   || s.contains('Delivered'))  return 5;
  if (s == _sAlmostThere || s.contains('Almost'))     return 4;
  if (s == _sOnTheWay    || s.contains('on the way')) return 3;
  if (s == _sReady       || s.contains('pickup'))     return 2;
  if (s == _sPreparing   || s.contains('Preparing'))  return 1;
  return 0;
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final isDark  = CupertinoTheme.of(context).brightness == Brightness.dark;
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
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Nav bar ────────────────────────────────────────────
              CupertinoSliverNavigationBar(
                largeTitle: const Text(
                  'My Orders',
                  style: TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w900,
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

              // ── Segment filter ───────────────────────────��─────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _PremiumSegmentedControl(
                    selected: _selectedSegment,
                    isDark: isDark,
                    allCount: all.length,
                    activeCount: active.length,
                    deliveredCount: delivered.length,
                    onChanged: (v) => setState(() => _selectedSegment = v),
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────
              if (shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    segment: _selectedSegment,
                    isDark: isDark,
                  ),
                )
              else
                ..._buildGroupedSliver(shown, isDark),
            ],
          );
        },
      ),
    );
  }

  // ── Groups orders by day, injects date-separator slivers ──────────────────
  List<Widget> _buildGroupedSliver(List<OrderModel> orders, bool isDark) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
        flat.add(_SectionDateHeader(label: label, isDark: isDark));
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
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
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Premium Segmented Control
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumSegmentedControl extends StatelessWidget {
  final int selected;
  final bool isDark;
  final int allCount;
  final int activeCount;
  final int deliveredCount;
  final ValueChanged<int> onChanged;

  const _PremiumSegmentedControl({
    required this.selected,
    required this.isDark,
    required this.allCount,
    required this.activeCount,
    required this.deliveredCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTab(0, 'All', allCount, CupertinoIcons.square_grid_2x2_fill),
          const SizedBox(width: 4),
          _buildTab(1, 'Active', activeCount, CupertinoIcons.flame_fill),
          const SizedBox(width: 4),
          _buildTab(2, 'Delivered', deliveredCount, CupertinoIcons.checkmark_seal_fill),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, int count, IconData icon) {
    final isSelected = selected == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimary
                : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? CupertinoColors.white
                    : isDark
                        ? CupertinoColors.systemGrey
                        : CupertinoColors.systemGrey2,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? CupertinoColors.white
                      : isDark
                          ? CupertinoColors.white.withValues(alpha: 0.6)
                          : CupertinoColors.black.withValues(alpha: 0.55),
                  letterSpacing: isSelected ? 0.2 : 0,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CupertinoColors.white.withValues(alpha: 0.2)
                        : isDark
                            ? kAccent.withValues(alpha: 0.15)
                            : kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? CupertinoColors.white
                          : isDark
                              ? kAccent
                              : kPrimary,
                    ),
                  ),
                ),
              ] else ...[
                // Spacer to keep height consistent when badge is absent
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Section Date Header — clean iOS-style section title
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionDateHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionDateHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isToday = label == 'Today';

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          // Icon indicator
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isToday
                  ? kPrimary.withValues(alpha: 0.12)
                  : isDark
                      ? CupertinoColors.white.withValues(alpha: 0.06)
                      : CupertinoColors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isToday
                  ? CupertinoIcons.calendar_today
                  : label == 'Yesterday'
                      ? CupertinoIcons.clock
                      : CupertinoIcons.calendar,
              size: 14,
              color: isToday
                  ? kPrimary
                  : isDark
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.systemGrey2,
            ),
          ),
          const SizedBox(width: 10),
          // Label
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isToday
                  ? kPrimary
                  : isDark
                      ? CupertinoColors.white.withValues(alpha: 0.5)
                      : CupertinoColors.black.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          // Divider line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isToday ? kPrimary : CupertinoColors.systemGrey4)
                        .withValues(alpha: 0.3),
                    (isToday ? kPrimary : CupertinoColors.systemGrey4)
                        .withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Order Card — premium glassmorphic feel
// ═══════════════════════════════════════════════════════════════════════════════
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
    final cardColor   = isDark ? kDarkCard : CupertinoColors.white;
    final textColor   = isDark ? CupertinoColors.white : const Color(0xFF1A1A1A);
    final subtleColor = isDark ? const Color(0xFF8BAE8B) : CupertinoColors.systemGrey;
    final isDelivered = _statusIsDelivered(order.status);
    final stepIndex   = _statusToStep(order.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDelivered
                  ? CupertinoColors.black.withValues(alpha: isDark ? 0.12 : 0.04)
                  : kPrimary.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDelivered
                ? (isDark
                    ? CupertinoColors.white.withValues(alpha: 0.06)
                    : CupertinoColors.black.withValues(alpha: 0.04))
                : kPrimary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
              child: Row(
                children: [
                  // Status icon container
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDelivered
                            ? [
                                CupertinoColors.systemGreen.withValues(alpha: 0.15),
                                CupertinoColors.systemGreen.withValues(alpha: 0.06),
                              ]
                            : [
                                kPrimary.withValues(alpha: 0.15),
                                kPrimary.withValues(alpha: 0.06),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isDelivered
                          ? CupertinoIcons.checkmark_seal_fill
                          : CupertinoIcons.bag_fill,
                      size: 20,
                      color: isDelivered
                          ? CupertinoColors.systemGreen
                          : kPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemsSummary(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.time,
                              size: 11,
                              color: subtleColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(order.timestamp),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtleColor,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(stepIndex: stepIndex, status: order.status),
                ],
              ),
            ),

            // ── Thin divider ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(70, 12, 16, 0),
              child: Container(
                height: 0.5,
                color: isDark
                    ? CupertinoColors.white.withValues(alpha: 0.07)
                    : CupertinoColors.black.withValues(alpha: 0.06),
              ),
            ),

            // ── Item list (max 3 shown) ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                children: List.generate(
                  order.itemNames.length > 3 ? 3 : order.itemNames.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        // Numbered bullet
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isDark
                                ? CupertinoColors.white.withValues(alpha: 0.06)
                                : kPrimaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? kAccent : kPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            order.itemNames[i],
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quantity pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? CupertinoColors.white.withValues(alpha: 0.07)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '×${order.itemQuantities[i]}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: subtleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Price
                        Text(
                          '₱${formatPrice(order.itemPrices[i] * order.itemQuantities[i])}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kAccent : kPrimary,
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
                padding: const EdgeInsets.only(left: 46, bottom: 4),
                child: Text(
                  '+${order.itemNames.length - 3} more item${order.itemNames.length - 3 == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? CupertinoColors.systemGrey
                        : CupertinoColors.systemGrey2,
                  ),
                ),
              ),

            // ── Progress tracker (active orders only) ────────────────
            if (!isDelivered) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  height: 0.5,
                  color: isDark
                      ? CupertinoColors.white.withValues(alpha: 0.07)
                      : CupertinoColors.black.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _OrderProgress(stepIndex: stepIndex, isDark: isDark),
              ),
            ],

            const SizedBox(height: 10),

            // ── Footer ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.white.withValues(alpha: 0.03)
                    : kBackground.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Action link
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_right,
                          size: 12,
                          color: kPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isDelivered ? 'View details' : 'Track order',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                  // Price total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: subtleColor,
                        ),
                      ),
                      Text(
                        '₱${formatPrice(order.totalAmount, decimals: true)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: kPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _itemsSummary() {
    final count = order.itemNames.length;
    if (count == 1) return order.itemNames.first;
    return '${order.itemNames.first} + ${count - 1} more';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final h   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ap  = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min $ap';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Progress bar — 4 visible milestones
// ═══════════════════════════════════════════════════════════════════════════════
class _OrderProgress extends StatelessWidget {
  final int stepIndex;
  final bool isDark;
  const _OrderProgress({required this.stepIndex, required this.isDark});

  int get _compact {
    if (stepIndex >= 4) return 3;
    if (stepIndex >= 3) return 2;
    if (stepIndex >= 1) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Confirmed', 'Preparing', 'On the way', 'Arriving'];
    const icons  = [
      CupertinoIcons.checkmark_circle_fill,
      CupertinoIcons.flame_fill,
      CupertinoIcons.car_fill,
      CupertinoIcons.location_fill,
    ];
    const colors = [
      kPrimary,
      Color(0xFFF57C00),
      Color(0xFFF9A825),
      Color(0xFF7B1FA2),
    ];
    final cur = _compact;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = (i ~/ 2) < cur;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 2.5,
                decoration: BoxDecoration(
                  color: passed
                      ? colors[i ~/ 2]
                      : isDark
                          ? CupertinoColors.white.withValues(alpha: 0.08)
                          : CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }

        final si       = i ~/ 2;
        final isDone   = si < cur;
        final isActive = si == cur;
        final stageColor = colors[si];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: isActive ? 24 : 22,
              height: isActive ? 24 : 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? stageColor
                    : isActive
                        ? stageColor.withValues(alpha: 0.15)
                        : isDark
                            ? CupertinoColors.white.withValues(alpha: 0.06)
                            : CupertinoColors.systemGrey6,
                border: Border.all(
                  color: isActive
                      ? stageColor
                      : CupertinoColors.transparent,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: stageColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: isDone
                    ? const Icon(CupertinoIcons.checkmark,
                        size: 11, color: CupertinoColors.white)
                    : isActive
                        ? Icon(icons[si], size: 10, color: stageColor)
                        : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              labels[si],
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? stageColor
                    : isDone
                        ? (isDark ? CupertinoColors.white.withValues(alpha: 0.7) : CupertinoColors.black.withValues(alpha: 0.5))
                        : CupertinoColors.systemGrey,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Status Badge
// ═══════════════════════════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final int    stepIndex;
  final String status;
  const _StatusBadge({required this.stepIndex, required this.status});

  String get _label => switch (stepIndex) {
    5 => 'Delivered',
    4 => 'Almost there',
    3 => 'On the way',
    2 => 'Ready',
    1 => 'Preparing',
    _ => 'Confirmed',
  };

  Color get _color => switch (stepIndex) {
    5 => CupertinoColors.systemGreen,
    4 => CupertinoColors.systemPurple,
    3 => CupertinoColors.systemOrange,
    2 => CupertinoColors.systemBlue,
    1 => const Color(0xFFF57C00),
    _ => kPrimary,
  };

  IconData get _icon => switch (stepIndex) {
    5 => CupertinoIcons.checkmark_seal_fill,
    4 => CupertinoIcons.location_fill,
    3 => CupertinoIcons.arrow_right_circle_fill,
    2 => CupertinoIcons.bag_fill,
    1 => CupertinoIcons.flame_fill,
    _ => CupertinoIcons.checkmark_circle_fill,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.25), width: 0.5),
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

// ═══════════════════════════════════════════════════════════════════════════════
//  Empty state
// ═══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final int  segment;
  final bool isDark;
  const _EmptyState({required this.segment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final icon = switch (segment) {
      2 => CupertinoIcons.checkmark_seal,
      1 => CupertinoIcons.flame,
      _ => CupertinoIcons.bag,
    };

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
            // Layered icon
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? kDarkCard
                    : kPrimaryLight.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? kPrimary.withValues(alpha: 0.12)
                      : kPrimaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: kPrimary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? CupertinoColors.white
                    : const Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? CupertinoColors.systemGrey
                    : CupertinoColors.systemGrey2,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

