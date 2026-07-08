import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/auth_state.dart';
import '../../core/api/api_client.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../shared/widgets/branch_chip.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _serverCtrl.text = prefs.getString('server_url') ?? 'http://10.0.2.2:8001';
    setState(() {});
  }

  Future<void> _saveServerUrl() async {
    final url = _serverCtrl.text.trim();
    if (url.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    ref.read(apiClientProvider).updateBaseUrl(url);
    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server URL saved'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.settings.signOutConfirm),
        content: Text(S.settings.signOutMessage),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: Text(S.common.cancel)),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(S.settings.signOutConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final locale = ref.watch(localeProvider);
    final isAmharic = locale == 'am';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(S.nav.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null) _buildProfile(user),
            const SizedBox(height: 16),
            if (user != null && user.isShopAdmin) ...[
              _buildBranchSection(user),
              const SizedBox(height: 12),
            ],
            if (user != null && user.isManager) ...[
              _buildSection(S.settings.manage, [
                _SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  title: S.settings.items,
                  subtitle: S.settings.itemsSub,
                  onTap: () => context.push('/items'),
                ),
                _SettingsTile(
                  icon: Icons.category_outlined,
                  title: S.settings.categories,
                  subtitle: S.settings.categoriesSub,
                  onTap: () => context.push('/categories'),
                ),
                if (user.isShopAdmin) ...[
                  _SettingsTile(
                    icon: Icons.people_outline_rounded,
                    title: S.settings.staff,
                    subtitle: S.settings.staffSub,
                    onTap: () => context.push('/staff'),
                  ),
                  _SettingsTile(
                    icon: Icons.store_outlined,
                    title: S.settings.branches,
                    subtitle: S.settings.branchesSub,
                    onTap: () => context.push('/branches'),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              _buildSection(S.settings.reportsSection, [
                _SettingsTile(
                  icon: Icons.bar_chart_rounded,
                  title: S.settings.reports,
                  subtitle: S.settings.reportsSub,
                  onTap: () => context.push('/reports'),
                ),
                _SettingsTile(
                  icon: Icons.payments_outlined,
                  title: S.settings.payments,
                  subtitle: S.settings.paymentsSub,
                  onTap: () => context.push('/payments'),
                ),
                _SettingsTile(
                  icon: Icons.security_outlined,
                  title: S.settings.deposits,
                  subtitle: S.settings.depositsSub,
                  onTap: () => context.push('/deposits'),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            _buildSection(S.settings.appSettings, [
              _LanguageTile(isAmharic: isAmharic),
              _SettingsTile(
                icon: Icons.dns_outlined,
                title: S.settings.serverUrl,
                subtitle: S.settings.serverUrlSub,
                onTap: () => _showServerDialog(),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(S.settings.account, [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: S.settings.signOut,
                subtitle: S.settings.signOutSub,
                onTap: _logout,
                destructive: true,
              ),
            ]),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'RentDesk v1.0.0',
                style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(AppUser user) {
    return GestureDetector(
      onTap: () => _showEditProfileSheet(user),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_roleLabel(user.roles),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet(AppUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: user,
        onSaved: () => ref.read(authProvider.notifier).refreshUser(),
      ),
    );
  }

  Widget _buildBranchSection(AppUser user) {
    final branchState = ref.watch(branchProvider);
    final branchName = branchState.activeBranch?.name ?? 'Not selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            S.settings.activeBranch.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: InkWell(
            onTap: () => BranchChip.showBranchSheet(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store_outlined,
                        color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.settings.activeBranch,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          branchName,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFCBD5E1), size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: List.generate(children.length * 2 - 1, (i) {
              if (i.isOdd) return const Divider(height: 1, indent: 56);
              return children[i ~/ 2];
            }),
          ),
        ),
      ],
    );
  }

  Future<void> _showServerDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Server URL'),
        content: TextField(
          controller: _serverCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.1:8080',
          ),
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              _saveServerUrl();
              ctx.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _roleLabel(List<String> roles) {
    if (roles.contains('ROLE_SUPER_ADMIN')) return S.profile.roleSuperAdmin;
    if (roles.contains('ROLE_SHOP_ADMIN')) return S.profile.roleShopAdmin;
    if (roles.contains('ROLE_BRANCH_MANAGER')) return S.profile.roleBranchManager;
    if (roles.contains('ROLE_STAFF')) return S.profile.roleStaff;
    return 'User';
  }
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final AppUser user;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.user, required this.onSaved});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _fnCtrl  = TextEditingController();
  final _lnCtrl  = TextEditingController();
  final _emCtrl  = TextEditingController();
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _cfnCtrl = TextEditingController();
  bool _obscureCur = true, _obscureNew = true, _obscureCfn = true;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _fnCtrl.text = widget.user.name.split(' ').first;
    _lnCtrl.text = widget.user.name.split(' ').skip(1).join(' ');
    _emCtrl.text = widget.user.email;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _fnCtrl.dispose(); _lnCtrl.dispose(); _emCtrl.dispose();
    _curCtrl.dispose(); _newCtrl.dispose(); _cfnCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, dynamic> body) async {
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      await ref.read(apiClientProvider).put('/users/me', data: body);
      widget.onSaved();
      setState(() { _saving = false; _success = 'Saved successfully'; });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _saving = false;
        _error = msg.contains('422') || msg.contains('400')
            ? 'Invalid input. Check your details.'
            : 'Failed to save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 10),
              Text(S.profile.editProfile, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          // Tabs
          TabBar(
            controller: _tabs,
            tabs: [Tab(text: S.profile.tabName), Tab(text: S.profile.tabEmail), Tab(text: S.profile.tabPassword)],
            indicatorColor: const Color(0xFF7C3AED),
            labelColor: const Color(0xFF7C3AED),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          ),
          // Feedback banner
          if (_error != null || _success != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _error != null ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(_error != null ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 16, color: _error != null ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(child: Text(_error ?? _success!,
                    style: TextStyle(fontSize: 12, color: _error != null ? const Color(0xFFEF4444) : const Color(0xFF10B981)))),
              ]),
            ),
          // Tab content
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabs,
              children: [
                _nameTab(),
                _emailTab(),
                _passwordTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameTab() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          Row(children: [
            Expanded(child: _field(_fnCtrl, S.profile.firstName)),
            const SizedBox(width: 10),
            Expanded(child: _field(_lnCtrl, S.profile.lastName)),
          ]),
          const SizedBox(height: 16),
          _saveBtn(S.profile.updateName, () => _save({
            'firstName': _fnCtrl.text.trim(),
            'lastName': _lnCtrl.text.trim(),
          })),
        ]),
      );

  Widget _emailTab() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          _field(_emCtrl, S.profile.emailAddress, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _saveBtn(S.profile.updateEmail, () => _save({'email': _emCtrl.text.trim()})),
        ]),
      );

  Widget _passwordTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          _passField(_curCtrl, S.profile.currentPassword, _obscureCur, () => setState(() => _obscureCur = !_obscureCur)),
          const SizedBox(height: 10),
          _passField(_newCtrl, S.profile.newPassword, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 10),
          _passField(_cfnCtrl, S.profile.confirmPassword, _obscureCfn, () => setState(() => _obscureCfn = !_obscureCfn)),
          const SizedBox(height: 16),
          _saveBtn(S.profile.updatePassword, () {
            if (_newCtrl.text != _cfnCtrl.text) {
              setState(() => _error = S.profile.passMismatch);
              return;
            }
            _save({'currentPassword': _curCtrl.text, 'newPassword': _newCtrl.text});
          }),
        ]),
      );

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboard}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      );

  Widget _passField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            onPressed: toggle,
          ),
        ),
      );

  Widget _saveBtn(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      );
}

class _LanguageTile extends ConsumerWidget {
  final bool isAmharic;
  const _LanguageTile({required this.isAmharic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(localeProvider.notifier).toggle(),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.language_rounded, color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.settings.language,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    isAmharic ? S.settings.languageAm : S.settings.languageEn,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isAmharic ? '🇪🇹 አማርኛ' : '🇬🇧 English',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFEF4444) : const Color(0xFF7C3AED);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: destructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}
