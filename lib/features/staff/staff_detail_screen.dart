import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/models/managed_item.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _detailErr(dynamic e) {
  try {
    // ignore: avoid_dynamic_calls
    final data = e.response?.data;
    if (data is Map) return (data['message'] ?? data['error'] ?? 'Error') as String;
    if (data is String) return data;
  } catch (_) {}
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('Connection refused') || s.contains('Failed host lookup')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (s.contains('401') || s.contains('Unauthorized')) return 'Session expired. Please log in again.';
  return 'Something went wrong. Please try again.';
}

String _relativeTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return 'Never';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return isoString;
  }
}

String _shortTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today $h:$m';
    if (diff.inDays == 1) return 'Yesterday $h:$m';
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  } catch (_) {
    return isoString;
  }
}

Color _actionColor(String action) {
  final a = action.toUpperCase();
  if (a.contains('CREATE') || a.contains('CREATED')) return const Color(0xFF10B981);
  if (a.contains('DELETE') || a.contains('DELETED') || a.contains('CANCEL')) return const Color(0xFFEF4444);
  if (a.contains('PAYMENT') || a.contains('PAID')) return const Color(0xFF3B82F6);
  if (a.contains('PICKUP') || a.contains('PICKED_UP') || a.contains('PICKED')) return const Color(0xFFF59E0B);
  if (a.contains('RETURN')) return const Color(0xFF059669);
  if (a.contains('EDIT') || a.contains('UPDATE') || a.contains('MODIF')) return const Color(0xFF7C3AED);
  return const Color(0xFF94A3B8);
}

String _actionLabel(String action) {
  return action
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0]}${w.substring(1).toLowerCase()}' : '')
      .join(' ');
}

Color _roleColor(StaffUser member) {
  if (member.isShopAdmin) return const Color(0xFF7C3AED);
  if (member.isManager) return const Color(0xFF3B82F6);
  return const Color(0xFF0EA5E9);
}

