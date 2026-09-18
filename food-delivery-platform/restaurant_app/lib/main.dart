import 'dart:convert';
import 'bill_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ── Constants ────────────────────────────────────────────────
const String _baseUrl = 'http://10.0.2.2:5000/api';
const String _socketUrl = 'http://10.0.2.2:5000';

// ── Colors ───────────────────────────────────────────────────
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

// ── API Helper ───────────────────────────────────────────────
Future<Map<String, dynamic>> apiPost(String path, Map<String, dynamic> body, {String? token}) async {
  try {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final r = await http.post(Uri.parse('$_baseUrl$path'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  } catch (e) { return {'error': e.toString()}; }
}

Future<Map<String, dynamic>> apiGet(String path, {String? token, Map<String,String>? params}) async {
  try {
    final headers = <String,String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    var uri = Uri.parse('$_baseUrl$path');
    if (params != null) uri = uri.replace(queryParameters: params);
    final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  } catch (e) { return {'error': e.toString()}; }
}

Future<Map<String, dynamic>> apiPut(String path, Map<String, dynamic> body, {String? token}) async {
  try {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final r = await http.put(Uri.parse('$_baseUrl$path'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  } catch (e) { return {'error': e.toString()}; }
}

// ── Auth State ───────────────────────────────────────────────
class AuthState extends ChangeNotifier {
  String? token;
  Map<String,dynamic>? user;
  Map<String,dynamic>? restaurant;
  bool loading = false;
  String? error;

  bool get isLoggedIn => token != null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    final u = p.getString('user');
    final r = p.getString('restaurant');
    if (u != null) user = jsonDecode(u);
    if (r != null) restaurant = jsonDecode(r);
    notifyListeners();
  }

  Future<bool> sendOTP(String phone) async {
    loading = true; error = null; notifyListeners();
    final res = await apiPost('/auth/send-otp', {'phone': phone});
    loading = false;
    if (res.containsKey('error')) { error = res['error']; notifyListeners(); return false; }
    notifyListeners(); return true;
  }

  Future<bool> verifyOTP(String phone, String otp) async {
    loading = true; error = null; notifyListeners();
    final res = await apiPost('/auth/verify-otp', {'phone': phone, 'otp': otp, 'role': 'merchant'});
    loading = false;
    if (res.containsKey('error')) { error = res['error']; notifyListeners(); return false; }
    token = res['token'];
    user = res['user'];
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token!);
    await p.setString('user', jsonEncode(user));
    await p.setString('user_id', user!['_id']);
    notifyListeners(); return true;
  }

  Future<void> logout() async {
    token = null; user = null; restaurant = null;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    notifyListeners();
  }
}

// ── Orders State ─────────────────────────────────────────────
class OrdersState extends ChangeNotifier {
  List<Map<String,dynamic>> incoming = [];
  List<Map<String,dynamic>> active = [];
  late IO.Socket socket;
  String? restaurantId;

  void init(String restId, String userId) {
    restaurantId = restId;
    socket = IO.io(_socketUrl, IO.OptionBuilder().setTransports(['websocket']).build());
    socket.on('connect', (_) {
      socket.emit('join', {'role': 'merchant', 'restaurantId': restId, 'userId': userId});
    });
    socket.on('new_order', (data) {
      final order = Map<String,dynamic>.from(data);
      if (order['restaurantId'] == restId) {
        incoming.insert(0, order);
        notifyListeners();
      }
    });
    socket.on('order_update', (data) {
      final order = Map<String,dynamic>.from(data);
      _refreshOrder(order);
    });
  }

  void _refreshOrder(Map<String,dynamic> order) {
    final status = order['status'];
    incoming.removeWhere((o) => o['_id'] == order['_id']);
    active.removeWhere((o) => o['_id'] == order['_id']);
    if (['ACCEPTED','PREPARING','READY'].contains(status)) {
      active.insert(0, order);
    }
    notifyListeners();
  }

  Future<void> loadOrders(String restId, String token) async {
    final res = await apiGet('/orders', token: token, params: {'restaurantId': restId});
    final orders = (res['orders'] as List? ?? []).cast<Map<String,dynamic>>();
    incoming = orders.where((o) => o['status'] == 'PLACED').toList();
    active = orders.where((o) => ['ACCEPTED','PREPARING','READY'].contains(o['status'])).toList();
    notifyListeners();
  }

  Future<void> updateStatus(String orderId, String status, String token) async {
    await apiPut('/orders/$orderId/status', {'status': status}, token: token);
  }

  void dispose() { socket.disconnect(); super.dispose(); }
}

// ── Router ───────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', redirect: (ctx, state) async {
      final p = await SharedPreferences.getInstance();
      return p.getString('token') != null ? '/dashboard' : '/login';
    }),
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    GoRoute(path: '/otp', builder: (ctx, state) => OTPScreen(phone: state.extra as String)),
    GoRoute(path: '/setup', builder: (ctx, state) => const RestaurantSetupScreen()),
    GoRoute(path: '/dashboard', builder: (ctx, state) => const DashboardScreen()),
  ],
);

