import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  late String _cachedGreeting;

  // ── Search ──────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _cachedGreeting = _buildGreeting();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    _searchFocus.requestFocus();
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _searchFocus.unfocus();
  }

  List<FoodItem> get _filteredItems {
    List<FoodItem> items = _selectedCategory == 'All'
        ? FoodItem.menu
        : FoodItem.menu.where((f) => f.category == _selectedCategory).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((f) =>
          f.name.toLowerCase().contains(q) ||
          f.description.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q) ||
          (f.badge?.toLowerCase().contains(q) ?? false)).toList();
    }
    return items;
  }

  // Reads Hive once — cached in initState
  String _buildGreeting() {
    final raw = Hive.box(kBoxDatabase).get('username') as String? ?? '';
    final name = raw.isEmpty ? '' : raw[0].toUpperCase() + raw.substring(1);
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return name.isEmpty ? '$part! 👋' : '$part, $name! 👋';
  }

  // Called from build — uses cache
  String _greeting() => _cachedGreeting;

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Bowls':   return CupertinoIcons.circle_grid_hex_fill;
      case 'Salads':  return CupertinoIcons.leaf_arrow_circlepath;
      case 'Wraps':   return CupertinoIcons.layers_fill;
      case 'Snacks':  return CupertinoIcons.star_fill;
      case 'Drinks':  return CupertinoIcons.drop_fill;
      default:        return CupertinoIcons.square_grid_2x2_fill;
    }
  }

  void _openItemDetail(BuildContext context, FoodItem food) {
    final brightness = CupertinoTheme.of(context).brightness;
    showCupertinoModalPopup(
      context: context,
      builder: (modalCtx) => CupertinoTheme(
        data: CupertinoThemeData(brightness: brightness),
        child: _ItemDetailSheet(food: food),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final bgColor = isDark ? kDarkBackground : kBackground;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Nav Bar ──────────────────────────────────────────────
          CupertinoSliverNavigationBar(
            largeTitle: const Row(
              children: [
                SizedBox(width: 4),
                Text('EcoBite',
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    )),
              ],
            ),
            backgroundColor: isDark
                ? kDarkBar.withValues(alpha: 0.95)
                : CupertinoColors.white.withValues(alpha: 0.92),
            trailing: GestureDetector(
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const CartPage()),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.cart_fill,
                        color: kPrimary, size: 22),
                  ),
                  if (cart.totalCount > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
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

          // ── Search Bar ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      placeholder: 'Search dishes, categories...',
                      onTap: () {
                        if (!_isSearching) _startSearch();
                      },
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                      ),
                      backgroundColor: isDark
                          ? const Color(0xFF1A2E1C)
                          : CupertinoColors.white,
                      itemColor: isDark
                          ? const Color(0xFF8BAE8B)
                          : CupertinoColors.systemGrey,
                      placeholderStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF5C7F5C)
                            : CupertinoColors.systemGrey,
                        fontSize: 15,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      prefixInsets:
                          const EdgeInsets.only(left: 10, right: 4),
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _cancelSearch,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: kPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Hero Welcome Card (hidden during search) ──────────────
          if (!_isSearching) ...[
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A4D1E), const Color(0xFF0A2010)]
                      : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: isDark ? 0.28 : 0.38),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Large decorative circle — top right
                  Positioned(
                    right: -36,
                    top: -36,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  // Small decorative circle — bottom left
                  Positioned(
                    left: -20,
                    bottom: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Main content row (text + emoji side by side)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 16, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Text column — fills available space
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _greeting(),
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'What are you eating today?',
                                style: TextStyle(
                                  color: CupertinoColors.white
                                      .withValues(alpha: 0.72),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Pills
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: const [
                                  _HeroPill(icon: '🌱', label: 'Eco-friendly'),
                                  _HeroPill(icon: '🛍', label: 'Low plastic'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Emoji — fixed width, never pushes text
                        const SizedBox(width: 12),
                        const Text(
                          '🥗',
                          style: TextStyle(fontSize: 64),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Stats Row ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _StatCard(
                    emoji: '🍽',
                    value: '${FoodItem.menu.length}',
                    label: 'Menu Items',
                    isDark: isDark,
                    cardColor: cardColor,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    emoji: '🥗',
                    value: '${FoodItem.categories.length - 1}',
                    label: 'Categories',
                    isDark: isDark,
                    cardColor: cardColor,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    emoji: '⚡',
                    value: '~30',
                    label: 'Min Delivery',
                    isDark: isDark,
                    cardColor: cardColor,
                  ),
                ],
              ),
            ),
          ),
          ], // end if (!_isSearching)

          // ── Section label: Menu ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Search Results'
                            : 'Our Menu',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'for "$_searchQuery"'
                            : 'Fresh & made to order',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF8BAE8B)
                              : CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_filteredItems.length} items',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Category Chips ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: FoodItem.categories.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kPrimary
                              : (isDark
                                  ? const Color(0xFF1A2E1C)
                                  : CupertinoColors.white),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? kPrimary
                                : (isDark
                                    ? const Color(0xFF2E4E2E)
                                    : const Color(0xFFD8EDD8)),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: kPrimary.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [
                                  BoxShadow(
                                    color: CupertinoColors.black
                                        .withValues(alpha: isDark ? 0.0 : 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _categoryIcon(cat),
                              size: 13,
                              color: isSelected
                                  ? CupertinoColors.white
                                  : (isDark ? kAccent : kPrimary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                color: isSelected
                                    ? CupertinoColors.white
                                    : textColor,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // ── Food Grid / Empty Search ────────────────────────────
          if (_filteredItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.search,
                          size: 44, color: kPrimary),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No dishes found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try a different keyword or category',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF8BAE8B)
                            : CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final food = _filteredItems[index];
                    return _FoodCard(
                      food: food,
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                      onTap: () => _openItemDetail(context, food),
                    );
                  },
                  childCount: _filteredItems.length,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 72,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Pill ─────────────────────────────────────────────────────────────────
class _HeroPill extends StatelessWidget {
  final String icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.white.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool isDark;
  final Color cardColor;
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.isDark,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black
                  .withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A3E2A)
                : const Color(0xFFE8F5E9),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: kPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF8BAE8B)
                    : CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Food Card ─────────────────────────────────────────────────────────────────
class _FoodCard extends StatelessWidget {
  final FoodItem food;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;

  const _FoodCard({
    required this.food,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(food.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black
                  .withValues(alpha: isDark ? 0.25 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    food.imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: const Icon(
                          CupertinoIcons.leaf_arrow_circlepath,
                          color: kPrimary,
                          size: 36),
                    ),
                  ),
                ),
                // Eco badge
                if (food.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF1B5E20).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        food.badge!,
                        style: const TextStyle(
                          color: Color(0xFFB9F6CA),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                // Cart qty badge
                if (qty > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimary.withValues(alpha: 0.4),
                              blurRadius: 6)
                        ],
                      ),
                      child: Text(
                        '$qty in cart',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Details ────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      food.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? const Color(0xFF8BAE8B)
                            : CupertinoColors.systemGrey,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₱${formatPrice(food.price)}',
                              style: const TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            qty > 0
                                ? CupertinoIcons.pencil
                                : CupertinoIcons.add,
                            color: CupertinoColors.white,
                            size: 15,
                          ),
                        ),
                      ],
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

// ── Item Detail Bottom Sheet ───────────────────────────────────────────────────
class _ItemDetailSheet extends StatefulWidget {
  final FoodItem food;
  const _ItemDetailSheet({required this.food});

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  int _qty = 1;
  bool _isLoading = false;
  final Set<Addon> _selectedAddons = {};

  double get _addonsTotal =>
      _selectedAddons.fold(0.0, (sum, a) => sum + a.price);
  double get _total => (widget.food.price + _addonsTotal) * _qty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      final cartItem = cart.getItem(widget.food.id);
      if (cartItem != null) {
        setState(() {
          _qty = cartItem.quantity;
          _selectedAddons.addAll(cartItem.selectedAddons);
        });
      }
    });
  }

  void _decrement() {
    if (_qty > 1 && !_isLoading) setState(() => _qty--);
  }

  void _increment() {
    if (!_isLoading) setState(() => _qty++);
  }

  Future<void> _addToCart(BuildContext context) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Capture everything from context BEFORE the async gap
    final cart = context.read<CartProvider>();
    final nav = Navigator.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final currentQty = cart.quantityOf(widget.food.id);
    final addonsList = _selectedAddons.toList();
    if (currentQty == 0) {
      for (int i = 0; i < _qty; i++) { cart.addItem(widget.food, addons: addonsList); }
    } else {
      // Update addons first
      cart.updateAddons(widget.food.id, addonsList);
      final diff = _qty - currentQty;
      if (diff > 0) {
        for (int i = 0; i < diff; i++) { cart.increment(widget.food.id); }
      } else if (diff < 0) {
        for (int i = 0; i < diff.abs(); i++) { cart.decrement(widget.food.id); }
      }
    }

    nav.pop();

    // Show overlay toast — no blur, no route, no backdrop
    _showCartOverlayToast(overlay, widget.food.name, _qty);
  }

  static void _showCartOverlayToast(OverlayState overlay, String name, int qty) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CartOverlayToast(
        itemName: name,
        qty: qty,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cartQty = context.watch<CartProvider>().quantityOf(widget.food.id);
    final isUpdate = cartQty > 0;
    final bgColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);
    final subColor = isDark ? const Color(0xFF8BAE8B) : CupertinoColors.systemGrey;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero Image ─────────────────
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            child: Image.network(
                              widget.food.imageUrl,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, e, s) => Container(
                                height: 240,
                                color: kPrimaryLight,
                                child: const Icon(CupertinoIcons.leaf_arrow_circlepath,
                                    color: kPrimary, size: 60),
                              ),
                            ),
                          ),
                          // Close button
                          Positioned(
                            top: 14,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.xmark,
                                    color: CupertinoColors.white, size: 16),
                              ),
                            ),
                          ),
                          // Badge
                          if (widget.food.badge != null)
                            Positioned(
                              bottom: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20).withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.food.badge!,
                                  style: const TextStyle(
                                    color: Color(0xFFB9F6CA),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // ── Info ──────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.food.name,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '₱${formatPrice(widget.food.price)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: kPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.food.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: subColor,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Add-ons Section ──────
                            if (widget.food.availableAddons.isNotEmpty) ...[
                              Text(
                                'Add-ons',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...widget.food.availableAddons.map((addon) {
                                final selected = _selectedAddons.contains(addon);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        _selectedAddons.remove(addon);
                                      } else {
                                        _selectedAddons.add(addon);
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? kPrimary.withValues(alpha: 0.08)
                                          : (isDark
                                              ? const Color(0xFF0F1F10)
                                              : const Color(0xFFF5FAF5)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? kPrimary
                                            : (isDark
                                                ? const Color(0xFF2E4E2E)
                                                : const Color(0xFFD8EDD8)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? kPrimary
                                                : (isDark
                                                    ? const Color(0xFF2A3E2A)
                                                    : const Color(0xFFE8F5E9)),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: selected
                                                ? null
                                                : Border.all(
                                                    color: CupertinoColors
                                                        .systemGrey3,
                                                    width: 1.5),
                                          ),
                                          child: selected
                                              ? const Icon(
                                                  CupertinoIcons.checkmark,
                                                  color:
                                                      CupertinoColors.white,
                                                  size: 14)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            addon.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '+ ₱${formatPrice(addon.price)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? kPrimary
                                                : subColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                            ],

                            // ── Divider ────────────
                            Container(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF2A3E2A)
                                  : const Color(0xFFE8F5E9),
                            ),
                            const SizedBox(height: 20),

                            // ── Qty selector ───────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F1F10)
                                        : const Color(0xFFF0FAF0),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2E5E2E)
                                          : const Color(0xFFC8E6C9),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Minus
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        onPressed: _qty > 1 ? _decrement : null,
                                        child: Icon(
                                          CupertinoIcons.minus,
                                          size: 18,
                                          color: _qty > 1 ? kPrimary : CupertinoColors.systemGrey3,
                                        ),
                                      ),
                                      // Count
                                      SizedBox(
                                        width: 36,
                                        child: Text(
                                          '$_qty',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      // Plus
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        onPressed: _increment,
                                        child: const Icon(CupertinoIcons.add, size: 18, color: kPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sticky CTA ────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF2A3E2A)
                          : const Color(0xFFE8F5E9),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: kPrimary,
                    disabledColor: kPrimary,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _isLoading ? null : () => _addToCart(context),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isLoading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              height: 22,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                    radius: 10,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Adding...',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              key: const ValueKey('idle'),
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isUpdate ? 'Update Cart' : 'Add to Cart',
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.white
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₱${formatPrice(_total)}',
                                    style: const TextStyle(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Cart Added Toast (Overlay — no blur, no backdrop) ────────────────────────
class _CartOverlayToast extends StatefulWidget {
  final String itemName;
  final int qty;
  final VoidCallback onDone;
  const _CartOverlayToast({
    required this.itemName,
    required this.qty,
    required this.onDone,
  });

  @override
  State<_CartOverlayToast> createState() => _CartOverlayToastState();
}

class _CartOverlayToastState extends State<_CartOverlayToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    // Auto-dismiss after 1.8s
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDone());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 110,
      left: 32,
      right: 32,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Color(0xFFB9F6CA), size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '${widget.qty}× ${widget.itemName} added!',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

