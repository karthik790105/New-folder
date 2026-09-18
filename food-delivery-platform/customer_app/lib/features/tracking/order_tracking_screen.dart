import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/constants/app_constants.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  OrderModel? _order;
  bool _loading = true;
  late IO.Socket _socket;
  double? _riderLat;
  double? _riderLng;

  final _statuses = ['PLACED', 'ACCEPTED', 'PREPARING', 'READY', 'DISPATCHED', 'PICKED_UP', 'DELIVERED'];
  final _statusLabels = {
    'PLACED': 'Order Placed',
    'ACCEPTED': 'Order Accepted',
    'PREPARING': 'Preparing Your Order',
    'READY': 'Ready for Pickup',
    'DISPATCHED': 'Rider Dispatched',
    'PICKED_UP': 'Order Picked Up',
    'DELIVERED': 'Delivered! 🎉',
    'REJECTED': 'Order Rejected',
    'CANCELLED': 'Order Cancelled',
  };
  final _statusIcons = {
    'PLACED': '📋',
    'ACCEPTED': '✅',
    'PREPARING': '👨‍🍳',
    'READY': '📦',
    'DISPATCHED': '🛵',
    'PICKED_UP': '🏃',
    'DELIVERED': '🎉',
  };

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _connectSocket();
  }

  Future<void> _loadOrder() async {
    final result = await ApiClient.get('/orders/${widget.orderId}', auth: true);
    if (result.containsKey('order')) {
      setState(() {
        _order = OrderModel.fromJson(result['order']);
        _loading = false;
      });
    }
  }

  void _connectSocket() {
    _socket = IO.io(AppConstants.socketUrl, IO.OptionBuilder().setTransports(['websocket']).build());
    _socket.on('connect', (_) {
      _socket.emit('track_order', {'orderId': widget.orderId});
    });
    _socket.on('order_status_changed', (data) {
      if (mounted && data['_id'] == widget.orderId) {
        setState(() => _order = OrderModel.fromJson(Map<String, dynamic>.from(data)));
      }
    });
    _socket.on('order_update', (data) {
      if (mounted && data['_id'] == widget.orderId) {
        setState(() => _order = OrderModel.fromJson(Map<String, dynamic>.from(data)));
      }
    });
    // Live rider GPS position updates
    _socket.on('rider_location', (data) {
      if (mounted) {
        setState(() {
          _riderLat = (data['lat'] as num?)?.toDouble();
          _riderLng = (data['lng'] as num?)?.toDouble();
        });
      }
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  int get _currentStep {
    if (_order == null) return 0;
    final idx = _statuses.indexOf(_order!.status);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: AppTheme.darkBg,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.primaryOrange), onPressed: _loadOrder),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : _order == null
              ? const Center(child: Text('Order not found', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Status card
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    // OTP display (show when PICKED_UP)
                    if (_order!.status == 'PICKED_UP' && _order!.deliveryOTP != null)
                      _buildOTPCard().animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                    // Live rider location (show when rider is on the way)
                    if (['DISPATCHED', 'PICKED_UP'].contains(_order!.status) && _riderLat != null)
                      _buildRiderLocationCard(),
                    // Timeline
                    const SizedBox(height: 8),
                    const Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildTimeline(),
                    const SizedBox(height: 20),
                    // Order summary
                    _buildOrderSummary(),
                  ],
                ),
    );
  }

  Widget _buildStatusCard() {
    final status = _order!.status;
    final isDelivered = status == 'DELIVERED';
    final isCancelled = status == 'CANCELLED' || status == 'REJECTED';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDelivered
              ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)]
              : isCancelled
                  ? [const Color(0xFF7B1111), const Color(0xFFB71C1C)]
                  : [const Color(0xFF4A1500), AppTheme.primaryOrange],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(_statusIcons[status] ?? '📋', style: const TextStyle(fontSize: 48))
              .animate(onPlay: (c) => c.repeat())
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOut)
              .then()
              .scale(begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9), duration: 1000.ms, curve: Curves.easeInOut),
          const SizedBox(height: 12),
          Text(_statusLabels[status] ?? status,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Order #${_order!.id.substring(0, 8)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (!isDelivered && !isCancelled) ...[
            const SizedBox(height: 16),
            // Progress bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / _statuses.length,
              backgroundColor: Colors.white24,
              color: Colors.white,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiderLocationCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withOpacity(0.5), width: 1.5),
      ),
      child: Row(children: [
        // Pulsing dot
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.5), blurRadius: 8, spreadRadius: 3)],
          ),
        ).animate(onPlay: (c) => c.repeat())
          .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.3, 1.3), duration: 900.ms)
          .then().scale(begin: const Offset(1.3, 1.3), end: const Offset(0.7, 0.7), duration: 900.ms),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rider Live Location', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${_riderLat!.toStringAsFixed(5)}, ${_riderLng!.toStringAsFixed(5)}',
            style: const TextStyle(color: AppTheme.success, fontSize: 12, fontFamily: 'monospace'),
          ),
          const Text('Updates every ~10 metres', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        const Icon(Icons.navigation_rounded, color: AppTheme.success, size: 22),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }

  Widget _buildOTPCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryOrange, width: 2),
      ),
      child: Column(
        children: [
          const Text('🔐 Delivery OTP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            _order!.deliveryOTP!,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryOrange,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this OTP with your delivery partner to confirm delivery',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final timeline = _order!.timeline;
    return Column(
      children: List.generate(timeline.length, (i) {
        final t = timeline[i];
        final isLast = i == timeline.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: isLast ? AppTheme.primaryOrange : AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast) Container(width: 2, height: 40, color: AppTheme.divider),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusLabels[t.status] ?? t.status,
                        style: TextStyle(color: isLast ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    if (t.note.isNotEmpty)
                      Text(t.note, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    Text(_formatTime(t.timestamp), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    if (!isLast) const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildOrderSummary() {
    final pricing = _order!.pricing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 15)),
          const SizedBox(height: 12),
          ..._order!.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text('${item.quantity}x ${item.name}', style: const TextStyle(color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text('₹${(item.price * item.quantity).toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              )),
          if (pricing != null) ...[
            const Divider(color: AppTheme.divider, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                Text('₹${pricing['total']?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
