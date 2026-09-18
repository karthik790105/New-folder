import 'dart:convert';
import 'live_map_screen.dart';
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

class AuthState extends ChangeNotifier {
  String? token;
  Map<String,dynamic>? user;
  Map<String,dynamic>? rider;
  bool loading = false;
  String? error;
  bool get isLoggedIn => token != null;

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
    final res = await _post('/auth/verify-otp', {'phone': phone, 'otp': otp, 'role': 'rider'});
    loading = false;
    if (res.containsKey('error')) { error = res['error']; notifyListeners(); return false; }
    token = res['token'];
    user = res['user'];
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token!);
    await p.setString('user', jsonEncode(user));
    // Fetch or create rider profile
    await _loadRider();
    notifyListeners(); return true;
  }

  Future<void> _loadRider() async {
    if (user == null) return;
    final res = await _get('/riders', token: token);
    final riders = (res['riders'] as List? ?? []).cast<Map<String,dynamic>>();
    final myRider = riders.where((r) => r['userId'] == user!['_id']).firstOrNull;
    if (myRider != null) {
      rider = myRider;
    } else {
      // Create rider profile
      final cr = await _post('/riders', {
        'userId': user!['_id'],
        'name': user!['name'],
        'phone': user!['phone'],
        'vehicleType': 'bike',
      }, t: token);
      rider = cr['rider'];
    }
    final p = await SharedPreferences.getInstance();
    if (rider != null) await p.setString('rider_id', rider!['_id']);
  }

  Future<void> logout() async {
    token = null; user = null; rider = null;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    notifyListeners();
  }
}

class RiderState extends ChangeNotifier {
  bool isOnline = false;
  List<Map<String,dynamic>> incoming = [];
  Map<String,dynamic>? activeOrder;
  double todayEarnings = 0;
  double totalEarnings = 0;
  int totalDeliveries = 0;
  late IO.Socket socket;
  String? riderId;
  String? token;

  void init(String rId, String t) {
    riderId = rId;
    token = t;
    socket = IO.io(_sock, IO.OptionBuilder().setTransports(['websocket']).build());
    socket.on('connect', (_) {
      socket.emit('join', {'role': 'rider', 'riderId': rId});
      if (isOnline) socket.emit('rider_online', {'riderId': rId});
    });
    socket.on('new_order', (data) {
      if (isOnline) {
        incoming.insert(0, Map<String,dynamic>.from(data));
        notifyListeners();
      }
    });
    socket.on('order_update', (data) {
      final o = Map<String,dynamic>.from(data);
      if (o['riderId'] == riderId) { activeOrder = o; notifyListeners(); }
    });
    socket.on('account_suspended', (data) {
      isOnline = false; notifyListeners();
    });
    _loadRiderData(rId, t);
  }

  Future<void> _loadRiderData(String rId, String t) async {
    final res = await _get('/riders/$rId', t: t);
    if (res.containsKey('rider')) {
      final r = res['rider'] as Map<String,dynamic>;
      todayEarnings = (r['todayEarnings'] as num?)?.toDouble() ?? 0;
      totalEarnings = (r['totalEarnings'] as num?)?.toDouble() ?? 0;
      totalDeliveries = r['totalDeliveries'] ?? 0;
      isOnline = r['isOnline'] ?? false;
      notifyListeners();
    }
    // Load active order if any
    final ordRes = await _get('/orders', t: t, q: {'riderId': rId});
    final orders = (ordRes['orders'] as List? ?? []).cast<Map<String,dynamic>>();
    final active = orders.where((o) => ['DISPATCHED','PICKED_UP'].contains(o['status'])).firstOrNull;
    if (active != null) { activeOrder = active; notifyListeners(); }
  }

  Future<void> toggleOnline(bool val) async {
    isOnline = val;
    notifyListeners();
    await _put('/riders/$riderId/status', {'isOnline': val, 'isAvailable': val}, t: token);
    if (val) socket.emit('rider_online', {'riderId': riderId});
    else socket.emit('rider_offline', {'riderId': riderId});
  }

