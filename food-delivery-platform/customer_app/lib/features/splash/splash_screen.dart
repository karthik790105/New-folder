import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset('assets/images/gofresh_logo.jpg', fit: BoxFit.cover),
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 32),
            const Text(
              'Go Fresh',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryOrange,
                letterSpacing: 1.5,
              ),
            ).animate().slideY(begin: 0.5, duration: 500.ms, delay: 300.ms).fadeIn(),
            const SizedBox(height: 8),
            const Text(
              'Food, Grocery & Meat Delivery',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 8),
            const Text(
              'From Our Store to Your Door ❤️',
              style: TextStyle(fontSize: 12, color: AppTheme.lightGreen, fontStyle: FontStyle.italic),
            ).animate().fadeIn(delay: 700.ms),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              color: AppTheme.primaryOrange,
              strokeWidth: 2,
            ).animate().fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}
