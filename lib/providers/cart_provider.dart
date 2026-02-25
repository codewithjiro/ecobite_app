import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../models/cart_item.dart';
import '../models/food_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final Set<String> _selectedIds = {};

  CartProvider() {
    _loadFromHive();
  }

  List<CartItem> get items => List.unmodifiable(_items);
  int get totalCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get total => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  // ── Selection ─────────────────────────────────────────────────────────────

  bool isSelected(String foodId) => _selectedIds.contains(foodId);
  bool get allSelected =>
      _items.isNotEmpty && _items.every((i) => _selectedIds.contains(i.foodItem.id));
  List<CartItem> get selectedItems =>
      _items.where((i) => _selectedIds.contains(i.foodItem.id)).toList();
  int get selectedCount => selectedItems.fold(0, (sum, i) => sum + i.quantity);
  double get selectedTotal =>
      selectedItems.fold(0.0, (sum, i) => sum + i.subtotal);

  void toggleSelection(String foodId) {
    if (_selectedIds.contains(foodId)) {
      _selectedIds.remove(foodId);
    } else {
      _selectedIds.add(foodId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.addAll(_items.map((i) => i.foodItem.id));
    notifyListeners();
  }

  void deselectAll() {
    _selectedIds.clear();
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  void _loadFromHive() {
    try {
      final box = Hive.box(kBoxDatabase);
      final raw = box.get('cart') as String?;
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        final foodId = map['foodId'] as String;
        final qty = map['qty'] as int;
        final food = FoodItem.menu.firstWhere(
          (f) => f.id == foodId,
          orElse: () => FoodItem.menu.first,
        );
        // Deserialize addons (backwards compatible — field may not exist)
        final List<Addon> addons = [];
        if (map['addons'] != null) {
          for (final a in map['addons'] as List<dynamic>) {
            addons.add(Addon.fromJson(a as Map<String, dynamic>));
          }
        }
        // only add if found
        if (food.id == foodId) {
          _items.add(CartItem(foodItem: food, selectedAddons: addons)..quantity = qty);
          _selectedIds.add(foodId); // restore as selected
        }
      }
    } catch (_) {
      // corrupt data — start fresh
    }
  }

  Future<void> _saveToHive() async {
    final box = Hive.box(kBoxDatabase);
    final encoded = jsonEncode(
      _items.map((i) => {
        'foodId': i.foodItem.id,
        'qty': i.quantity,
        'addons': i.selectedAddons.map((a) => a.toJson()).toList(),
      }).toList(),
    );
    await box.put('cart', encoded);
  }

  // ── Mutations (all call _saveToHive) ─────────────────────────────────────

  void addItem(FoodItem food, {List<Addon> addons = const []}) {
    final index = _items.indexWhere((e) => e.foodItem.id == food.id);
    if (index >= 0) {
      _items[index].quantity++;
      _items[index].selectedAddons = List.of(addons);
    } else {
      _items.add(CartItem(foodItem: food, selectedAddons: List.of(addons)));
      _selectedIds.add(food.id); // auto-select newly added items
    }
    notifyListeners();
    _saveToHive();
  }

  void removeItem(String foodId) {
    _items.removeWhere((e) => e.foodItem.id == foodId);
    _selectedIds.remove(foodId);
    notifyListeners();
    _saveToHive();
  }

  void increment(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
      _saveToHive();
    }
  }

  void decrement(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    if (index >= 0) {
      if (_items[index].quantity <= 1) {
        _items.removeAt(index);
        _selectedIds.remove(foodId);
      } else {
        _items[index].quantity--;
      }
      notifyListeners();
      _saveToHive();
    }
  }

  void clearSelected() {
    _items.removeWhere((i) => _selectedIds.contains(i.foodItem.id));
    _selectedIds.clear();
    notifyListeners();
    _saveToHive();
  }

  void clearCart() {
    _items.clear();
    _selectedIds.clear();
    notifyListeners();
    _saveToHive();
  }

  int quantityOf(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    return index >= 0 ? _items[index].quantity : 0;
  }

  /// Returns the CartItem for the given foodId, or null if not in cart.
  CartItem? getItem(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    return index >= 0 ? _items[index] : null;
  }

  /// Updates the addons for an existing cart item.
  void updateAddons(String foodId, List<Addon> addons) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    if (index >= 0) {
      _items[index].selectedAddons = List.of(addons);
      notifyListeners();
      _saveToHive();
    }
  }
}