  Future<void> acceptOrder(Map<String,dynamic> order) async {
    final orderId = order['_id'];
    incoming.removeWhere((o) => o['_id'] == orderId);
    activeOrder = order;
    notifyListeners();
    await _put('/orders/$orderId/status', {'status': 'DISPATCHED', 'riderId': riderId}, t: token);
  }

  Future<void> markPickedUp() async {
    if (activeOrder == null) return;
    await _put('/orders/${activeOrder!['_id']}/status', {'status': 'PICKED_UP'}, t: token);
  }

  Future<String?> verifyDeliveryOTP(String otp) async {
    if (activeOrder == null) return 'No active order';
    final res = await _post('/orders/${activeOrder!['_id']}/verify-otp', {'otp': otp}, t: token);
    if (res.containsKey('error')) return res['error'];
    activeOrder = null;
    todayEarnings += (res['order']?['riderEarnings'] as num?)?.toDouble() ?? 0;
    totalDeliveries += 1;
    notifyListeners();
    return null; // success
  }

  void dispose() { socket.disconnect(); super.dispose(); }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', redirect: (ctx, state) async {
      final p = await SharedPreferences.getInstance();
      return p.getString('token') != null ? '/home' : '/login';
    }),
    GoRoute(path: '/login', builder: (ctx, state) => const _LoginScreen()),
    GoRoute(path: '/otp', builder: (ctx, state) => _OTPScreen(phone: state.extra as String)),
    GoRoute(path: '/home', builder: (ctx, state) => const _HomeScreen()),
    GoRoute(path: '/delivery', builder: (ctx, state) => const _DeliveryScreen()),
    GoRoute(path: '/otp-entry', builder: (ctx, state) => const _OTPEntryScreen()),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthState()..load()),
      ChangeNotifierProvider(create: (_) => RiderState()),
    ],
    child: MaterialApp.router(
      title: 'Go Fresh Rider',
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

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({super.key});
  @override State<_LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<_LoginScreen> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 40),
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.asset('assets/images/gofresh_logo.jpg', width: 100, height: 100, fit: BoxFit.cover))),
        const SizedBox(height: 32),
        const Text('Delivery Partner', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary)).animate().slideX(begin: -0.3, duration: 400.ms),
        const Text('Login to start delivering', style: TextStyle(color: _textSecondary)),
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
      ]))),
    );
  }
}

