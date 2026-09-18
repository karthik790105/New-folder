// Models for Go Fresh Customer App

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isSuspended;
  final List<AddressModel> addresses;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isSuspended = false,
    this.addresses = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        role: json['role'] ?? 'customer',
        isSuspended: json['isSuspended'] ?? false,
        addresses: (json['addresses'] as List?)
                ?.map((a) => AddressModel.fromJson(a))
                .toList() ??
            [],
      );
}

class AddressModel {
  final String label;
  final String address;
  final double? lat;
  final double? lng;
  final bool isDefault;

  AddressModel({required this.label, required this.address, this.lat, this.lng, this.isDefault = false});

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        label: json['label'] ?? 'Home',
        address: json['address'] ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        isDefault: json['isDefault'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
        'isDefault': isDefault,
      };
}

class StoreModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final double? lat;
  final double? lng;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final bool isApproved;
  final int avgDeliveryTime;
  final double minOrder;
  final double deliveryFee;
  final String? logo;
  final List<String> cuisineTypes;
  final String storeType; // restaurant, grocery, meat
  final double? distance;

  StoreModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    this.lat,
    this.lng,
    required this.rating,
    required this.reviewCount,
    required this.isOpen,
    required this.isApproved,
    required this.avgDeliveryTime,
    required this.minOrder,
    required this.deliveryFee,
    this.logo,
    this.cuisineTypes = const [],
    required this.storeType,
    this.distance,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json, {String storeType = 'restaurant'}) => StoreModel(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        address: json['address'] ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: json['reviewCount'] ?? 0,
        isOpen: json['isOpen'] ?? false,
        isApproved: json['isApproved'] ?? false,
        avgDeliveryTime: json['avgDeliveryTime'] ?? 30,
        minOrder: (json['minOrder'] as num?)?.toDouble() ?? 0,
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 10,
        logo: json['logo'],
        cuisineTypes: (json['cuisineTypes'] as List?)?.cast<String>() ?? [],
        storeType: storeType,
        distance: (json['distance'] as num?)?.toDouble(),
      );
}

class MenuItemModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String category;
  double price;
  final bool isVeg;
  bool isAvailable;
  final double rating;
  final int prepTime;
  final List<AddOnModel> addOns;
  final String? storeType;

  MenuItemModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isVeg,
    required this.isAvailable,
    required this.rating,
    required this.prepTime,
    this.addOns = const [],
    this.storeType,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['_id'] ?? '',
        restaurantId: json['restaurantId'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        category: json['category'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        isVeg: json['isVeg'] ?? true,
        isAvailable: json['isAvailable'] ?? true,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        prepTime: json['prepTime'] ?? 0,
        addOns: (json['addOns'] as List?)?.map((a) => AddOnModel.fromJson(a)).toList() ?? [],
        storeType: json['storeType'],
      );
}

class AddOnModel {
  final String name;
  final double price;

  AddOnModel({required this.name, required this.price});

  factory AddOnModel.fromJson(Map<String, dynamic> json) => AddOnModel(
        name: json['name'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );
}

class CartItem {
  final MenuItemModel item;
  int quantity;
  final List<AddOnModel> selectedAddOns;

  CartItem({required this.item, this.quantity = 1, this.selectedAddOns = const []});

  double get total => (item.price + selectedAddOns.fold(0.0, (s, a) => s + a.price)) * quantity;
}

class OrderModel {
  final String id;
  final String customerId;
  final String restaurantId;
  final List<OrderItemModel> items;
  final String status;
  final String? deliveryOTP;
  final Map<String, dynamic>? pricing;
  final Map<String, dynamic>? deliveryAddress;
  final List<OrderTimelineModel> timeline;
  final String? riderId;
  final Map<String, dynamic>? customerInfo;
  final String? storeType;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    required this.items,
    required this.status,
    this.deliveryOTP,
    this.pricing,
    this.deliveryAddress,
    this.timeline = const [],
    this.riderId,
    this.customerInfo,
    this.storeType,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['_id'] ?? '',
        customerId: json['customerId'] ?? '',
        restaurantId: json['restaurantId'] ?? '',
        items: (json['items'] as List?)?.map((i) => OrderItemModel.fromJson(i)).toList() ?? [],
        status: json['status'] ?? 'PLACED',
        deliveryOTP: json['deliveryOTP'],
        pricing: json['pricing'],
        deliveryAddress: json['deliveryAddress'],
        timeline: (json['timeline'] as List?)?.map((t) => OrderTimelineModel.fromJson(t)).toList() ?? [],
        riderId: json['riderId'],
        customerInfo: json['customerInfo'],
        storeType: json['storeType'],
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class OrderItemModel {
  final String id;
  final String name;
  final int quantity;
  final double price;

  OrderItemModel({required this.id, required this.name, required this.quantity, required this.price});

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? '',
        quantity: json['quantity'] ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'_id': id, 'name': name, 'quantity': quantity, 'price': price};
}

class OrderTimelineModel {
  final String status;
  final DateTime timestamp;
  final String note;

  OrderTimelineModel({required this.status, required this.timestamp, required this.note});

  factory OrderTimelineModel.fromJson(Map<String, dynamic> json) => OrderTimelineModel(
        status: json['status'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        note: json['note'] ?? '',
      );
}
