import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

const String _base = 'http://10.0.2.2:5000/api';
const String _sock = 'http://10.0.2.2:5000';
const Color _orange = Color(0xFFFF6B00);
const Color _green = Color(0xFF2E7D32);
const Color _lightGreen = Color(0xFF4CAF50);
const Color _darkBg = Color(0xFF1A1A1A);
const Color _cardBg = Color(0xFF242424);
const Color _surfaceBg = Color(0xFF2D2D2D);
const Color _textPrimary = Color(0xFFFFFFFF);
const Color _textSecondary = Color(0xFFB0B0B0);
const Color _textMuted = Color(0xFF757575);
const Color _divider = Color(0xFF333333);
const Color _success = Color(0xFF4CAF50);
const Color _error = Color(0xFFE53935);
const Color _warning = Color(0xFFFFC107);

Future<Map<String,dynamic>> _post(String p, Map body, {String? t}) async {
  try {
    final h = {'Content-Type': 'application/json', if (t != null) 'Authorization': 'Bearer $t'};
    final r = await http.post(Uri.parse('$_base$p'), headers: h, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  } catch (e) { return {'error': e.toString()}; }
}
Future<Map<String,dynamic>> _get(String p, {String? t, Map<String,String>? q}) async {
  try {
    final h = <String,String>{'Content-Type': 'application/json', if (t != null) 'Authorization': 'Bearer $t'};
    var uri = Uri.parse('$_base$p');
    if (q != null) uri = uri.replace(queryParameters: q);
    final r = await http.get(uri, headers: h).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  } catch (e) { return {'error': e.toString()}; }
}
Future<Map<String,dynamic>> _put(String p, Map body, {String? t}) async {
  try {
    final h = {'Content-Type': 'application/json', if (t != null) 'Authorization': 'Bearer $t'};
    final r = await http.put(Uri.parse('$_base$p'), headers: h, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  } catch (e) { return {'error': e.toString()}; }
}

// ── Auth State ────────────────────────────────────────────────
class AuthState extends ChangeNotifier {
  String? token;
  Map<String,dynamic>? user;
  bool loading = false;
  String? error;
  bool get isAdmin => user?['role'] == 'admin';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    final u = p.getString('user');
    if (u != null) user = jsonDecode(u);
    notifyListeners();
  }

  Future<bool> sendOTP(String phone) async {
    loading = true; error = null; notifyListeners();
    final res = await _post('/auth/send-otp', {'phone': phone});
    loading = false;
    if (res.containsKey('error')) { error = res['error']; notifyListeners(); return false; }
    notifyListeners(); return true;
  }

  Future<bool> verifyOTP(String phone, String otp) async {
    loading = true; error = null; notifyListeners();
    final res = await _post('/auth/verify-otp', {'phone': phone, 'otp': otp, 'role': 'admin'});
    loading = false;
    if (res.containsKey('error')) { error = res['error']; notifyListeners(); return false; }
    token = res['token'];
    user = res['user'];
    if (user?['role'] != 'admin') { error = 'Not an admin account'; token = null; user = null; notifyListeners(); return false; }
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token!);
    await p.setString('user', jsonEncode(user));
    notifyListeners(); return true;
  }

  Future<void> logout() async {
    token = null; user = null;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    notifyListeners();
  }
}

// ── Admin State ───────────────────────────────────────────────
class AdminState extends ChangeNotifier {
  Map<String,dynamic> stats = {};
  List<Map<String,dynamic>> liveOrders = [];
  List<Map<String,dynamic>> restaurants = [];
  List<Map<String,dynamic>> riders = [];
  List<Map<String,dynamic>> customers = [];
  List<Map<String,dynamic>> menuItems = [];
  Map<String,dynamic> deliveryConfig = {'baseKm': 1, 'baseCharge': 10, 'perKmCharge': 5};
  late IO.Socket socket;
  bool loading = false;

  void initSocket(String userId) {
    socket = IO.io(_sock, IO.OptionBuilder().setTransports(['websocket']).build());
    socket.on('connect', (_) => socket.emit('join', {'role': 'admin', 'userId': userId}));
    socket.on('new_order', (data) {
      liveOrders.insert(0, Map<String,dynamic>.from(data));
      if (liveOrders.length > 50) liveOrders.removeLast();
      notifyListeners();
    });
    socket.on('admin_order_update', (data) {
      final o = Map<String,dynamic>.from(data);
      final idx = liveOrders.indexWhere((x) => x['_id'] == o['_id']);
      if (idx != -1) liveOrders[idx] = o;
      else liveOrders.insert(0, o);
      notifyListeners();
    });
  }

