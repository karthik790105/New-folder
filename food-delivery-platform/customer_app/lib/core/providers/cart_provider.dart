import 'package:flutter/foundation.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  StoreModel? _store;
  double _deliveryFee = 10;

  List<CartItem> get items => _items;
  StoreModel? get store => _store;
  double get deliveryFee => _deliveryFee;
  bool get isEmpty => _items.isEmpty;

  double get itemsTotal => _items.fold(0, (sum, i) => sum + i.total);
  double get taxes => itemsTotal * 0.05;
  double get grandTotal => itemsTotal + _deliveryFee + taxes;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  void setDeliveryFee(double fee) {
    _deliveryFee = fee;
    notifyListeners();
  }

  void addItem(MenuItemModel item, StoreModel store, {List<AddOnModel> addOns = const []}) {
    // If switching store, clear cart
    if (_store != null && _store!.id != store.id) {
      _items.clear();
    }
    _store = store;

    final existing = _items.where((ci) => ci.item.id == item.id).firstOrNull;
    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(CartItem(item: item, quantity: 1, selectedAddOns: addOns));
    }
    notifyListeners();
  }

  void removeItem(String itemId) {
    final idx = _items.indexWhere((ci) => ci.item.id == itemId);
    if (idx != -1) {
      if (_items[idx].quantity > 1) {
        _items[idx].quantity--;
      } else {
        _items.removeAt(idx);
      }
      if (_items.isEmpty) _store = null;
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _store = null;
    notifyListeners();
  }

  int getItemQuantity(String itemId) {
    final item = _items.where((ci) => ci.item.id == itemId).firstOrNull;
    return item?.quantity ?? 0;
  }

  List<Map<String, dynamic>> toOrderItems() => _items.map((ci) => ({
        '_id': ci.item.id,
        'name': ci.item.name,
        'quantity': ci.quantity,
        'price': ci.item.price,
        'addOns': ci.selectedAddOns.map((a) => {'name': a.name, 'price': a.price}).toList(),
      })).toList();
}
