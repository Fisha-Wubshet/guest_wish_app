import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/api/api_client.dart';
import '../../shared/widgets/phone_input_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _serverCtrl = TextEditingController(text: 'https://rent.gizebit.com');
  String _phone = '';
  String _dial = '+251';
  bool _obscure = true;
  bool _showServerUrl = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _serverCtrl.text = prefs.getString('server_url') ?? 'https://rent.gizebit.com';
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_phone.isEmpty) return;
    if (_showServerUrl) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', _serverCtrl.text.trim());
      ref.read(apiClientProvider).updateBaseUrl(_serverCtrl.text.trim());
    }
    await ref.read(authProvider.notifier).loginByPhone(_phone, _dial, _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),   // soft neutral so the card pops
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                // Fill at least the viewport so Center below can actually center.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // ── Logo + tagline (centered above the card)
                Image.asset('assets/gizebit_logo.png', height: 54),
                const SizedBox(height: 10),
                const Text(
                  'Sign in to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Card holding the form
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (auth.error != null) ...[
                          _errorBox(auth.error!),
                          const SizedBox(height: 16),
                        ],
                        _fieldLabel('Phone number'),
                        const SizedBox(height: 6),
                        PhoneInputField(
                          initialCountryDial: _dial,
                          hint: '912 345 678',
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter your phone number' : null,
                          onChanged: (_, d, n) { _phone = n ?? ''; _dial = d; },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            _fieldLabel('Password'),
                            const Spacer(),
                            InkWell(
                              onTap: () => context.push('/forgot-password'),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Forgot?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 20, color: Color(0xFF94A3B8)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20, color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                        ),

                        if (_showServerUrl) ...[
                          const SizedBox(height: 16),
                          _fieldLabel('Server URL'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _serverCtrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              hintText: 'e.g. http://192.168.1.1:8080',
                              prefixIcon: Icon(Icons.dns_outlined,
                                  size: 20, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.4),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Sign In'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showServerUrl = !_showServerUrl),
                    icon: Icon(
                      _showServerUrl ? Icons.expand_less : Icons.settings_outlined,
                      size: 14, color: const Color(0xFF94A3B8),
                    ),
                    label: Text(
                      _showServerUrl ? 'Hide server settings' : 'Configure server URL',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
          letterSpacing: 0.1,
        ),
      );

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );
}