String _roleLabel(StaffUser member) {
  if (member.isShopAdmin) return 'Shop Admin';
  if (member.isManager) return 'Branch Manager';
  return 'Staff';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffDetailScreen extends ConsumerStatefulWidget {
  final int id;

  const StaffDetailScreen({super.key, required this.id});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  // Staff
  StaffUser? _member;
  bool _loadingStaff = true;
  String? _staffError;

  // Audit summary
  Map<String, dynamic>? _summary;
  bool _loadingSummary = false;

  // Activity
  List<Map<String, dynamic>> _activity = [];
  bool _loadingActivity = false;
  bool _hasMore = true;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Map<String, dynamic> _branchParam() {
    final user = ref.read(authProvider).user;
    final scopeId = ref.read(branchScopeProvider);
    final branchId = scopeId ?? user?.branchId;
    if (branchId != null) return {'branchId': branchId};
    return {};
  }

  Future<void> _loadAll() async {
    await _loadStaff();
    if (_member != null) {
      await Future.wait([
        _loadSummary(),
        _loadActivity(reset: true),
      ]);
    }
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loadingStaff = true;
      _staffError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getRoot('/shop/staff');
      final list = (res.data as List<dynamic>)
          .map((e) => StaffUser.fromJson(e as Map<String, dynamic>))
          .toList();
      final found = list.where((s) => s.id == widget.id).toList();
      if (!mounted) return;
      if (found.isEmpty) {
        setState(() {
          _staffError = 'Staff member not found.';
          _loadingStaff = false;
        });
      } else {
        setState(() {
          _member = found.first;
          _loadingStaff = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staffError = _detailErr(e);
        _loadingStaff = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    final member = _member;
    if (member == null) return;
    setState(() => _loadingSummary = true);
    try {
      final api = ref.read(apiClientProvider);
      final params = _branchParam();
      final res = await api.get(
        '/audit-logs/staff-summary/${Uri.encodeComponent(member.email)}',
        params: params.isNotEmpty ? params : null,
      );
      if (!mounted) return;
      setState(() {
        _summary = res.data as Map<String, dynamic>?;
        _loadingSummary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadActivity({bool reset = false}) async {
    final member = _member;
    if (member == null) return;
    if (_loadingActivity) return;

    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !reset) return;

    setState(() => _loadingActivity = true);
    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'page': _page,
        'size': _pageSize,
        ..._branchParam(),
      };
      final res = await api.get(
        '/audit-logs/by-staff/${Uri.encodeComponent(member.email)}',
        params: params,
      );
      if (!mounted) return;
      final raw = res.data;
      List<dynamic> items;
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['content'] ?? raw['data'] ?? raw['items'] ?? []) as List<dynamic>;
      } else {
        items = [];
      }
      final parsed = items.map((e) => e as Map<String, dynamic>).toList();
      setState(() {
        if (reset) {
          _activity = parsed;
        } else {
          _activity.addAll(parsed);
        }
        _hasMore = parsed.length >= _pageSize;
        _page++;
        _loadingActivity = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingActivity = false);
    }
  }

  Future<void> _refresh() async {
    await _loadStaff();
    if (_member != null) {
      await Future.wait([
        _loadSummary(),
        _loadActivity(reset: true),
      ]);
    }
  }

  Future<void> _toggleBan() async {
    final member = _member;
    if (member == null) return;
    final isBanned = member.banned;
    final action = isBanned ? 'Unban' : 'Ban';
    final actionColor = isBanned ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final body = isBanned
        ? '"${member.name}" will regain access to the app.'
        : '"${member.name}" will no longer be able to log in.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action Staff Member'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
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
    final endpoint = isBanned
        ? '/shop/staff/${member.id}/unban'
        : '/shop/staff/${member.id}/ban';
    try {
      await ref.read(apiClientProvider).putRoot(endpoint);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${member.name} ${isBanned ? 'unbanned' : 'banned'}'),
          backgroundColor: actionColor,
        ),
      );
      await _loadStaff();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_detailErr(e)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _showResetPasswordSheet() async {
    final member = _member;
    if (member == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResetPasswordSheet(
        member: member,
        api: ref.read(apiClientProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStaff) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    if (_staffError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text(_staffError!, style: const TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadAll,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final member = _member!;
    final currentUser = ref.watch(authProvider).user;
    final isSelf = currentUser?.id == member.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF7C3AED),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(context, member),
            SliverToBoxAdapter(child: _buildStatsRow(member)),
            if (!isSelf) SliverToBoxAdapter(child: _buildQuickActions(member)),
            SliverToBoxAdapter(child: _buildActivitySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, StaffUser member) {
    final rc = _roleColor(member);
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF7C3AED),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        member.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    member.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    member.email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Chips
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HeaderChip(label: _roleLabel(member), color: rc),
                      if (member.branchName != null)
                        _HeaderChip(
                          label: member.branchName!,
                          color: Colors.white.withValues(alpha: 0.7),
                          icon: Icons.store_outlined,
                        ),
                      _HeaderChip(
                        label: member.banned ? 'Banned' : 'Active',
                        color: member.banned
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        isDot: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(StaffUser member) {
    final total = _summary?['totalActions'] as int? ?? _summary?['total'] as int? ?? 0;
    final month = _summary?['thisMonth'] as int? ?? _summary?['monthCount'] as int? ?? 0;
    final lastSeen = _summary?['lastSeen'] as String? ?? _summary?['lastActivity'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFF7C3AED),
              iconBg: const Color(0xFFF5F3FF),
              label: 'Total Actions',
              value: _loadingSummary ? '–' : total.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF3B82F6),
              iconBg: const Color(0xFFEFF6FF),
              label: 'This Month',
              value: _loadingSummary ? '–' : month.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFECFDF5),
              label: 'Last Seen',
              value: _loadingSummary ? '–' : _relativeTime(lastSeen),
              smallText: true,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(StaffUser member) {
    final isBanned = member.banned;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.lock_reset_rounded,
              iconColor: const Color(0xFF3B82F6),
              iconBg: const Color(0xFFEFF6FF),
              label: 'Reset Password',
              subtitle: 'Set a new password for this account',
              onTap: _showResetPasswordSheet,
            ),
            Divider(height: 1, indent: 20, endIndent: 20, color: const Color(0xFFF1F5F9)),
            _ActionTile(
              icon: isBanned ? Icons.person_rounded : Icons.person_off_rounded,
              iconColor: isBanned ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              iconBg: isBanned ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              label: isBanned ? 'Unban Staff Member' : 'Ban Staff Member',
              subtitle: isBanned
                  ? 'Restore access to the app'
                  : 'Revoke login access immediately',
              onTap: _toggleBan,
              destructive: !isBanned,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Activity Section ──────────────────────────────────────────────────────

  Widget _buildActivitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (_activity.isEmpty && !_loadingActivity)
            _buildEmptyActivity()
          else ...[
            ..._activity.map((log) => _ActivityCard(log: log)),
            if (_loadingActivity)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _loadActivity(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      foregroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Load More',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 28,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Actions taken by this staff member will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isDot;

  const _HeaderChip({
    required this.label,
    required this.color,
    this.icon,
    this.isDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isDot ? Colors.white : Colors.white.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final bool smallText;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: smallText ? 13 : 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: destructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _ActivityCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = (log['action'] ?? log['actionType'] ?? 'ACTION') as String;
    final entityType = (log['entityType'] ?? log['entity_type'] ?? '') as String;
    final entityId = log['entityId'] ?? log['entity_id'];
    final timestamp = (log['timestamp'] ?? log['createdAt'] ?? log['created_at']) as String?;
    final details = (log['details'] ?? log['description'] ?? '') as String;

    final color = _actionColor(action);
    final label = _actionLabel(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color dot / action indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _actionIcon(action),
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Action chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _shortTime(timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Entity info
                  if (entityType.isNotEmpty)
                    Text(
                      entityId != null ? '$entityType #$entityId' : entityType,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  // Details snippet
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      details,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String action) {
    final a = action.toUpperCase();
    if (a.contains('CREATE')) return Icons.add_circle_outline_rounded;
    if (a.contains('DELETE') || a.contains('CANCEL')) return Icons.remove_circle_outline_rounded;
    if (a.contains('PAYMENT') || a.contains('PAID')) return Icons.payments_outlined;
    if (a.contains('PICKUP') || a.contains('PICKED')) return Icons.shopping_bag_outlined;
    if (a.contains('RETURN')) return Icons.assignment_return_outlined;
    if (a.contains('EDIT') || a.contains('UPDATE') || a.contains('MODIF')) return Icons.edit_outlined;
    return Icons.history_rounded;
  }
}

// ─── Reset Password Sheet ─────────────────────────────────────────────────────

class _ResetPasswordSheet extends StatefulWidget {
  final StaffUser member;
  final ApiClient api;

  const _ResetPasswordSheet({required this.member, required this.api});

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.putRoot(
        '/shop/staff/${widget.member.id}/reset-password',
        data: {'password': _passCtrl.text},
      );
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Password reset for ${widget.member.name}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      setState(() {
        _error = _detailErr(e);
        _saving = false;
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
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Set a new password for ${widget.member.name}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _passCtrl,
                obscureText: !_showPass,
                autofocus: true,
                decoration: _inputDec('New Password', Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Reset Password',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDec(String label, IconData? icon) => InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF94A3B8)) : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
