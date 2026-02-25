import 'food_item.dart';

class CartItem {
  final FoodItem foodItem;
  int quantity;
  List<Addon> selectedAddons;

  CartItem({
    required this.foodItem,
    this.quantity = 1,
    List<Addon>? selectedAddons,
  }) : selectedAddons = selectedAddons ?? [];

  /// Total price of selected add-ons (per unit).
  double get addonsPrice =>
      selectedAddons.fold(0.0, (sum, a) => sum + a.price);

  /// Subtotal = (base price + addons) × quantity.
  double get subtotal => (foodItem.price + addonsPrice) * quantity;
}

