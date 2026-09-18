import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/models/models.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/home/home_screen.dart';
import 'features/store/store_detail_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/tracking/order_tracking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const GoFreshApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    GoRoute(
      path: '/otp',
      builder: (ctx, state) => OtpScreen(phone: state.extra as String),
    ),
    GoRoute(path: '/home', builder: (ctx, state) => const HomeScreen()),
    GoRoute(
      path: '/store/:id',
      builder: (ctx, state) => StoreDetailScreen(store: state.extra as StoreModel),
    ),
    GoRoute(path: '/cart', builder: (ctx, state) => const CartScreen()),
    GoRoute(
      path: '/tracking/:id',
      builder: (ctx, state) => OrderTrackingScreen(orderId: state.pathParameters['id']!),
    ),
  ],
);

class GoFreshApp extends StatelessWidget {
  const GoFreshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp.router(
        title: 'Go Fresh',
        theme: AppTheme.darkTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
