import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/utils/password_gen.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _isAm => appLocale == 'am';

  Future<void> _submit() async {
    if (_newCtrl.text.length < 6) {
      setState(() => _error = _isAm ? 'ፓስዎርድ ቢያንስ 6 ቁምፊ መሆን አለበት።' : 'Password must be at least 6 characters.');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = _isAm ? 'ፓስዎርዶች መመሳሰል አለባቸው።' : 'Passwords must match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      await api.postRoot('/auth/first-login/change-password', data: {'newPassword': _newCtrl.text});
      await ref.read(authProvider.notifier).clearMustChangePassword();
      if (!mounted) return;
      context.go('/bookings');
    } catch (e) {
      setState(() { _error = _extract(e); _loading = false; });
    }
  }

  String _extract(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return (data['message'] ?? data['error'] ?? 'Error').toString();
    } catch (_) {}
    return _isAm ? 'ስህተት ተከስቷል' : 'Something went wrong';
  }

  void _generate() {
    final pw = generatePassword();
    setState(() {
      _newCtrl.text = pw;
      _confirmCtrl.text = pw;
      _obscure = false;
    });
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final am = _isAm;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(
                            am ? 'አዲስ ፓስዎርድ ያዘጋጁ' : 'Set a new password',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: 0.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      am ? 'ወደ GizeBit እንኳን ደህና መጡ' : 'Welcome to GizeBit',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      am
                          ? 'ከመቀጠልዎ በፊት ለመለያዎ አዲስ ፓስዎርድ ያዘጋጁ።'
                          : 'Before you continue, please set a new password for your account.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        am
                            ? 'የገቡት በጊዜያዊ ፓስዎርድ ነው። ይህ አንድ ጊዜ ብቻ ይሠራል — መለያዎን ለማጠናከር ከታች አዲስ ይምረጡ።'
                            : "You signed in with a temporary password. It only works once — pick a new one below to secure your account.",
                        style: const TextStyle(color: Color(0xFF92400E), fontSize: 12.5, height: 1.5),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(am ? 'አዲስ ፓስዎርድ' : 'New password',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: _dec(am ? 'ቢያንስ 6 ቁምፊ' : 'At least 6 characters', Icons.lock_outline_rounded).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20, color: const Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(am ? 'አዲሱን ፓስዎርድ ያረጋግጡ' : 'Confirm new password',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: _dec('', Icons.lock_outline_rounded),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _generate,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F0FF),
                          foregroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        icon: const Icon(Icons.auto_fix_high, size: 14),
                        label: Text(am ? 'ጠንካራ ፓስዎርድ ጠቁመኝ' : 'Suggest a strong password'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _loading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          am ? 'አስቀምጥ እና ቀጥል' : 'Save and continue',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, size: 14, color: Color(0xFF94A3B8)),
                        label: Text(
                          am ? 'ውጣ' : 'Sign out',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
      );
}
