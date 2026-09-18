import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color _orange = Color(0xFFFF6B00);
const Color _success = Color(0xFF4CAF50);
const Color _error = Color(0xFFE53935);
const Color _darkBg = Color(0xFF1A1A1A);
const Color _cardBg = Color(0xFF242424);
const Color _textPrimary = Color(0xFFFFFFFF);
const Color _textSecondary = Color(0xFFB0B0B0);
const Color _textMuted = Color(0xFF757575);
const String _base = 'http://10.0.2.2:5000/api';

Future<void> _put(String p, Map body, {String? t}) async {
  try {
    final h = {'Content-Type': 'application/json', if (t != null) 'Authorization': 'Bearer $t'};
    await http.put(Uri.parse('$_base$p'), headers: h, body: jsonEncode(body)).timeout(const Duration(seconds: 10));
  } catch (_) {}
}

/// Full-screen live map for the rider showing their GPS position,
/// restaurant pin, and customer delivery pin.
class LiveMapScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final String riderId;

  const LiveMapScreen({super.key, required this.order, required this.riderId});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _mapController = MapController();
  LatLng? _riderPosition;
  StreamSubscription<Position>? _locationSub;
  String? _token;
  bool _centered = false;

  // Fixed pins from order data
  late final LatLng _restaurantPin;
  late final LatLng _customerPin;
  bool _headingToCustomer = false;

  @override
  void initState() {
    super.initState();
    _restaurantPin = LatLng(
      (widget.order['restaurantLocation']?['lat'] as num?)?.toDouble() ?? 12.9716,
      (widget.order['restaurantLocation']?['lng'] as num?)?.toDouble() ?? 77.5946,
    );
    _customerPin = LatLng(
      (widget.order['deliveryAddress']?['lat'] as num?)?.toDouble() ?? 12.9800,
      (widget.order['deliveryAddress']?['lng'] as num?)?.toDouble() ?? 77.6000,
    );
    _headingToCustomer = widget.order['status'] == 'PICKED_UP';
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await _requestPermission();
    _startTracking();
  }

  Future<void> _requestPermission() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
  }

  void _startTracking() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 metres
      ),
    ).listen((pos) {
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _riderPosition = loc);

      // Auto-center map on first fix
      if (!_centered) {
        _mapController.move(loc, 15);
        _centered = true;
      }

      // Broadcast position to backend for live tracking
      _put('/riders/${widget.riderId}/location', {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'orderId': widget.order['_id'],
      }, t: _token);
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  LatLng get _destinationPin =>
      _headingToCustomer ? _customerPin : _restaurantPin;

  String get _destinationLabel =>
      _headingToCustomer ? '🏠 Customer' : '🍽️ Restaurant';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          // ── Full-screen OpenStreetMap ──────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _restaurantPin,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gofresh.rider',
              ),
              MarkerLayer(markers: [
                // Rider marker (blue pulsing dot)
                if (_riderPosition != null)
                  Marker(
                    point: _riderPosition!,
                    width: 48,
                    height: 48,
                    child: _PulsingDot(color: Colors.blue),
                  ),
                // Restaurant pin
                Marker(
                  point: _restaurantPin,
                  width: 40,
                  height: 40,
                  child: const _MapPin(emoji: '🍽️', color: _orange),
                ),
                // Customer delivery pin
                Marker(
                  point: _customerPin,
                  width: 40,
                  height: 40,
                  child: const _MapPin(emoji: '🏠', color: _success),
                ),
              ]),
            ],
          ),

          // ── Top overlay: back + title ─────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(Icons.navigation_rounded,
                          color: _orange, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _headingToCustomer
                            ? 'Heading to Customer'
                            : 'Heading to Restaurant',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom info card ──────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.flag_rounded,
                        label: 'Destination',
                        value: _destinationLabel,
                        color: _headingToCustomer ? _success : _orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.my_location_rounded,
                        label: 'GPS',
                        value: _riderPosition != null
                            ? '${_riderPosition!.latitude.toStringAsFixed(4)},\n${_riderPosition!.longitude.toStringAsFixed(4)}'
                            : 'Acquiring…',
                        color: Colors.blue,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Recenter button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_riderPosition != null) {
                          _mapController.move(_riderPosition!, 15);
                        }
                      },
                      icon: const Icon(Icons.my_location_rounded,
                          color: _orange, size: 16),
                      label: const Text('Center on My Location',
                          style: TextStyle(
                              color: _orange, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _orange),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 4)
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1000.ms)
          .then()
          .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8), duration: 1000.ms),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String emoji;
  final Color color;
  const _MapPin({required this.emoji, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
        CustomPaint(size: const Size(10, 6), painter: _TrianglePainter(color)),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ]),
    );
  }
}
