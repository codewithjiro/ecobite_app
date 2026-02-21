import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'models/food_item.dart';
import 'providers/cart_provider.dart';
import 'cart_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String _selectedCategory = 'All';

  List<FoodItem> get _filteredItems => _selectedCategory == 'All'
      ? FoodItem.menu
      : FoodItem.menu.where((f) => f.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('LamonGo 🍱'),
            backgroundColor: isDark
                ? kDarkBar.withValues(alpha: 0.9)
                : CupertinoColors.white.withValues(alpha: 0.9),
            trailing: GestureDetector(
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const CartPage()),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(CupertinoIcons.cart_fill, color: kPrimary, size: 26),
                  if (cart.totalCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.totalCount}',
                          style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: FoodItem.categories.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimary : cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected ? kPrimary : CupertinoColors.systemGrey4),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? CupertinoColors.white : textColor,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final food = _filteredItems[index];
                  return _FoodCard(
                    food: food,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                  );
                },
                childCount: _filteredItems.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final FoodItem food;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const _FoodCard({
    required this.food,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(food.id);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isDark ? CupertinoColors.black : kPrimary).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.network(
              food.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: CupertinoColors.systemGrey5,
                child: const Icon(CupertinoIcons.photo,
                    color: CupertinoColors.systemGrey2, size: 40),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    food.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${food.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: kPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (qty == 0)
                        GestureDetector(
                          onTap: () => context.read<CartProvider>().addItem(food),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                            child: const Icon(CupertinoIcons.add,
                                color: CupertinoColors.white, size: 16),
                          ),
                        )
                      else
                        Row(
                          children: [
                            _QtyButton(
                              icon: CupertinoIcons.minus,
                              onTap: () => context.read<CartProvider>().decrement(food.id),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('$qty',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      fontSize: 13)),
                            ),
                            _QtyButton(
                              icon: CupertinoIcons.add,
                              onTap: () => context.read<CartProvider>().increment(food.id),
                            ),
                          ],
                        ),
                    ],
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

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 12, color: kPrimary),
      ),
    );
  }
}