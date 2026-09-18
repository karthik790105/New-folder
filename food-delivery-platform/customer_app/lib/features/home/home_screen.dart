import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/cart_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StoreModel> _restaurants = [];
  List<StoreModel> _groceryStores = [];
  List<StoreModel> _meatStores = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  int _navIndex = 0;

  final List<Map<String, dynamic>> _cuisines = [
    {'name': 'All', 'icon': '🍽️'},
    {'name': 'South Indian', 'icon': '🥘'},
    {'name': 'Pizza', 'icon': '🍕'},
    {'name': 'Burgers', 'icon': '🍔'},
    {'name': 'Biryani', 'icon': '🍲'},
    {'name': 'Healthy', 'icon': '🥗'},
  ];
  String _selectedCuisine = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final [rData, gData, mData] = await Future.wait([
      ApiClient.get('/restaurants'),
      ApiClient.get('/stores/grocery'),
      ApiClient.get('/stores/meat'),
    ]);
    setState(() {
      _restaurants = (rData['restaurants'] as List? ?? [])
          .map((r) => StoreModel.fromJson(r, storeType: 'restaurant'))
          .toList();
      _groceryStores = (gData['stores'] as List? ?? [])
          .map((s) => StoreModel.fromJson(s, storeType: 'grocery'))
          .toList();
      _meatStores = (mData['stores'] as List? ?? [])
          .map((s) => StoreModel.fromJson(s, storeType: 'meat'))
          .toList();
      _loading = false;
    });
  }

  List<StoreModel> get _filteredRestaurants {
    var list = _restaurants;
    if (_search.isNotEmpty) list = list.where((r) => r.name.toLowerCase().contains(_search.toLowerCase())).toList();
    if (_selectedCuisine != 'All') list = list.where((r) => r.cuisineTypes.any((c) => c.contains(_selectedCuisine))).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: _navIndex == 0 ? _buildHomeTab(cartCount) : _navIndex == 2 ? _buildOrdersTab() : _buildProfileTab(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.primaryOrange,
          unselectedItemColor: AppTheme.textMuted,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_bag_rounded),
                  if (cartCount > 0)
                    Positioned(
                      right: -6, top: -6,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle),
                        child: Center(child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(int cartCount) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryOrange,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/images/gofresh_logo.jpg', width: 40, height: 40, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Go Fresh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange)),
                          Text('Delivering to you 🛵', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      if (cartCount > 0)
                        GestureDetector(
                          onTap: () => context.push('/cart'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [
                              const Icon(Icons.shopping_bag, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text('$cartCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search
                  Container(
                    decoration: BoxDecoration(color: AppTheme.surfaceBg, borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search restaurants, dishes...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Banner
                  _buildBanner(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryOrange,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: AppTheme.primaryOrange,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: '🍽️ Food'),
                  Tab(text: '🛒 Grocery'),
                  Tab(text: '🥩 Meat'),
                ],
              ),
            ),
          ),
          // Cuisine filters (only for food tab)
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (ctx, _) => _tabController.index == 0
                  ? SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _cuisines.length,
                        itemBuilder: (ctx, i) {
                          final c = _cuisines[i];
                          final selected = _selectedCuisine == c['name'];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCuisine = c['name']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected ? AppTheme.primaryOrange : AppTheme.surfaceBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${c['icon']} ${c['name']}',
                                  style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Store list
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStoreList(_filteredRestaurants, 'restaurant'),
                _buildStoreList(_groceryStores, 'grocery'),
                _buildStoreList(_meatStores, 'meat'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFF2E7D32)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Your Needs,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Text('Our Delivery! 🚀', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: const Text('₹10 delivery within 1km', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const Spacer(),
            const Text('🛵', style: TextStyle(fontSize: 48)),
          ],
        ),
      ),
    ).animate().shimmer(duration: 2000.ms, delay: 500.ms);
  }

  Widget _buildStoreList(List<StoreModel> stores, String type) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
    }
    if (stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(type == 'grocery' ? '🛒' : type == 'meat' ? '🥩' : '🍽️', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No ${type} stores available', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stores.length,
      itemBuilder: (ctx, i) => _StoreCard(store: stores[i]).animate().slideY(begin: 0.2, duration: 300.ms, delay: (i * 50).ms),
    );
  }

  Widget _buildOrdersTab() {
    return _OrdersTab();
  }

  Widget _buildProfileTab() {
    return _ProfileTab();
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/store/${store.id}', extra: store),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store image placeholder / logo area
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: store.storeType == 'grocery'
                      ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                      : store.storeType == 'meat'
                          ? [const Color(0xFF7B1111), const Color(0xFFB71C1C)]
                          : [const Color(0xFF4A1500), const Color(0xFFFF6B00)],
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(store.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(store.description, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      store.storeType == 'grocery' ? '🛒' : store.storeType == 'meat' ? '🥩' : '🍽️',
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                  const SizedBox(width: 4),
                  Text('${store.rating}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(' (${store.reviewCount})', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.access_time_rounded, color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text('${store.avgDeliveryTime} min', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('₹${store.deliveryFee.toInt()} delivery', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (!store.isOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: const Center(child: Text('CLOSED', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 2))),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    // Get customerId from prefs
    final prefs = await SharedPreferences.getInstance();
    // For demo, load all orders
    final result = await ApiClient.get('/orders', auth: true);
    setState(() {
      _orders = result['orders'] ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🛵', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text('No orders yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Order your first meal from Go Fresh!', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (ctx, i) {
        final o = _orders[_orders.length - 1 - i];
        return _OrderCard(order: o, onTap: () => context.push('/tracking/${o['_id']}'));
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'DELIVERED': return AppTheme.success;
      case 'CANCELLED': case 'REJECTED': return AppTheme.error;
      default: return AppTheme.primaryOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.surfaceBg, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('🛵', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order['_id']?.substring(0, 8) ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${(order['items'] as List?)?.length ?? 0} items • ₹${(order['pricing']?['total'] ?? 0)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(order['status'] ?? '').withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(order['status'] ?? '', style: TextStyle(color: _statusColor(order['status'] ?? ''), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('My Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 24),
          _ProfileTile(icon: Icons.person_outline, title: 'Account Details', onTap: () {}),
          _ProfileTile(icon: Icons.location_on_outlined, title: 'Saved Addresses', onTap: () {}),
          _ProfileTile(icon: Icons.receipt_long_outlined, title: 'Order History', onTap: () => context.go('/home')),
          _ProfileTile(icon: Icons.support_agent_outlined, title: 'Help & Support', onTap: () {}),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                context.go('/login');
              },
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: const Text('Logout', style: TextStyle(color: AppTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                Text('Go Fresh', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700)),
                Text('From Our Store to Your Door ❤️', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryOrange, size: 22),
            const SizedBox(width: 14),
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppTheme.darkBg, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart';