// ── Main ─────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthState()..load()),
      ChangeNotifierProvider(create: (_) => OrdersState()),
    ],
    child: MaterialApp.router(
      title: 'Go Fresh Restaurant',
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

// ── Login Screen ─────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(child: ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.asset('assets/images/gofresh_logo.jpg', width: 100, height: 100, fit: BoxFit.cover))),
          const SizedBox(height: 32),
          const Text('Restaurant Partner', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary)).animate().slideX(begin: -0.3, duration: 400.ms),
          const Text('Login to manage your restaurant', style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(color: _surfaceBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _divider)),
            child: Row(children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('+91', style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 16))),
              Container(width: 1, height: 24, color: _divider),
              Expanded(child: TextField(controller: _ctrl, keyboardType: TextInputType.phone, maxLength: 10,
                style: const TextStyle(color: _textPrimary, fontSize: 18, letterSpacing: 2),
                decoration: const InputDecoration(hintText: '9876543210', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18), counterText: '', filled: false))),
            ]),
          ),
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
        ],
      ))),
    );
  }
}

// ── OTP Screen ────────────────────────────────────────────────
class OTPScreen extends StatefulWidget {
  final String phone;
  const OTPScreen({super.key, required this.phone});
  @override State<OTPScreen> createState() => _OTPScreenState();
}
class _OTPScreenState extends State<OTPScreen> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(backgroundColor: _darkBg, elevation: 0),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Enter OTP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary)),
        Text('Sent to +91 ${widget.phone}', style: const TextStyle(color: _textSecondary)),
        const SizedBox(height: 32),
        TextField(controller: _ctrl, keyboardType: TextInputType.number, maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: 12),
          decoration: InputDecoration(filled: true, fillColor: _surfaceBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), counterText: '')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: auth.loading ? null : () async {
            final ok = await auth.verifyOTP(widget.phone, _ctrl.text.trim());
            if (!mounted) return;
            if (ok) context.go('/dashboard');
          },
          style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: auth.loading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify & Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        )),
        if (auth.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(auth.error!, style: const TextStyle(color: _error))),
      ])),
    );
  }
}

// ── Restaurant Setup ─────────────────────────────────────────
class RestaurantSetupScreen extends StatelessWidget {
  const RestaurantSetupScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Setup coming soon')));
}

// ── Dashboard ─────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  bool _isOpen = true;
  List<Map<String,dynamic>> _restaurants = [];
  String? _selectedRestId;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      _init();
    }
  }

  Future<void> _init() async {
    final auth = context.read<AuthState>();
    if (auth.token == null) return;
    final res = await apiGet('/restaurants/all', token: auth.token);
    final userId = auth.user?['_id'];
    final myRests = (res['restaurants'] as List? ?? [])
        .cast<Map<String,dynamic>>()
        .where((r) => r['ownerId'] == userId)
        .toList();
    if (myRests.isNotEmpty) {
      setState(() {
        _restaurants = myRests;
        _selectedRestId = myRests.first['_id'];
        _isOpen = myRests.first['isOpen'] ?? true;
      });
      final orders = context.read<OrdersState>();
      orders.init(_selectedRestId!, userId ?? '');
      await orders.loadOrders(_selectedRestId!, auth.token!);
    }
  }

  Future<void> _toggleOpen() async {
    if (_selectedRestId == null) return;
    final auth = context.read<AuthState>();
    setState(() => _isOpen = !_isOpen);
    await apiPut('/restaurants/$_selectedRestId', {'isOpen': _isOpen}, token: auth.token);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final orders = context.watch<OrdersState>();
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/gofresh_logo.jpg', width: 32, height: 32, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          const Text('Go Fresh', style: TextStyle(color: _orange, fontWeight: FontWeight.w800)),
          const Text(' Partner', style: TextStyle(color: _textSecondary, fontSize: 14)),
        ]),
        actions: [
          GestureDetector(
            onTap: _toggleOpen,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isOpen ? _success.withOpacity(0.2) : _error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isOpen ? _success : _error),
              ),
              child: Text(_isOpen ? '🟢 OPEN' : '🔴 CLOSED', style: TextStyle(color: _isOpen ? _success : _error, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _IncomingOrdersTab(orders: orders, token: auth.token ?? ''),
          _ActiveOrdersTab(orders: orders, token: auth.token ?? ''),
          _MenuTab(restId: _selectedRestId ?? '', token: auth.token ?? ''),
          _EarningsTab(restId: _selectedRestId ?? '', token: auth.token ?? ''),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: _cardBg, border: Border(top: BorderSide(color: _divider))),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: _orange,
          unselectedItemColor: _textMuted,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: orders.incoming.isNotEmpty,
                label: Text('${orders.incoming.length}', style: const TextStyle(fontSize: 10)),
                backgroundColor: _error,
                child: const Icon(Icons.notifications_active_rounded),
              ),
              label: 'New Orders',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Active'),
            const BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
            const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Earnings'),
          ],
        ),
      ),
    );
  }
}

