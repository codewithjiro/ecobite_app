class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
  });

  // -------------------- HARDCODED FOOD LIST --------------------
  static const List<FoodItem> menu = [
    // Rice Meals
    FoodItem(
      id: 'rm1',
      name: 'Chicken Adobo',
      description: 'Classic Filipino chicken braised in soy sauce & vinegar, served with steamed rice.',
      price: 89.0,
      imageUrl: 'https://images.unsplash.com/photo-1598103442097-8b74394b95c4?w=400',
      category: 'Rice Meals',
    ),
    FoodItem(
      id: 'rm2',
      name: 'Pork Sinigang',
      description: 'Sour tamarind soup with tender pork ribs and fresh vegetables.',
      price: 99.0,
      imageUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=400',
      category: 'Rice Meals',
    ),
    FoodItem(
      id: 'rm3',
      name: 'Beef Caldereta',
      description: 'Rich tomato-based beef stew with potatoes, carrots, and bell peppers.',
      price: 119.0,
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
      category: 'Rice Meals',
    ),
    FoodItem(
      id: 'rm4',
      name: 'Lechon Kawali',
      description: 'Crispy deep-fried pork belly served with liver sauce and rice.',
      price: 109.0,
      imageUrl: 'https://images.unsplash.com/photo-1558030006-450675393462?w=400',
      category: 'Rice Meals',
    ),
    // Snacks
    FoodItem(
      id: 'sn1',
      name: 'Lumpia Shanghai',
      description: 'Crispy Filipino spring rolls filled with seasoned ground pork (6 pcs).',
      price: 59.0,
      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=400',
      category: 'Snacks',
    ),
    FoodItem(
      id: 'sn2',
      name: 'Kwek-Kwek',
      description: 'Deep-fried quail eggs coated in orange batter, served with vinegar dip.',
      price: 39.0,
      imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400',
      category: 'Snacks',
    ),
    FoodItem(
      id: 'sn3',
      name: 'Banana Cue',
      description: 'Skewered caramelized banana with brown sugar, a classic Filipino street food.',
      price: 29.0,
      imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400',
      category: 'Snacks',
    ),
    FoodItem(
      id: 'sn4',
      name: 'Chicken Inasal',
      description: 'Grilled marinated chicken skewers with calamansi and annatto oil.',
      price: 79.0,
      imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400',
      category: 'Snacks',
    ),
    // Drinks
    FoodItem(
      id: 'dr1',
      name: 'Sago\'t Gulaman',
      description: 'Refreshing sweet drink with sago pearls, gulaman jelly, and brown sugar syrup.',
      price: 35.0,
      imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400',
      category: 'Drinks',
    ),
    FoodItem(
      id: 'dr2',
      name: 'Buko Juice',
      description: 'Fresh young coconut juice with coconut strips. Naturally sweet and refreshing.',
      price: 45.0,
      imageUrl: 'https://images.unsplash.com/photo-1502741224143-90386d7f8c82?w=400',
      category: 'Drinks',
    ),
    FoodItem(
      id: 'dr3',
      name: 'Calamansi Juice',
      description: 'Freshly squeezed Filipino lime juice, lightly sweetened and served cold.',
      price: 30.0,
      imageUrl: 'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400',
      category: 'Drinks',
    ),
    FoodItem(
      id: 'dr4',
      name: 'Mais con Yelo',
      description: 'Shaved ice dessert drink with sweet corn kernels, milk, and sugar.',
      price: 40.0,
      imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400',
      category: 'Drinks',
    ),
  ];

  static List<String> get categories => ['All', 'Rice Meals', 'Snacks', 'Drinks'];
}

