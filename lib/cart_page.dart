import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'providers/cart_provider.dart';
import 'checkout_page.dart'; // Phase 4 - Checkout

class CartPage extends StatelessWidget {
  const CartPage({super.key});

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
        middle: const Text('My Cart'),
        backgroundColor: isDark
            ? kDarkBar.withValues(alpha: 0.9)
            : CupertinoColors.white.withValues(alpha: 0.9),
        trailing: cart.items.isEmpty
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _confirmClear(context, cart),
                child: const Text('Clear',
                    style: TextStyle(color: CupertinoColors.systemRed)),
              ),
      ),
      child: SafeArea(
        child: cart.items.isEmpty
            ? _buildEmpty(textColor)
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.foodItem.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: CupertinoColors.systemGrey5,
                                    child: const Icon(CupertinoIcons.photo,
                                        size: 24,
                                        color: CupertinoColors.systemGrey2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.foodItem.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: textColor)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₱${item.foodItem.price.toStringAsFixed(0)} each',
                                      style: const TextStyle(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity controls
                              Row(
                                children: [
                                  _QtyBtn(
                                    icon: CupertinoIcons.minus,
                                    onTap: () => context
                                        .read<CartProvider>()
                                        .decrement(item.foodItem.id),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('${item.quantity}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: textColor)),
                                  ),
                                  _QtyBtn(
                                    icon: CupertinoIcons.add,
                                    onTap: () => context
                                        .read<CartProvider>()
                                        .increment(item.foodItem.id),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              // Subtotal
                              Text(
                                '₱${item.subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // ── Total & Checkout ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                            Text(
                              '₱${cart.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: kPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (_) => const CheckoutPage()),
                            ),
                            child: const Text(
                              'Proceed to Checkout',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.white),
                            ),
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

  Widget _buildEmpty(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.cart,
              size: 72, color: CupertinoColors.systemGrey3),
          const SizedBox(height: 16),
          Text('Your cart is empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          const SizedBox(height: 8),
          const Text('Add some delicious food to get started!',
              style: TextStyle(
                  fontSize: 13, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: kPrimary),
      ),
    );
  }
}


