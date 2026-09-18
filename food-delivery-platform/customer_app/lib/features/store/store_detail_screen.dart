import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/constants/app_constants.dart';

class StoreDetailScreen extends StatefulWidget {
  final StoreModel store;
  const StoreDetailScreen({super.key, required this.store});
  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  List<MenuItemModel> _items = [];
  List<String> _categories = [];
  bool _loading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final result = await ApiClient.get('${AppConstants.menu}/${widget.store.id}');
    setState(() {
      _items = (result['items'] as List? ?? []).map((i) => MenuItemModel.fromJson(i)).toList();
      _categories = ['All', ...(result['categories'] as List? ?? []).cast<String>()];
      _loading = false;
    });
  }

  List<MenuItemModel> get _filtered => _selectedCategory == 'All'
      ? _items
      : _items.where((i) => i.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          // App bar with store info
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.darkBg,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.store.storeType == 'grocery'
                        ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)]
                        : widget.store.storeType == 'meat'
                            ? [const Color(0xFF7B1111), const Color(0xFFC62828)]
                            : [const Color(0xFF4A1500), const Color(0xFFFF6B00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(widget.store.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(widget.store.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                          Text(' ${widget.store.rating} (${widget.store.reviewCount})',
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time_rounded, color: Colors.white70, size: 14),
                          Text(' ${widget.store.avgDeliveryTime} min', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(width: 16),
                          Text('₹${widget.store.minOrder.toInt()} min order', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Category chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final sel = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primaryOrange : AppTheme.surfaceBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(cat, style: TextStyle(color: sel ? Colors.white : AppTheme.textSecondary, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                },
              ),
            ),
          ),
          // Menu items
          _loading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _MenuItemCard(item: _filtered[i], store: widget.store, cart: cart)
                        .animate()
                        .slideX(begin: 0.1, duration: 200.ms, delay: (i * 30).ms),
                    childCount: _filtered.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      // Bottom cart bar
      bottomNavigationBar: cart.store?.id == widget.store.id && cart.itemCount > 0
          ? _CartBar(cart: cart)
          : null,
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final StoreModel store;
  final CartProvider cart;
  const _MenuItemCard({required this.item, required this.store, required this.cart});

  @override
  Widget build(BuildContext context) {
    final qty = cart.getItemQuantity(item.id);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // Veg/non-veg badge
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              border: Border.all(color: item.isVeg ? AppTheme.success : AppTheme.error, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: item.isVeg ? AppTheme.success : AppTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 15)),
                const SizedBox(height: 4),
                Text(item.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('₹${item.price.toInt()}', style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!item.isAvailable)
            const Text('Unavailable', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
          else if (qty == 0)
            GestureDetector(
              onTap: () => cart.addItem(item, store),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryOrange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('ADD', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: () => cart.removeItem(item.id),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.remove, color: Colors.white, size: 16),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Center(child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 16))),
                ),
                GestureDetector(
                  onTap: () => cart.addItem(item, store),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final CartProvider cart;
  const _CartBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/cart'),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
              child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            const Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            Text('₹${cart.itemsTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ).animate().slideY(begin: 1, duration: 300.ms, curve: Curves.easeOut),
    );
  }
}
