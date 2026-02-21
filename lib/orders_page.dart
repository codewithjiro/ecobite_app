import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'models/order_model.dart';
import 'tracking_page.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('My Orders'),
            backgroundColor: isDark
                ? kDarkBar.withValues(alpha: 0.9)
                : CupertinoColors.white.withValues(alpha: 0.9),
          ),
          SliverToBoxAdapter(
            child: ValueListenableBuilder(
              valueListenable:
                  Hive.box<OrderModel>(kBoxOrders).listenable(),
              builder: (context, Box<OrderModel> box, _) {
                final orders = box.values.toList().reversed.toList();

                if (orders.isEmpty) {
                  return SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.bag,
                              size: 72,
                              color: CupertinoColors.systemGrey3),
                          const SizedBox(height: 16),
                          Text('No orders yet',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                          const SizedBox(height: 8),
                          const Text('Your order history will appear here.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => TrackingPage(order: order),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black
                                  .withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(order.timestamp),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.systemGrey),
                                ),
                                _StatusBadge(status: order.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Items
                            ...List.generate(
                              order.itemNames.length,
                              (i) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '• ${order.itemNames[i]} x${order.itemQuantities[i]}',
                                  style: TextStyle(
                                      fontSize: 13, color: textColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Total
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textColor)),
                                Text(
                                  '₱${order.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: kPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    if (status.contains('Delivered')) return CupertinoColors.systemGreen;
    if (status.contains('on the way')) return CupertinoColors.systemOrange;
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _color),
      ),
    );
  }
}