  Future<void> loadAll(String token) async {
    loading = true; notifyListeners();
    final [statsRes, ordersRes, restsRes, ridersRes, customersRes, menuRes, configRes] = await Future.wait([
      _get('/admin/stats', t: token),
      _get('/admin/orders', t: token),
      _get('/admin/restaurants', t: token),
      _get('/admin/riders', t: token),
      _get('/admin/customers', t: token),
      _get('/menu/restaurant/rest_1'), // sample
      _get('/admin/delivery-config', t: token),
    ]);
    stats = statsRes['stats'] ?? {};
    if (liveOrders.isEmpty) liveOrders = (ordersRes['orders'] as List? ?? []).cast<Map<String,dynamic>>();
    restaurants = (restsRes['restaurants'] as List? ?? []).cast<Map<String,dynamic>>();
    riders = (ridersRes['riders'] as List? ?? []).cast<Map<String,dynamic>>();
    customers = (customersRes['customers'] as List? ?? []).cast<Map<String,dynamic>>();
    menuItems = (menuRes['items'] as List? ?? []).cast<Map<String,dynamic>>();
    deliveryConfig = configRes['config'] ?? deliveryConfig;
    loading = false; notifyListeners();
  }

  Future<void> suspendRestaurant(String id, bool val, String token) async {
    await _put('/admin/restaurants/$id/suspend', {'isSuspended': val}, t: token);
    final idx = restaurants.indexWhere((r) => r['_id'] == id);
    if (idx != -1) { restaurants[idx]['isSuspended'] = val; notifyListeners(); }
  }

  Future<void> approveRestaurant(String id, bool val, String token) async {
    await _put('/admin/restaurants/$id/approve', {'isApproved': val}, t: token);
    final idx = restaurants.indexWhere((r) => r['_id'] == id);
    if (idx != -1) { restaurants[idx]['isApproved'] = val; notifyListeners(); }
  }

  Future<void> suspendRider(String id, bool val, String token) async {
    await _put('/admin/riders/$id/suspend', {'isSuspended': val}, t: token);
    final idx = riders.indexWhere((r) => r['_id'] == id);
    if (idx != -1) { riders[idx]['isSuspended'] = val; notifyListeners(); }
  }

  Future<void> approveRider(String id, bool val, String token) async {
    await _put('/admin/riders/$id/approve', {'isApproved': val}, t: token);
    final idx = riders.indexWhere((r) => r['_id'] == id);
    if (idx != -1) { riders[idx]['isApproved'] = val; notifyListeners(); }
  }

  Future<void> suspendCustomer(String id, bool val, String token) async {
    await _put('/admin/customers/$id/suspend', {'isSuspended': val}, t: token);
    final idx = customers.indexWhere((c) => c['_id'] == id);
    if (idx != -1) { customers[idx]['isSuspended'] = val; notifyListeners(); }
  }

  Future<void> toggleMenuItem(String id, bool val, String token) async {
    await _put('/admin/menu/$id/toggle', {'isAvailable': val}, t: token);
    final idx = menuItems.indexWhere((m) => m['_id'] == id);
    if (idx != -1) { menuItems[idx]['isAvailable'] = val; notifyListeners(); }
  }

  Future<void> updateMenuPrice(String id, double price, String token) async {
    await _put('/admin/menu/$id/price', {'price': price}, t: token);
    final idx = menuItems.indexWhere((m) => m['_id'] == id);
    if (idx != -1) { menuItems[idx]['price'] = price; notifyListeners(); }
  }

  Future<void> updateDeliveryConfig(Map<String,dynamic> config, String token) async {
    await _put('/admin/delivery-config', config, t: token);
    deliveryConfig = {...deliveryConfig, ...config};
    notifyListeners();
  }

  void dispose() { socket.disconnect(); super.dispose(); }
}

// ── Router ─────────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', redirect: (ctx, state) async {
      final p = await SharedPreferences.getInstance();
      return p.getString('token') != null ? '/dashboard' : '/login';
    }),
    GoRoute(path: '/login', builder: (ctx, state) => const _LoginScreen()),
    GoRoute(path: '/otp', builder: (ctx, state) => _OTPScreen(phone: state.extra as String)),
    GoRoute(path: '/dashboard', builder: (ctx, state) => const _DashboardScreen()),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthState()..load()),
      ChangeNotifierProvider(create: (_) => AdminState()),
    ],
    child: MaterialApp.router(
      title: 'Go Fresh Admin',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true, brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: _orange, secondary: _lightGreen, surface: _cardBg),
        scaffoldBackgroundColor: _darkBg,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
    ),
  ));
}