class _OTPScreen extends StatefulWidget {
  final String phone;
  const _OTPScreen({super.key, required this.phone});
  @override State<_OTPScreen> createState() => _OTPScreenState();
}
class _OTPScreenState extends State<_OTPScreen> {
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
            if (ok) {
              final rider = context.read<AuthState>().rider;
              if (rider != null) {
                context.read<RiderState>().init(rider['_id'], context.read<AuthState>().token!);
              }
              context.go('/home');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: auth.loading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify & Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        )),
        if (auth.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(auth.error!, style: const TextStyle(color: _error))),
      ])),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({super.key});
  @override State<_HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<_HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<RiderState>();
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/gofresh_logo.jpg', width: 32, height: 32, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Go Fresh', style: TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Delivery Partner', style: TextStyle(color: _textMuted, fontSize: 11)),
          ]),
        ]),
        actions: [
          GestureDetector(
            onTap: () => rider.toggleOnline(!rider.isOnline),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rider.isOnline ? _success.withOpacity(0.2) : _surfaceBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: rider.isOnline ? _success : _divider),
              ),
              child: Text(rider.isOnline ? '🟢 Online' : '⚫ Offline', style: TextStyle(color: rider.isOnline ? _success : _textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        _buildDashboard(rider),
        _buildIncoming(rider),
        _buildEarnings(rider),
      ]),
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
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
              icon: Badge(isLabelVisible: rider.incoming.isNotEmpty, label: Text('${rider.incoming.length}', style: const TextStyle(fontSize: 10)), backgroundColor: _error, child: const Icon(Icons.notifications_rounded)),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.wallet_rounded), label: 'Earnings'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(RiderState rider) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (rider.activeOrder != null) ...[
        GestureDetector(
          onTap: () => context.push('/delivery'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A1500), _orange]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Text('🛵', style: TextStyle(fontSize: 28)),
                SizedBox(width: 10),
                Text('Active Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              Text('Order #${rider.activeOrder!['_id']?.substring(0, 8) ?? ''}', style: const TextStyle(color: Colors.white70)),
              Text('Status: ${rider.activeOrder!['status']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Tap to view details →', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ).animate().pulse(duration: 2000.ms),
        const SizedBox(height: 16),
      ] else if (!rider.isOnline) ...[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _divider)),
          child: const Column(children: [
            Text('⚫', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('You are Offline', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Go online to receive delivery requests', style: TextStyle(color: _textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      // Stats row
      Row(children: [
        Expanded(child: _MiniStat('Today', '₹${rider.todayEarnings.toStringAsFixed(0)}', Icons.today_rounded, _orange)),
        const SizedBox(width: 12),
        Expanded(child: _MiniStat('Deliveries', '${rider.totalDeliveries}', Icons.local_shipping_rounded, _lightGreen)),
      ]),
    ]);
  }

  Widget _buildIncoming(RiderState rider) {
    if (!rider.isOnline) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('⚫', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        Text('Go online to receive orders', style: TextStyle(color: _textSecondary)),
      ]));
    }
    if (rider.incoming.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🔔', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        Text('Waiting for orders...', style: TextStyle(color: _textSecondary, fontSize: 18)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rider.incoming.length,
      itemBuilder: (ctx, i) => _IncomingOrderCard(order: rider.incoming[i], riderState: rider),
    );
  }

  Widget _buildEarnings(RiderState rider) {
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      _StatCard('Today\'s Earnings', '₹${rider.todayEarnings.toStringAsFixed(0)}', Icons.today_rounded, _orange),
      const SizedBox(height: 12),
      _StatCard('Total Earnings', '₹${rider.totalEarnings.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, _success),
      const SizedBox(height: 12),
      _StatCard('Total Deliveries', '${rider.totalDeliveries}', Icons.local_shipping_rounded, _lightGreen),
    ]));
  }
}

class _IncomingOrderCard extends StatelessWidget {
  final Map<String,dynamic> order;
  final RiderState riderState;
  const _IncomingOrderCard({required this.order, required this.riderState});

  @override
  Widget build(BuildContext context) {
    final customerInfo = order['customerInfo'] ?? {};
    final items = (order['items'] as List? ?? []).cast<Map<String,dynamic>>();
    final pricing = order['pricing'] ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withOpacity(0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            const Text('🛒', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${items.length} items • ₹${pricing['total']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
              Text('Earn: ₹${((pricing['deliveryFee'] as num? ?? 10) + 20).toStringAsFixed(0)}', style: const TextStyle(color: _success, fontWeight: FontWeight.w600, fontSize: 13)),
            ])),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Customer info
          Row(children: [const Icon(Icons.person, color: _orange, size: 16), const SizedBox(width: 6), Text(customerInfo['name'] ?? 'Customer', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.phone, color: _textMuted, size: 16), const SizedBox(width: 6), Text(customerInfo['phone'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 13))]),
          const SizedBox(height: 8),
          // Items
          ...items.map((item) => Text('${item['quantity']}x ${item['name']}', style: const TextStyle(color: _textSecondary, fontSize: 13))),
          const SizedBox(height: 12),
          // Accept button
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              riderState.acceptOrder(order);
              context.push('/delivery');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('✓ Accept Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          )),
          const SizedBox(height: 14),
        ])),
      ]),
    );
  }
}

