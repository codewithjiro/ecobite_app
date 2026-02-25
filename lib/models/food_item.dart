// ── Addon Model ──────────────────────────────────────────────────────────────
class Addon {
  final String name;
  final double price;

  const Addon({required this.name, required this.price});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Addon && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  Map<String, dynamic> toJson() => {'name': name, 'price': price};

  factory Addon.fromJson(Map<String, dynamic> json) =>
      Addon(name: json['name'] as String, price: (json['price'] as num).toDouble());
}

class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final String? badge;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.badge,
  });

  /// Addons available for this item based on its category.
  List<Addon> get availableAddons => addonsByCategory[category] ?? [];

  /// Category → available add-ons map
  static const Map<String, List<Addon>> addonsByCategory = {
    'Bowls': [
      Addon(name: 'Extra Rice', price: 20),
      Addon(name: 'Extra Chicken', price: 35),
      Addon(name: 'Extra Tofu', price: 25),
      Addon(name: 'Extra Sauce', price: 10),
      Addon(name: 'Soft-Boiled Egg', price: 20),
    ],
    'Salads': [
      Addon(name: 'Extra Dressing', price: 15),
      Addon(name: 'Grilled Chicken', price: 35),
      Addon(name: 'Avocado', price: 30),
      Addon(name: 'Croutons', price: 10),
      Addon(name: 'Feta Cheese', price: 20),
    ],
    'Wraps': [
      Addon(name: 'Extra Protein', price: 35),
      Addon(name: 'Extra Cheese', price: 20),
      Addon(name: 'Avocado', price: 30),
      Addon(name: 'Extra Sauce', price: 10),
      Addon(name: 'Side Salad', price: 25),
    ],
    'Snacks': [
      Addon(name: 'Extra Dip', price: 15),
      Addon(name: 'Pita Bread', price: 15),
      Addon(name: 'Honey Drizzle', price: 10),
      Addon(name: 'Granola Topping', price: 15),
    ],
    'Drinks': [
      Addon(name: 'Extra Shot', price: 20),
      Addon(name: 'Upsize', price: 25),
      Addon(name: 'Oat Milk', price: 20),
      Addon(name: 'Whipped Cream', price: 15),
      Addon(name: 'Flavor Syrup', price: 15),
    ],
  };

  // -------------------- ECOBITE MENU --------------------
  static const List<FoodItem> menu = [
    // ── Bowls ──────────────────────────────────────────
    FoodItem(
      id: 'bw1',
      name: 'Chicken Teriyaki Bowl',
      description: 'Grilled chicken glazed in house teriyaki, steamed brown rice, edamame & sesame seeds.',
      price: 175.0,
      imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
      category: 'Bowls',
      badge: '🥩 Protein',
    ),
    FoodItem(
      id: 'bw2',
      name: 'Tuna Poke Bowl',
      description: 'Sushi-grade tuna, seasoned sushi rice, cucumber, avocado, pickled ginger & ponzu drizzle.',
      price: 195.0,
      imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600',
      category: 'Bowls',
      badge: '🐟 Pescatarian',
    ),
    FoodItem(
      id: 'bw3',
      name: 'Tofu Veggie Bowl',
      description: 'Crispy baked tofu, quinoa, roasted seasonal veggies, kale & tahini miso dressing.',
      price: 155.0,
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600',
      category: 'Bowls',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'bw4',
      name: 'Salmon Citrus Bowl',
      description: 'Pan-seared salmon, jasmine rice, pickled radish, cucumber ribbons & yuzu ponzu.',
      price: 210.0,
      imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600',
      category: 'Bowls',
      badge: '🐟 Pescatarian',
    ),
    FoodItem(
      id: 'bw5',
      name: 'Beef & Broccoli Bowl',
      description: 'Tender sliced beef, charred broccolini, garlic ginger sauce over steamed white rice.',
      price: 185.0,
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600',
      category: 'Bowls',
      badge: '🥩 Protein',
    ),

    // ── Salads ─────────────────────────────────────────
    FoodItem(
      id: 'sl1',
      name: 'Caesar Salad',
      description: 'Crisp romaine, parmesan shavings, house-made Caesar dressing & whole-grain croutons.',
      price: 130.0,
      imageUrl: 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=600',
      category: 'Salads',
      badge: '🥗 Veggie',
    ),
    FoodItem(
      id: 'sl2',
      name: 'Asian Sesame Salad',
      description: 'Mixed greens, shredded purple cabbage, mandarin, toasted almonds & ginger sesame vinaigrette.',
      price: 140.0,
      imageUrl: 'https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?w=600',
      category: 'Salads',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'sl3',
      name: 'Mango Chicken Salad',
      description: 'Grilled chicken strips, fresh mango, arugula, cherry tomatoes & honey-lime dressing.',
      price: 155.0,
      imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=600',
      category: 'Salads',
      badge: '🥩 Protein',
    ),
    FoodItem(
      id: 'sl4',
      name: 'Greek Garden Salad',
      description: 'Cucumber, kalamata olives, cherry tomatoes, feta, red onion & herb vinaigrette.',
      price: 125.0,
      imageUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600',
      category: 'Salads',
      badge: '🥗 Veggie',
    ),
    FoodItem(
      id: 'sl5',
      name: 'Kale Power Salad',
      description: 'Massaged kale, roasted chickpeas, avocado, pumpkin seeds & lemon tahini dressing.',
      price: 145.0,
      imageUrl: 'https://images.unsplash.com/photo-1607532941433-304659e8198a?w=600',
      category: 'Salads',
      badge: '🌱 Vegan',
    ),

    // ── Wraps ──────────────────────────────────────────
    FoodItem(
      id: 'wr1',
      name: 'Chicken Pesto Wrap',
      description: 'Grilled chicken, fresh basil pesto, sun-dried tomatoes, baby spinach in a whole-wheat wrap.',
      price: 145.0,
      imageUrl: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600',
      category: 'Wraps',
      badge: '🥩 Protein',
    ),
    FoodItem(
      id: 'wr2',
      name: 'Tuna Melt',
      description: 'Wild-caught tuna, melted low-fat cheese, capers, red onion & whole-grain sourdough.',
      price: 160.0,
      imageUrl: 'https://images.unsplash.com/photo-1528736235302-52922df5c122?w=600',
      category: 'Wraps',
      badge: '🐟 Pescatarian',
    ),
    FoodItem(
      id: 'wr3',
      name: 'Falafel Wrap',
      description: 'Crispy falafel, hummus, shredded lettuce, tomato, pickled turnip & tahini in a pita wrap.',
      price: 135.0,
      imageUrl: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=600',
      category: 'Wraps',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'wr4',
      name: 'Turkey Avocado Wrap',
      description: 'Smoked turkey, smashed avocado, arugula, dijon mustard & whole-wheat tortilla.',
      price: 155.0,
      imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600',
      category: 'Wraps',
      badge: '🥩 Protein',
    ),

    // ── Snacks ─────────────────────────────────────────
    FoodItem(
      id: 'sn1',
      name: 'Yogurt Parfait',
      description: 'Greek yogurt layered with organic granola, seasonal berries & local honey drizzle.',
      price: 95.0,
      imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600',
      category: 'Snacks',
      badge: '🌿 Clean',
    ),
    FoodItem(
      id: 'sn2',
      name: 'Granola Bar',
      description: 'House-baked oat & nut bar with dark chocolate chips, chia seeds and no refined sugar.',
      price: 65.0,
      imageUrl: 'https://images.unsplash.com/photo-1571748982800-fa51082c2224?w=600',
      category: 'Snacks',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'sn3',
      name: 'Fruit Cup',
      description: 'Seasonal fresh-cut fruits — mango, melon, pineapple & kiwi with a citrus-mint glaze.',
      price: 80.0,
      imageUrl: 'https://images.unsplash.com/photo-1568308853224-1f17b4084076?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      category: 'Snacks',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'sn4',
      name: 'Avocado Toast Bites',
      description: 'Mini whole-grain toast rounds topped with smashed avocado, chili flakes & microgreens.',
      price: 90.0,
      imageUrl: 'https://images.unsplash.com/photo-1741732667053-0abb166c66b9?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8N3x8QXZvY2FkbyUyMFRvYXN0JTIwQml0ZXN8ZW58MHx8MHx8fDA%3D',
      category: 'Snacks',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'sn5',
      name: 'Edamame Bowl',
      description: 'Steamed edamame tossed in sea salt, chili oil & toasted sesame — served warm.',
      price: 70.0,
      imageUrl: 'https://images.unsplash.com/photo-1768326119213-e0ad875083a3?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTB8fEVkYW1hbWUlMjBCb3dsfGVufDB8fDB8fHww',
      category: 'Snacks',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'sn6',
      name: 'Hummus & Veggie Plate',
      description: 'House-made hummus with cucumber sticks, baby carrots, cherry tomatoes & warm pita.',
      price: 100.0,
      imageUrl: 'https://images.unsplash.com/photo-1577906096429-f73c2c312435?w=600',
      category: 'Snacks',
      badge: '🌱 Vegan',
    ),

    // ── Drinks ─────────────────────────────────────────
    FoodItem(
      id: 'dr1',
      name: 'Cold Brew',
      description: 'Slow-steeped 18-hour cold brew, served over ice. Smooth, bold, no bitterness.',
      price: 110.0,
      imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=600',
      category: 'Drinks',
      badge: '☕ Caffeine',
    ),
    FoodItem(
      id: 'dr2',
      name: 'Matcha Latte',
      description: 'Ceremonial-grade matcha blended with oat milk and a touch of agave. Iced or hot.',
      price: 120.0,
      imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=600',
      category: 'Drinks',
      badge: '🍵 Antioxidants',
    ),
    FoodItem(
      id: 'dr3',
      name: 'Green Juice',
      description: 'Cold-pressed spinach, cucumber, green apple, ginger & lemon. Zero added sugar.',
      price: 105.0,
      imageUrl: 'https://images.unsplash.com/photo-1610970881699-44a5587cabec?w=600',
      category: 'Drinks',
      badge: '🌱 Detox',
    ),
    FoodItem(
      id: 'dr4',
      name: 'Mango Lassi',
      description: 'Thick blended Alphonso mango with probiotic yogurt, cardamom & a pinch of saffron.',
      price: 115.0,
      imageUrl: 'https://images.unsplash.com/photo-1527661591475-527312dd65f5?w=600',
      category: 'Drinks',
      badge: '🥭 Fresh',
    ),
    FoodItem(
      id: 'dr5',
      name: 'Coconut Chia Cooler',
      description: 'Chilled coconut water loaded with chia seeds, lime juice & a splash of pandan syrup.',
      price: 95.0,
      imageUrl: 'https://images.unsplash.com/photo-1625535927032-dd38fdf54f84?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8Q29jb251dCUyMENoaWElMjBDb29sZXJ8ZW58MHx8MHx8fDA%3D',
      category: 'Drinks',
      badge: '🌱 Vegan',
    ),
    FoodItem(
      id: 'dr6',
      name: 'Berry Hibiscus Iced Tea',
      description: 'Brewed hibiscus tea shaken with mixed berry purée, honey & fresh mint over crushed ice.',
      price: 100.0,
      imageUrl: 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=600',
      category: 'Drinks',
      badge: '🌸 Antioxidants',
    ),
  ];

  static List<String> get categories =>
      ['All', 'Bowls', 'Salads', 'Wraps', 'Snacks', 'Drinks'];
}
