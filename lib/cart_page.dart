import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'models/cart_item.dart';
import 'providers/cart_provider.dart';
import 'checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          cart.items.isEmpty ? 'My Cart' : 'My Cart (${cart.totalCount})',
          style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimary),
        ),
        backgroundColor: isDark
            ? kDarkBar.withValues(alpha: 0.95)
            : CupertinoColors.white.withValues(alpha: 0.92),
        trailing: cart.items.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => cart.allSelected
                        ? cart.deselectAll()
                        : cart.selectAll(),
                    child: Text(
                      cart.allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(color: kPrimary, fontSize: 13),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4),
                    onPressed: () => _confirmClear(context, cart),
                    child: const Icon(CupertinoIcons.trash,
                        color: CupertinoColors.systemRed, size: 18),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: cart.items.isEmpty
            ? _buildEmpty(context, isDark, textColor)
            : Column(
                children: [
                  // ── Item list ────────────────────────────────────
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return _CartItemRow(
                          item: item,
                          isDark: isDark,
                          cardColor: cardColor,
                          textColor: textColor,
                        );
                      },
                    ),
                  ),

                  // ── Order summary + CTA ──────────────────────────
                  _OrderSummaryPanel(
                    cart: cart,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isDark, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.cart,
                size: 56, color: kPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse the menu and add\nsomething delicious!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 28),
          CupertinoButton(
            color: kPrimary,
            borderRadius: BorderRadius.circular(14),
            onPressed: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Browse Menu',
                  style: TextStyle(
                      color: CupertinoColors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    final hasSelected = cart.selectedItems.isNotEmpty;
    final selectedCount = cart.selectedCount;

    if (hasSelected) {
      // May naka-check → direct confirmation para sa selected lang
      showThemedDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete Selected?'),
          content: Text(
            'Remove $selectedCount selected item${selectedCount == 1 ? '' : 's'} from your cart?',
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                cart.clearSelected();
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete Selected'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else {
      // Walang naka-check → Delete All lang
      showThemedDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete All?'),
          content: const Text('Remove all items from your cart?'),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                cart.clearCart();
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete All'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }
}

// ── Cart Item Row (swipe to delete) ───────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const _CartItemRow({
    required this.item,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.foodItem.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        bool confirmed = false;
        await showThemedDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Remove Item?'),
            content: Text(
                'Remove "${item.foodItem.name}" from your cart?'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  confirmed = true;
                  Navigator.of(ctx).pop();
                },
                child: const Text('Remove'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        return confirmed;
      },
      onDismissed: (_) =>
          context.read<CartProvider>().removeItem(item.foodItem.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.trash_fill, color: CupertinoColors.white, size: 22),
            SizedBox(height: 4),
            Text('Remove',
                style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: isDark ? 0.10 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selection checkbox
            GestureDetector(
              onTap: () => context
                  .read<CartProvider>()
                  .toggleSelection(item.foodItem.id),
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    final selected = cart.isSelected(item.foodItem.id);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected
                            ? kPrimary
                            : (isDark
                                ? const Color(0xFF2A3E2A)
                                : const Color(0xFFE8F5E9)),
                        borderRadius: BorderRadius.circular(6),
                        border: selected
                            ? null
                            : Border.all(
                                color: CupertinoColors.systemGrey3,
                                width: 1.5),
                      ),
                      child: selected
                          ? const Icon(CupertinoIcons.checkmark,
                              color: CupertinoColors.white, size: 14)
                          : null,
                    );
                  },
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.foodItem.imageUrl,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (context, e, s) => Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.leaf_arrow_circlepath,
                      color: kPrimary, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.foodItem.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: textColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₱${formatPrice(item.foodItem.price)} each',
                    style: const TextStyle(
                        color: CupertinoColors.systemGrey, fontSize: 12),
                  ),
                  if (item.selectedAddons.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.selectedAddons.map((a) => '+ ${a.name}').join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF8BAE8B)
                            : CupertinoColors.systemGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Subtotal
                  Text(
                    '₱${formatPrice(item.subtotal)}',
                    style: const TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ],
              ),
            ),

            // Qty stepper
            _QtyStepper(foodId: item.foodItem.id, qty: item.quantity, textColor: textColor),
          ],
        ),
      ),
    );
  }
}

// ── Quantity Stepper ──────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  final String foodId;
  final int qty;
  final Color textColor;
  const _QtyStepper(
      {required this.foodId, required this.qty, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StepBtn(
          icon: CupertinoIcons.add,
          onTap: () => context.read<CartProvider>().increment(foodId),
        ),
        const SizedBox(height: 6),
        Text(
          '$qty',
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
        ),
        const SizedBox(height: 6),
        _StepBtn(
          icon: CupertinoIcons.minus,
          onTap: () => context.read<CartProvider>().decrement(foodId),
          isDestructive: qty <= 1,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  const _StepBtn(
      {required this.icon, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFE53935) : kPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ── Order Summary Panel ───────────────────────────────────────────────────────
class _OrderSummaryPanel extends StatelessWidget {
  final CartProvider cart;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const _OrderSummaryPanel({
    required this.cart,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    const deliveryFee = 0.0; // free delivery for now
    final subtotal = cart.selectedTotal;
    final total = subtotal + deliveryFee;
    final hasSelection = cart.selectedItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Selected items label
          Row(
            children: [
              const SizedBox(width: 5),
              Text(
                hasSelection
                    ? '${cart.selectedCount} item${cart.selectedCount == 1 ? '' : 's'} selected'
                    : 'No items selected',
                style: const TextStyle(
                    fontSize: 12, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subtotal row
          _SummaryRow(
            label: 'Subtotal',
            value: '₱${formatPrice(subtotal, decimals: true)}',
            textColor: textColor,
          ),
          const SizedBox(height: 6),

          // Delivery row
          _SummaryRow(
            label: 'Delivery',
            value: deliveryFee == 0.0 ? '🌿 Free' : '₱${deliveryFee.toStringAsFixed(0)}',
            textColor: deliveryFee == 0.0 ? kPrimary : textColor,
            valueColor: deliveryFee == 0.0 ? kPrimary : null,
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: isDark ? const Color(0xFF2A3E2A) : const Color(0xFFE8F5E9)),
          const SizedBox(height: 12),

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: textColor)),
              Text(
                '₱${formatPrice(total, decimals: true)}',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checkout button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: hasSelection ? kPrimary : CupertinoColors.systemGrey3,
              borderRadius: BorderRadius.circular(16),
              onPressed: hasSelection
                  ? () => Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const CheckoutPage()),
                      )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(CupertinoIcons.creditcard, color: CupertinoColors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Proceed to Checkout',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.white,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color? valueColor;
  const _SummaryRow(
      {required this.label,
      required this.value,
      required this.textColor,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? textColor)),
      ],
    );
  }
}
