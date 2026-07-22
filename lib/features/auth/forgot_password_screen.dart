import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../shared/widgets/phone_input_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  int _tab = 1; // 0 = recovery code, 1 = email OTP — email is now the default

  final _phoneKey = GlobalKey<PhoneInputFieldState>();
  String _phoneNormalized = '';
  String _countryDial = '+251';

  final _codeCtrl = TextEditingController();
  final _otpCtrl  = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _newPassConfirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _otpRequested = false;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _newPassConfirmCtrl.dispose();
    super.dispose();
  }

  bool _validateNewPassword() {
    if (_newPassCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return false;
    }
    if (_newPassCtrl.text != _newPassConfirmCtrl.text) {
      setState(() => _error = 'Passwords must match.');
      return false;
    }
    return true;
  }

  Future<void> _resetWithCode() async {
    if (_phoneNormalized.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your recovery code.');
      return;
    }
    if (!_validateNewPassword()) return;

    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final api = ref.read(apiClientProvider);
      await api.postRoot('/auth/forgot-password/recovery-code', data: {
        'phone': _phoneNormalized,
        'countryCode': _countryDial,
        'recoveryCode': _codeCtrl.text.trim(),
        'newPassword': _newPassCtrl.text,
      });
      setState(() { _success = 'Password reset successfully.'; });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestOtp() async {
    if (_phoneNormalized.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.postRoot('/auth/forgot-password/email-otp/request', data: {
        'phone': _phoneNormalized,
        'countryCode': _countryDial,
      });
      final data = res.data as Map<String, dynamic>;
      if (data['hasEmail'] == false) {
        setState(() => _error = "This account doesn't have an email on file. Use your recovery code instead.");
        return;
      }
      setState(() {
        _success = 'If your account has an email on file, a code has been sent.';
        _otpRequested = true;
      });
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    if (!_validateNewPassword()) return;

    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final api = ref.read(apiClientProvider);
      await api.postRoot('/auth/forgot-password/email-otp/verify', data: {
        'phone': _phoneNormalized,
        'countryCode': _countryDial,
        'otp': _otpCtrl.text.trim(),
        'newPassword': _newPassCtrl.text,
      });
      setState(() { _success = 'Password reset successfully.'; });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(dynamic e) {
    final s = e.toString();
    if (s.contains('401')) return 'Invalid or expired code.';
    if (s.contains('429')) return 'Please wait a moment before trying again.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Reset your password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how you would like to recover access to your account.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              _buildTabBar(),
              const SizedBox(height: 20),
              _buildAlerts(),
              _buildForm(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabButton(1, Icons.mail_outline, 'Email code'),
          _tabButton(0, Icons.shield_outlined, 'Recovery code'),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = index;
          _error = null;
          _success = null;
          _otpRequested = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? const Color(0xFF7C3AED) : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlerts() {
    return Column(
      children: [
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
              ],
            ),
          ),
        if (_success != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_success!, style: const TextStyle(color: Color(0xFF047857), fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Phone number'),
        PhoneInputField(
          key: _phoneKey,
          initialCountryDial: _countryDial,
          onChanged: (d, dial, n) {
            _phoneNormalized = n ?? '';
            _countryDial = dial;
          },
        ),
        const SizedBox(height: 16),

        if (_tab == 0) ...[
          _label('Recovery code'),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]'))],
            decoration: _inputDec('XXXX-XXXX-XXXX-XXXX'),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Text(
            'The 16-character code you saved when your account was created.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          _passwordFields(),
          const SizedBox(height: 20),
          _submitBtn(label: 'Reset password', onTap: _resetWithCode),
        ] else ...[
          if (!_otpRequested) ...[
            const SizedBox(height: 8),
            _submitBtn(label: 'Send code to my email', onTap: _requestOtp),
          ] else ...[
            _label('Verification code'),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: _inputDec('000000'),
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 4, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _passwordFields(),
            const SizedBox(height: 20),
            _submitBtn(label: 'Verify and reset', onTap: _verifyOtp),
          ],
        ],
      ],
    );
  }

  Widget _passwordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('New password'),
        TextField(
          controller: _newPassCtrl,
          obscureText: _obscure,
          decoration: _inputDec('••••••••').copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: const Color(0xFF94A3B8)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _label('Confirm new password'),
        TextField(
          controller: _newPassConfirmCtrl,
          obscureText: _obscure,
          decoration: _inputDec('••••••••'),
        ),
      ],
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600)),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      );

  Widget _submitBtn({required String label, required VoidCallback onTap}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label),
      ),
    );
  }
}