// ── Incoming Orders Tab ───────────────────────────────────────
class _IncomingOrdersTab extends StatelessWidget {
  final OrdersState orders;
  final String token;
  const _IncomingOrdersTab({required this.orders, required this.token});

  @override
  Widget build(BuildContext context) {
    if (orders.incoming.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🔔', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        Text('No new orders', style: TextStyle(color: _textSecondary, fontSize: 18)),
        Text('New orders will appear here instantly', style: TextStyle(color: _textMuted)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.incoming.length,
      itemBuilder: (ctx, i) => _IncomingOrderCard(order: orders.incoming[i], orders: orders, token: token)
          .animate().slideX(begin: 0.3, duration: 300.ms, delay: (i * 50).ms),
    );
  }
}

class _IncomingOrderCard extends StatelessWidget {
  final Map<String,dynamic> order;
  final OrdersState orders;
  final String token;
  const _IncomingOrderCard({required this.order, required this.orders, required this.token});

  @override
  Widget build(BuildContext context) {
    final customerInfo = order['customerInfo'] ?? {};
    final items = (order['items'] as List? ?? []).cast<Map<String,dynamic>>();
    final pricing = order['pricing'] ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: _orange.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            const Text('🛒', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${order['_id']?.substring(0, 8) ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 15)),
              Text('${items.length} items • ₹${pricing['total']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Text('NEW', style: TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 11))),
          ]),
        ),
        // Customer info
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person, color: _orange, size: 16),
            const SizedBox(width: 6),
            Text(customerInfo['name'] ?? 'Customer', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.phone, color: _textMuted, size: 16),
            const SizedBox(width: 6),
            Text(customerInfo['phone'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          ]),
        ])),
        // Items
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Column(
          children: items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Text('${item['quantity']}x', style: const TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(child: Text(item['name'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 13))),
              Text('₹${((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toStringAsFixed(0)}', style: const TextStyle(color: _textPrimary, fontSize: 13)),
            ]),
          )).toList(),
        )),
        // Buttons
        Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => orders.updateStatus(order['_id'], 'REJECTED', token),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Reject', style: TextStyle(color: _error, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton(
            onPressed: () => orders.updateStatus(order['_id'], 'ACCEPTED', token),
            style: ElevatedButton.styleFrom(backgroundColor: _success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('✓ Accept Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ])),
      ]),
    );
  }
}

// ── Active Orders Tab ─────────────────────────────────────────
class _ActiveOrdersTab extends StatelessWidget {
  final OrdersState orders;
  final String token;
  const _ActiveOrdersTab({required this.orders, required this.token});

  static const _nextStatus = {'ACCEPTED': 'PREPARING', 'PREPARING': 'READY'};
  static const _nextLabel = {'ACCEPTED': 'Start Preparing', 'PREPARING': 'Mark Ready'};
  static const _statusLabel = {'ACCEPTED': '✅ Accepted', 'PREPARING': '👨‍🍳 Preparing', 'READY': '📦 Ready'};

