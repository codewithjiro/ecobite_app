import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/food_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get total => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(FoodItem food) {
    final index = _items.indexWhere((e) => e.foodItem.id == food.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(foodItem: food));
    }
    notifyListeners();
  }

  void removeItem(String foodId) {
    _items.removeWhere((e) => e.foodItem.id == foodId);
    notifyListeners();
  }

  void increment(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrement(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    if (index >= 0) {
      if (_items[index].quantity <= 1) {
        _items.removeAt(index);
      } else {
        _items[index].quantity--;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  int quantityOf(String foodId) {
    final index = _items.indexWhere((e) => e.foodItem.id == foodId);
    return index >= 0 ? _items[index].quantity : 0;
  }
}

