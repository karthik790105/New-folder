import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/location_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressCtrl = TextEditingController(text: '');
  bool _placing = false;
  bool _fetchingLocation = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _loadDeliveryConfig();
  }

  Future<void> _loadDeliveryConfig() async {
    final result = await ApiClient.get('/admin/delivery-config');
    if (result.containsKey('config')) {
      final config = result['config'];
      context.read<CartProvider>().setDeliveryFee(
        (config['baseCharge'] as num?)?.toDouble() ?? 10,
      );
    }
  }

  /// Fetches GPS location and reverse-geocodes it into the address field
  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    final result = await LocationService.getCurrentLocation();
    setState(() => _fetchingLocation = false);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _addressCtrl.text = result.address!;
        _lat = result.lat;
        _lng = result.lng;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.location_on, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text('Location detected!'),
          ]),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // Show error with option to open settings
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not get location'),
          backgroundColor: AppTheme.error,
          action: result.error?.contains('Settings') == true || result.error?.contains('settings') == true
              ? SnackBarAction(
                  label: 'Open Settings',
                  textColor: Colors.white,
                  onPressed: LocationService.openAppSettings,
                )
              : result.error?.contains('GPS') == true
                  ? SnackBarAction(
                      label: 'Enable GPS',
                      textColor: Colors.white,
                      onPressed: LocationService.openSettings,
                    )
                  : null,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or detect your delivery address'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _placing = true);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'usr_1';

    final body = {
      'customerId': userId,
      'restaurantId': cart.store!.id,
      'storeType': cart.store!.storeType,
      'items': cart.toOrderItems(),
      'deliveryAddress': {
        'address': _addressCtrl.text.trim(),
        'lat': _lat ?? 12.9716,
        'lng': _lng ?? 77.5946,
      },
      'payment': {'method': 'COD'},
      'pricing': {
        'itemsTotal': cart.itemsTotal,
        'deliveryFee': cart.deliveryFee,
        'taxes': cart.taxes,
        'total': cart.grandTotal,
      },
    };

    final result = await ApiClient.post('/orders', body, auth: true);
    setState(() => _placing = false);

    if (!mounted) return;
    if (result.containsKey('order')) {
      final orderId = result['order']['_id'];
      cart.clearCart();
      context.pushReplacement('/tracking/$orderId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to place order'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: cart.isEmpty ? _buildEmpty() : _buildCart(cart),
    );
  }

  Widget _buildCart(CartProvider cart) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Store name chip
              if (cart.store != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.store, color: AppTheme.primaryOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(cart.store!.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 16),

              // Cart items
              ...cart.items.map((ci) => _CartItemRow(ci: ci, cart: cart)),
              const SizedBox(height: 16),

              // ── Delivery Address Section ──────────────────────────────
              const Text('Delivery Address',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 8),

              // Address text field
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: TextField(
                  controller: _addressCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryOrange),
                    hintText: 'Enter full delivery address…',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(0, 14, 14, 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Use Current Location Button ───────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _fetchingLocation ? null : _useCurrentLocation,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _fetchingLocation
                          ? AppTheme.textMuted
                          : AppTheme.lightGreen,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _fetchingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: AppTheme.lightGreen, strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded,
                          color: AppTheme.lightGreen, size: 18),
                  label: Text(
                    _fetchingLocation
                        ? 'Detecting location…'
                        : '📍 Use My Current Location',
                    style: TextStyle(
                      color: _fetchingLocation
                          ? AppTheme.textMuted
                          : AppTheme.lightGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),

              // Show detected coordinates as a pill (if GPS was used)
              if (_lat != null && _lng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          const Icon(Icons.gps_fixed,
                              color: AppTheme.lightGreen, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'GPS: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                            style: const TextStyle(
                                color: AppTheme.lightGreen, fontSize: 11),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ).animate().slideX(begin: -0.2, duration: 300.ms),

              const SizedBox(height: 16),

              // Pricing breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _PricingRow('Items Total',
                      '₹${cart.itemsTotal.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  _PricingRow('Delivery Fee',
                      '₹${cart.deliveryFee.toStringAsFixed(0)}',
                      subtitle: '₹10 for 1km + ₹5/km'),
                  const SizedBox(height: 8),
                  _PricingRow('GST (5%)', '₹${cart.taxes.toStringAsFixed(0)}'),
                  const Divider(color: AppTheme.divider, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text('₹${cart.grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.primaryOrange,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Payment method
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.money, color: AppTheme.success),
                  SizedBox(width: 10),
                  Text('Cash on Delivery',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  Spacer(),
                  Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                ]),
              ),
            ],
          ),
        ),

        // Place Order button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _placing ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppTheme.primaryOrange,
              ),
              child: _placing
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : Text(
                      'Place Order • ₹${cart.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🛒', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text('Your cart is empty',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Add items from a store to get started',
              style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final dynamic ci;
  final CartProvider cart;
  const _CartItemRow({required this.ci, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        // Veg indicator
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            border: Border.all(
                color: ci.item.isVeg ? AppTheme.success : AppTheme.error,
                width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: ci.item.isVeg ? AppTheme.success : AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(ci.item.name,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ),
        // Qty controls
        Row(children: [
          GestureDetector(
            onTap: () => cart.removeItem(ci.item.id),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.remove,
                  color: AppTheme.textSecondary, size: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${ci.quantity}',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: () => cart.addItem(ci.item, cart.store!),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(6)),
              child:
                  const Icon(Icons.add, color: Colors.white, size: 14),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Text('₹${ci.total.toStringAsFixed(0)}',
            style: const TextStyle(
                color: AppTheme.primaryOrange, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _PricingRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  const _PricingRow(this.label, this.value, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        if (subtitle != null)
          Text(subtitle!,
              style:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
    ]);
  }
}
