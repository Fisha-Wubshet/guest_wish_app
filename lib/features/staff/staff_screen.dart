import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/models/managed_item.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  List<StaffUser> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).getRoot('/shop/staff');
      final list = res.data as List<dynamic>;
      if (mounted) {
        setState(() {
          _staff = list.map((e) => StaffUser.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = _staffErr(e); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _showCreateSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateStaffSheet(api: ref.read(apiClientProvider)),
    );
    if (result == true) _load();
  }

  Future<void> _toggleBan(StaffUser member) async {
    final isBanned = member.banned;
    final action = isBanned ? S.settings.unban : S.settings.ban;
    final actionColor = isBanned ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action ${S.nav.staff}'),
        content: Text('"${member.name}"'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(S.common.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final endpoint = isBanned ? '/shop/staff/${member.id}/unban' : '/shop/staff/${member.id}/ban';
    try {
      await ref.read(apiClientProvider).putRoot(endpoint);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${member.name} ${isBanned ? S.settings.unbannedMsg : S.settings.bannedMsg}'),
          backgroundColor: actionColor,
        ),
      );
      _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_staffErr(e)), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(S.nav.staff),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: Text(S.settings.addStaff),
      ),
      body: _buildBody(currentUser),
    );
  }

  Widget _buildBody(AppUser? currentUser) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: Text(S.common.retry),
            ),
          ],
        ),
      );
    }

    if (_staff.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 16),
            Text(S.settings.noStaffYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(S.settings.tapToAddStaff, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _staff.length,
        itemBuilder: (_, i) {
          final member = _staff[i];
          final isSelf = member.id == currentUser?.id;
          return _StaffTile(
            member: member,
            isSelf: isSelf,
            onTap: () => context.push('/staff/${member.id}'),
            onToggleBan: isSelf ? null : () => _toggleBan(member),
          );
        },
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final StaffUser member;
  final bool isSelf;
  final VoidCallback? onTap;
  final VoidCallback? onToggleBan;

  const _StaffTile({required this.member, required this.isSelf, this.onTap, this.onToggleBan});

  Color get _roleColor {
    if (member.isShopAdmin) return const Color(0xFF7C3AED);
    if (member.isManager) return const Color(0xFF3B82F6);
    return const Color(0xFF0EA5E9);
  }

  String get _roleLabel {
    if (member.isShopAdmin) return S.profile.roleShopAdmin;
    if (member.isManager) return S.profile.roleBranchManager;
    return S.profile.roleStaff;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = !member.banned;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  member.initials,
                  style: TextStyle(color: _roleColor, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name + (isSelf ? ' (You)' : ''),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(member.email, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(label: _roleLabel, color: _roleColor),
                      if (member.branchName != null) ...[
                        const SizedBox(width: 6),
                        _Chip(label: member.branchName!, color: const Color(0xFF64748B), icon: Icons.store_outlined),
                      ],
                      const Spacer(),
                      _StatusBadge(active: isActive),
                    ],
                  ),
                ],
              ),
            ),
            if (!isSelf && onToggleBan != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onToggleBan,
                style: IconButton.styleFrom(
                  backgroundColor: isActive
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  isActive ? Icons.person_off_outlined : Icons.person_outlined,
                  color: isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  size: 20,
                ),
                tooltip: isActive ? 'Ban' : 'Unban',
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            active ? S.status.active : S.settings.banned,
            style: TextStyle(
              color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Staff Sheet
// ---------------------------------------------------------------------------

class _CreateStaffSheet extends StatefulWidget {
  final ApiClient api;

  const _CreateStaffSheet({required this.api});

  @override
  State<_CreateStaffSheet> createState() => _CreateStaffSheetState();
}

class _CreateStaffSheetState extends State<_CreateStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  String _role = 'ROLE_STAFF';
  int? _branchId;
  List<Map<String, dynamic>> _branches = [];
  bool _saving = false;
  bool _loadingBranches = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBranches() async {
    setState(() { _loadingBranches = true; });
    try {
      final res = await widget.api.get('/branches');
      final raw = res.data;
      final list = (raw is List ? raw : (raw['data'] ?? raw['content'] ?? [])) as List<dynamic>;
      if (mounted) {
        setState(() {
          _branches = list.map((e) => e as Map<String, dynamic>).toList();
          if (_branches.isNotEmpty) _branchId = _branches.first['id'] as int;
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() { _loadingBranches = false; });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_branchId == null) {
      setState(() { _error = S.settings.pleaseSelectBranch; });
      return;
    }
    final nav = Navigator.of(context);
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.postRoot(
        '/register-admin?branchId=$_branchId',
        data: {
          'firstName': _firstCtrl.text.trim(),
          'lastName': _lastCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
          'roles': [_role],
        },
      );
      nav.pop(true);
    } catch (e) {
      setState(() { _error = _staffErr(e); _saving = false; });
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
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(S.settings.addStaffMember, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(S.settings.addStaffSubtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _staffInputDec(S.profile.firstName, Icons.person_outline_rounded),
                          validator: (v) => (v == null || v.trim().isEmpty) ? S.settings.staffRequired : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _staffInputDec(S.profile.lastName, null),
                          validator: (v) => (v == null || v.trim().isEmpty) ? S.settings.staffRequired : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _staffInputDec(S.auth.email, Icons.email_outlined),
                    validator: (v) => (v == null || !v.contains('@')) ? S.settings.validEmailRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: !_showPass,
                    decoration: _staffInputDec(S.auth.password, Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: const Color(0xFF94A3B8)),
                        onPressed: () => setState(() { _showPass = !_showPass; }),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? S.settings.minSixChars : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: _staffInputDec(S.settings.staffRoleLabel, Icons.badge_outlined),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(value: 'ROLE_BRANCH_MANAGER', child: Text(S.profile.roleBranchManager)),
                      DropdownMenuItem(value: 'ROLE_STAFF', child: Text(S.profile.roleStaff)),
                    ],
                    onChanged: (v) => setState(() { _role = v!; }),
                  ),
                  const SizedBox(height: 12),
                  _loadingBranches
                      ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2)))
                      : DropdownButtonFormField<int>(
                          value: _branchId,
                          decoration: _staffInputDec(S.common.branch, Icons.store_outlined),
                          borderRadius: BorderRadius.circular(12),
                          items: _branches.map((b) => DropdownMenuItem<int>(
                            value: b['id'] as int,
                            child: Text(b['name'] as String? ?? ''),
                          )).toList(),
                          onChanged: (v) => setState(() { _branchId = v; }),
                          validator: (v) => v == null ? S.settings.selectBranch : null,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(S.settings.createAccount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _staffInputDec(String label, IconData? icon) => InputDecoration(
  labelText: label,
  prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF94A3B8)) : null,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
  filled: true,
  fillColor: const Color(0xFFF8FAFC),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
);

String _staffErr(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map) return (data['message'] ?? data['error'] ?? 'Error') as String;
    if (data is String) return data;
  } catch (_) {}
  return 'Something went wrong';
}