// ── Login ──────────────────────────────────────────────────────
class _LoginScreen extends StatefulWidget {
  const _LoginScreen({super.key});
  @override State<_LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<_LoginScreen> {
  final _ctrl = TextEditingController();
  @override Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(backgroundColor: _darkBg, body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 40),
      Center(child: ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.asset('assets/images/gofresh_logo.jpg', width: 100, height: 100, fit: BoxFit.cover))),
      const SizedBox(height: 32),
      const Text('Admin Panel', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary)).animate().slideX(begin: -0.3, duration: 400.ms),
      const Text('Control everything from here', style: TextStyle(color: _textSecondary)),
      const SizedBox(height: 32),
      Container(decoration: BoxDecoration(color: _surfaceBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _divider)), child: Row(children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('+91', style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 16))),
        Container(width: 1, height: 24, color: _divider),
        Expanded(child: TextField(controller: _ctrl, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: _textPrimary, fontSize: 18, letterSpacing: 2), decoration: const InputDecoration(hintText: '9000000000', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18), counterText: '', filled: false))),
      ])),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: auth.loading ? null : () async {
          final ok = await auth.sendOTP(_ctrl.text.trim());
          if (ok && mounted) context.push('/otp', extra: _ctrl.text.trim());
        },
        style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: auth.loading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      )),
      if (auth.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(auth.error!, style: const TextStyle(color: _error))),
    ]))));
  }
}

class _OTPScreen extends StatefulWidget {
  final String phone;
  const _OTPScreen({super.key, required this.phone});
  @override State<_OTPScreen> createState() => _OTPScreenState();
}
class _OTPScreenState extends State<_OTPScreen> {
  final _ctrl = TextEditingController();
  @override Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(backgroundColor: _darkBg, appBar: AppBar(backgroundColor: _darkBg, elevation: 0), body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Enter OTP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary)),
      Text('Sent to +91 ${widget.phone}', style: const TextStyle(color: _textSecondary)),
      const SizedBox(height: 32),
      TextField(controller: _ctrl, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: 12),
        decoration: InputDecoration(filled: true, fillColor: _surfaceBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), counterText: '')),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: auth.loading ? null : () async {
          final ok = await auth.verifyOTP(widget.phone, _ctrl.text.trim());
          if (!mounted) return;
          if (ok) {
            final admin = context.read<AdminState>();
            admin.initSocket(context.read<AuthState>().user!['_id']);
            await admin.loadAll(context.read<AuthState>().token!);
            context.go('/dashboard');
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: auth.loading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify & Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      )),
      if (auth.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(auth.error!, style: const TextStyle(color: _error))),
    ])));
  }
}

