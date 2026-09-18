import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _verifying = false;
  int _resendTimer = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _focusNodes[0].requestFocus();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(String val, int index) {
    if (val.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    setState(() => _verifying = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOTP(widget.phone, _otp);
    setState(() => _verifying = false);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Invalid OTP'), backgroundColor: AppTheme.error),
      );
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    await auth.sendOTP(widget.phone);
    setState(() => _resendTimer = 30);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(backgroundColor: AppTheme.darkBg, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verify OTP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))
                .animate().slideX(begin: -0.3, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to +91 ${widget.phone}',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 40),
            // OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => _OtpBox(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                onChanged: (v) => _onChanged(v, i),
                onBackspace: () => _onBackspace(i),
              )),
            ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 300.ms),
            const SizedBox(height: 40),
            // Verify button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppTheme.primaryOrange,
                ),
                child: _verifying
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 400.ms),
            const SizedBox(height: 24),
            Center(
              child: _resendTimer > 0
                  ? Text('Resend OTP in ${_resendTimer}s', style: const TextStyle(color: AppTheme.textSecondary))
                  : TextButton(
                      onPressed: _resend,
                      child: const Text('Resend OTP', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w600)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focusNode.hasFocus ? AppTheme.primaryOrange : AppTheme.divider, width: 2),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event.character == null && controller.text.isEmpty) onBackspace();
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: 1,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          decoration: const InputDecoration(border: InputBorder.none, counterText: '', filled: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