class _DeliveryScreen extends StatelessWidget {
  const _DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<RiderState>();
    final order = rider.activeOrder;
    if (order == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
      return const SizedBox();
    }
    final customerInfo = order['customerInfo'] ?? {};
    final items = (order['items'] as List? ?? []).cast<Map<String,dynamic>>();
    final status = order['status'];
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(title: const Text('Active Delivery'), backgroundColor: _darkBg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Status
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: status == 'PICKED_UP' ? [const Color(0xFF1B5E20), _success] : [const Color(0xFF4A1500), _orange]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Text(status == 'DISPATCHED' ? '🛵 Head to Restaurant' : status == 'PICKED_UP' ? '🏃 Head to Customer' : '📋 $status',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Order #${order['_id']?.substring(0, 8) ?? ''}', style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        // Customer info
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Customer Info', style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.person, color: _orange, size: 18), const SizedBox(width: 8), Text(customerInfo['name'] ?? '', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 16))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.phone, color: _textMuted, size: 18), const SizedBox(width: 8), Text(customerInfo['phone'] ?? '', style: const TextStyle(color: _textSecondary))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.location_on, color: _error, size: 18), const SizedBox(width: 8), Expanded(child: Text(order['deliveryAddress']?['address'] ?? '', style: const TextStyle(color: _textSecondary)))]),
        ])),
        const SizedBox(height: 12),
        // Items
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Order Items', style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Text('${item['quantity']}x', style: const TextStyle(color: _orange, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(child: Text(item['name'] ?? '', style: const TextStyle(color: _textPrimary))),
            Text('₹${((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary)),
          ]))),
        ])),
        const SizedBox(height: 20),
        // Live Map button – always visible during active delivery
        OutlinedButton.icon(
          onPressed: () {
            final riderId = context.read<RiderState>().riderId ?? '';
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => LiveMapScreen(order: order, riderId: riderId),
            ));
          },
          icon: const Icon(Icons.map_rounded, color: _orange, size: 18),
          label: const Text('View Live Map', style: TextStyle(color: _orange, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _orange),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        if (status == 'DISPATCHED') SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => rider.markPickedUp(),
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text('Confirm Pickup from Restaurant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: _success, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        if (status == 'PICKED_UP') SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => context.push('/otp-entry'),
          icon: const Icon(Icons.lock_open, color: Colors.white),
          label: const Text('Enter Delivery OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    );
  }
}

class _OTPEntryScreen extends StatefulWidget {
  const _OTPEntryScreen({super.key});
  @override State<_OTPEntryScreen> createState() => _OTPEntryScreenState();
}
class _OTPEntryScreenState extends State<_OTPEntryScreen> {
  final _ctrl = TextEditingController();
  bool _verifying = false;
  String? _error;

  Future<void> _verify() async {
    final otp = _ctrl.text.trim();
    if (otp.length != 4) { setState(() => _error = 'OTP must be 4 digits'); return; }
    setState(() { _verifying = true; _error = null; });
    final rider = context.read<RiderState>();
    final err = await rider.verifyDeliveryOTP(otp);
    setState(() => _verifying = false);
    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Delivery completed! Earnings updated.'), backgroundColor: _success));
      context.go('/home');
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(title: const Text('Delivery OTP'), backgroundColor: _darkBg),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        const SizedBox(height: 40),
        const Text('🔐', style: TextStyle(fontSize: 80)).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text('Enter Customer OTP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _textPrimary)),
        const SizedBox(height: 8),
        const Text('Ask the customer to tell you their 4-digit OTP', style: TextStyle(color: _textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 40),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _orange, letterSpacing: 12),
          decoration: InputDecoration(
            filled: true, fillColor: _surfaceBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _orange, width: 2)),
            counterText: '',
            hintText: '_ _ _ _',
            hintStyle: TextStyle(color: _textMuted.withOpacity(0.5), fontSize: 40, letterSpacing: 12),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: _error))],
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _verifying ? null : _verify,
          style: ElevatedButton.styleFrom(backgroundColor: _success, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _verifying ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Confirm Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        )),
      ])),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
    ]),
  );
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
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
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