// ── Dashboard ──────────────────────────────────────────────────
class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen({super.key});
  @override State<_DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<_DashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/gofresh_logo.jpg', width: 32, height: 32, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Go Fresh Admin', style: TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Full Control', style: TextStyle(color: _textMuted, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _orange), onPressed: () => admin.loadAll(auth.token ?? '')),
          IconButton(icon: const Icon(Icons.logout, color: _textMuted), onPressed: () { auth.logout(); context.go('/login'); }),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        _DashboardTab(admin: admin),
        _OrdersTab(admin: admin),
        _RestaurantsTab(admin: admin, token: auth.token ?? ''),
        _RidersTab(admin: admin, token: auth.token ?? ''),
        _SettingsTab(admin: admin, token: auth.token ?? ''),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: _cardBg, border: Border(top: BorderSide(color: _divider))),
        child: BottomNavigationBar(
          currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent, selectedItemColor: _orange, unselectedItemColor: _textMuted, elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Badge(isLabelVisible: admin.liveOrders.where((o) => o['status'] == 'PLACED').length > 0, label: Text('${admin.liveOrders.where((o) => o['status'] == 'PLACED').length}', style: const TextStyle(fontSize: 10)), backgroundColor: _error, child: const Icon(Icons.receipt_rounded)), label: 'Orders'),
            const BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'Stores'),
            const BottomNavigationBarItem(icon: Icon(Icons.delivery_dining_rounded), label: 'Riders'),
            const BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final AdminState admin;
  const _DashboardTab({required this.admin});
  @override Widget build(BuildContext context) {
    final s = admin.stats;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Live Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary)),
      const SizedBox(height: 16),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.4, children: [
        _StatTile('Total Orders', '${s['totalOrders'] ?? 0}', Icons.receipt_long, _orange),
        _StatTile('Today Orders', '${s['todayOrders'] ?? 0}', Icons.today, _lightGreen),
        _StatTile('Total Revenue', '₹${(s['totalRevenue'] as num?)?.toStringAsFixed(0) ?? '0'}', Icons.currency_rupee, _success),
        _StatTile('Online Riders', '${s['onlineRiders'] ?? 0}', Icons.delivery_dining, Color(0xFF2196F3)),
        _StatTile('Restaurants', '${s['approvedRestaurants'] ?? 0}', Icons.restaurant, _warning),
        _StatTile('Customers', '${s['totalCustomers'] ?? 0}', Icons.people, Color(0xFF9C27B0)),
      ]),
      const SizedBox(height: 20),
      const Text('Pending Orders', style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 16)),
      const SizedBox(height: 8),
      ...admin.liveOrders.where((o) => o['status'] == 'PLACED').take(5).map((o) {
        final c = o['customerInfo'] ?? {};
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _orange.withOpacity(0.3))), child: Row(children: [
          const Text('🛒', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['name'] ?? 'Customer', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
            Text(c['phone'] ?? '', style: const TextStyle(color: _textMuted, fontSize: 12)),
          ])),
          Text('₹${o['pricing']?['total']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: _orange, fontWeight: FontWeight.w700)),
        ]));
      }),
    ]);
  }
}

class _OrdersTab extends StatelessWidget {
  final AdminState admin;
  const _OrdersTab({required this.admin});
  Color _c(String s) { if (s == 'DELIVERED') return _success; if (s == 'CANCELLED' || s == 'REJECTED') return _error; return _orange; }
  @override Widget build(BuildContext context) {
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: admin.liveOrders.length, itemBuilder: (ctx, i) {
      final o = admin.liveOrders[i];
      final c = o['customerInfo'] ?? {};
      final items = (o['items'] as List? ?? []).cast<Map<String,dynamic>>();
      return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Order #${o['_id']?.substring(0, 8) ?? ''}', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _c(o['status'] ?? '').withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(o['status'] ?? '', style: TextStyle(color: _c(o['status'] ?? ''), fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Row(children: [const Icon(Icons.person, color: _orange, size: 14), const SizedBox(width: 4), Text('${c['name'] ?? ''} • ${c['phone'] ?? ''}', style: const TextStyle(color: _textSecondary, fontSize: 12))]),
        const SizedBox(height: 4),
        Text('${items.length} items • ₹${o['pricing']?['total']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: _textMuted, fontSize: 12)),
      ]));
    });
  }
}

class _RestaurantsTab extends StatelessWidget {
  final AdminState admin;
  final String token;
  const _RestaurantsTab({required this.admin, required this.token});
  @override Widget build(BuildContext context) {
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: admin.restaurants.length, itemBuilder: (ctx, i) {
      final r = admin.restaurants[i];
      final suspended = r['isSuspended'] ?? false;
      final approved = r['isApproved'] ?? false;
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: suspended ? _error.withOpacity(0.3) : _divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r['name'] ?? '', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 15))),
          if (suspended) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _error.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('SUSPENDED', style: TextStyle(color: _error, fontSize: 10, fontWeight: FontWeight.w800))),
          if (!approved && !suspended) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _warning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('PENDING', style: TextStyle(color: _warning, fontSize: 10, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text(r['address'] ?? '', style: const TextStyle(color: _textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          if (!approved) Expanded(child: _ActionBtn('Approve', _success, () => admin.approveRestaurant(r['_id'], true, token))),
          if (approved) Expanded(child: _ActionBtn(suspended ? 'Enable' : 'Suspend', suspended ? _success : _error, () => admin.suspendRestaurant(r['_id'], !suspended, token))),
          const SizedBox(width: 8),
          Expanded(child: _ActionBtn('View Menu', _orange, () => _showMenuDialog(context, r['_id'], token))),
        ]),
      ]));
    });
  }
  void _showMenuDialog(BuildContext context, String restId, String token) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _cardBg,
      title: const Text('Menu Items', style: TextStyle(color: _textPrimary)),
      content: SizedBox(width: 300, height: 400, child: FutureBuilder(
        future: _get('/menu/restaurant/$restId'),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _orange));
          final items = (snap.data!['items'] as List? ?? []).cast<Map<String,dynamic>>();
          return ListView.builder(itemCount: items.length, itemBuilder: (ctx, i) {
            final item = items[i];
            return ListTile(
              title: Text(item['name'] ?? '', style: const TextStyle(color: _textPrimary, fontSize: 13)),
              subtitle: Text('₹${item['price']}', style: const TextStyle(color: _orange)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: item['isAvailable'] ?? true, activeColor: _success, onChanged: (v) {
                  admin.toggleMenuItem(item['_id'], v, token);
                  Navigator.pop(ctx);
                }),
              ]),
            );
          });
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: _orange)))],
    ));
  }
}