  @override
  Widget build(BuildContext context) {
    if (orders.active.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('📋', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        Text('No active orders', style: TextStyle(color: _textSecondary)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.active.length,
      itemBuilder: (ctx, i) {
        final o = orders.active[i];
        final items = (o['items'] as List? ?? []).cast<Map<String,dynamic>>();
        final customerInfo = o['customerInfo'] ?? {};
        final next = _nextStatus[o['status']];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_statusLabel[o['status']] ?? o['status'], style: const TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
              const Spacer(),
              Text('Order #${o['_id']?.substring(0, 8)}', style: const TextStyle(color: _textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Text('${customerInfo['name'] ?? ''} • ${customerInfo['phone'] ?? ''}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            ...items.map((item) => Text('${item['quantity']}x ${item['name']}', style: const TextStyle(color: _textSecondary, fontSize: 13))),
            if (next != null) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => orders.updateStatus(o['_id'], next, token),
                style: ElevatedButton.styleFrom(backgroundColor: _orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text(_nextLabel[o['status']] ?? 'Update', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _lightGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: _lightGreen, size: 16),
                  SizedBox(width: 6),
                  Text('Ready! Waiting for rider pickup', style: TextStyle(color: _lightGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => BillService.printBill(o),
                  icon: const Icon(Icons.print_rounded, color: _orange, size: 16),
                  label: const Text('Print Bill', style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _orange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => BillService.shareBill(o),
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 16),
                  label: const Text('Share Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: _orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
                )),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

// ── Menu Tab ──────────────────────────────────────────────────
class _MenuTab extends StatefulWidget {
  final String restId;
  final String token;
  const _MenuTab({required this.restId, required this.token});
  @override State<_MenuTab> createState() => _MenuTabState();
}
class _MenuTabState extends State<_MenuTab> {
  List<Map<String,dynamic>> _items = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.restId.isEmpty) { setState(() => _loading = false); return; }
    final res = await apiGet('/menu/restaurant/${widget.restId}');
    setState(() { _items = (res['items'] as List? ?? []).cast<Map<String,dynamic>>(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _orange));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        final available = item['isAvailable'] ?? true;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _divider)),
          child: Row(children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(border: Border.all(color: (item['isVeg'] ?? true) ? _success : _error, width: 1.5), borderRadius: BorderRadius.circular(2)),
              child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: (item['isVeg'] ?? true) ? _success : _error, shape: BoxShape.circle)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '', style: TextStyle(color: available ? _textPrimary : _textMuted, fontWeight: FontWeight.w600)),
              Text('₹${item['price']}', style: const TextStyle(color: _orange, fontWeight: FontWeight.w700)),
            ])),
            Switch(value: available, activeColor: _success, onChanged: (v) async {
              await apiPut('/menu/${item['_id']}', {'isAvailable': v}, token: widget.token);
              setState(() => _items[i]['isAvailable'] = v);
            }),
          ]),
        );
      },
    );
  }
}

// ── Earnings Tab ──────────────────────────────────────────────
class _EarningsTab extends StatefulWidget {
  final String restId;
  final String token;
  const _EarningsTab({required this.restId, required this.token});
  @override State<_EarningsTab> createState() => _EarningsTabState();
}
class _EarningsTabState extends State<_EarningsTab> {
  int _todayOrders = 0;
  double _todayRevenue = 0;
  double _totalRevenue = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.restId.isEmpty) return;
    final res = await apiGet('/orders', token: widget.token, params: {'restaurantId': widget.restId});
    final orders = (res['orders'] as List? ?? []).cast<Map<String,dynamic>>();
    final today = DateTime.now();
    final todayOrders = orders.where((o) {
      final d = DateTime.tryParse(o['createdAt'] ?? '');
      return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
    final delivered = orders.where((o) => o['status'] == 'DELIVERED').toList();
    setState(() {
      _todayOrders = todayOrders.length;
      _todayRevenue = todayOrders.where((o) => o['status'] == 'DELIVERED').fold(0.0, (s, o) => s + ((o['pricing']?['itemsTotal'] as num?) ?? 0).toDouble());
      _totalRevenue = delivered.fold(0.0, (s, o) => s + ((o['pricing']?['itemsTotal'] as num?) ?? 0).toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      _StatCard('Today\'s Orders', '$_todayOrders', Icons.receipt_rounded, _orange),
      const SizedBox(height: 12),
      _StatCard('Today\'s Revenue', '₹${_todayRevenue.toStringAsFixed(0)}', Icons.currency_rupee, _success),
      const SizedBox(height: 12),
      _StatCard('Total Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', Icons.bar_chart, _lightGreen),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)), child: Row(children: [
        const Icon(Icons.info_outline, color: _textMuted, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Go Fresh commission (20%) is deducted from your revenue', style: TextStyle(color: _textSecondary, fontSize: 13))),
      ])),
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _cardBg, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 13)),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
      ]),
    ]),
  );
}
