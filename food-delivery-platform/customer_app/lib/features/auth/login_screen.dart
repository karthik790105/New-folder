import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _sendOTP() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number'), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOTP(phone);
    setState(() => _sending = false);
    if (!mounted) return;
    if (ok) {
      context.push('/otp', extra: phone);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed to send OTP'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Logo
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.3), blurRadius: 20)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset('assets/images/gofresh_logo.jpg', fit: BoxFit.cover),
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 40),
              const Text('Welcome to', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary))
                  .animate().fadeIn(delay: 200.ms),
              const Text(
                'Go Fresh! 🍃',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 200.ms),
              const SizedBox(height: 8),
              const Text(
                'Enter your mobile number to get started',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 40),
              // Phone input
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ),
                    Container(width: 1, height: 24, color: AppTheme.divider),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary, letterSpacing: 2),
                        decoration: const InputDecoration(
                          hintText: '9876543210',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          counterText: '',
                          filled: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 24),
              // Send OTP button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppTheme.primaryOrange,
                  ),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send OTP via SMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 600.ms),
              const Spacer(),
              // Footer
              Center(
                child: Column(
                  children: [
                    const Text('🛵 Fast Delivery', style: TextStyle(color: AppTheme.lightGreen, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('From Our Store to Your Door ❤️',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