class _RidersTab extends StatelessWidget {
  final AdminState admin;
  final String token;
  const _RidersTab({required this.admin, required this.token});
  @override Widget build(BuildContext context) {
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: admin.riders.length, itemBuilder: (ctx, i) {
      final r = admin.riders[i];
      final suspended = r['isSuspended'] ?? false;
      final approved = r['isApproved'] ?? false;
      final online = r['isOnline'] ?? false;
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: suspended ? _error.withOpacity(0.3) : _divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(online ? '🟢' : '⚫', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(r['name'] ?? '', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700))),
          if (suspended) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _error.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('SUSPENDED', style: TextStyle(color: _error, fontSize: 10, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text('📞 ${r['phone'] ?? ''}  •  🛵 ${r['vehicleNumber'] ?? ''}', style: const TextStyle(color: _textMuted, fontSize: 12)),
        Text('Deliveries: ${r['totalDeliveries'] ?? 0}  •  Earnings: ₹${r['totalEarnings'] ?? 0}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          if (!approved) Expanded(child: _ActionBtn('Approve', _success, () => admin.approveRider(r['_id'], true, token))),
          if (approved) Expanded(child: _ActionBtn(suspended ? 'Enable' : 'Suspend', suspended ? _success : _error, () => admin.suspendRider(r['_id'], !suspended, token))),
        ]),
      ]));
    });
  }
}

class _SettingsTab extends StatefulWidget {
  final AdminState admin;
  final String token;
  const _SettingsTab({required this.admin, required this.token});
  @override State<_SettingsTab> createState() => _SettingsTabState();
}
class _SettingsTabState extends State<_SettingsTab> {
  final _baseKm = TextEditingController();
  final _baseCharge = TextEditingController();
  final _perKm = TextEditingController();

  @override void initState() {
    super.initState();
    _baseKm.text = '${widget.admin.deliveryConfig['baseKm'] ?? 1}';
    _baseCharge.text = '${widget.admin.deliveryConfig['baseCharge'] ?? 10}';
    _perKm.text = '${widget.admin.deliveryConfig['perKmCharge'] ?? 5}';
  }

  @override Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Delivery Pricing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)), child: Column(children: [
        _ConfigField('Base Distance (km)', _baseKm),
        const SizedBox(height: 12),
        _ConfigField('Base Charge (₹)', _baseCharge),
        const SizedBox(height: 12),
        _ConfigField('Per km charge (₹)', _perKm),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () async {
            await widget.admin.updateDeliveryConfig({
              'baseKm': int.tryParse(_baseKm.text) ?? 1,
              'baseCharge': int.tryParse(_baseCharge.text) ?? 10,
              'perKmCharge': int.tryParse(_perKm.text) ?? 5,
            }, widget.token);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Delivery config updated'), backgroundColor: _success));
          },
          style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        )),
      ])),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Current Formula', style: TextStyle(color: _textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Text('Within ${widget.admin.deliveryConfig['baseKm']}km: ₹${widget.admin.deliveryConfig['baseCharge']}', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
        Text('After ${widget.admin.deliveryConfig['baseKm']}km: +₹${widget.admin.deliveryConfig['perKmCharge']}/km', style: const TextStyle(color: _orange, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }
}

class _ConfigField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _ConfigField(this.label, this.ctrl);
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: _textSecondary, fontSize: 13)),
    const SizedBox(height: 6),
    TextField(controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: _textPrimary, fontSize: 16),
      decoration: InputDecoration(filled: true, fillColor: _surfaceBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
  ]);
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.value, this.icon, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.onTap);
  @override Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(side: BorderSide(color: color), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 8)),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  );
}
