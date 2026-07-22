import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/models/managed_item.dart';
import '../../shared/widgets/phone_input_field.dart';
import '../../shared/widgets/credentials_share_sheet.dart';
import '../../core/utils/password_gen.dart';
import '../../core/locale/locale_provider.dart';

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

  // KPI stats: { totalBookings, activeBookings, cancelledBookings }
  Map<String, dynamic>? _stats;

  // Bookings created by this staff (paginated).
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = false;
  bool _hasMoreBookings = true;
  int _bookingsPage = 1;
  static const _bookingsPageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loadingStaff = true;
      _staffError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getRoot('/shop/staff/${widget.id}');
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _member = StaffUser.fromJson(data);
        _stats  = data['stats'] as Map<String, dynamic>?;
        _loadingStaff = false;
      });
      await _loadBookings(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staffError = _detailErr(e);
        _loadingStaff = false;
      });
    }
  }

  Future<void> _loadBookings({bool reset = false}) async {
    if (_loadingBookings) return;
    if (reset) { _bookingsPage = 1; _hasMoreBookings = true; }
    if (!_hasMoreBookings && !reset) return;

    setState(() => _loadingBookings = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/bookings', params: {
        'createdById': widget.id,
        'page': _bookingsPage,
        'size': _bookingsPageSize,
      });
      final raw = res.data;
      List<dynamic> items;
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['data'] ?? raw['content'] ?? raw['items'] ?? []) as List<dynamic>;
      } else {
        items = [];
      }
      final parsed = items.map((e) => e as Map<String, dynamic>).toList();
      if (!mounted) return;
      setState(() {
        if (reset) { _bookings = parsed; } else { _bookings.addAll(parsed); }
        _hasMoreBookings = parsed.length >= _bookingsPageSize;
        _bookingsPage++;
        _loadingBookings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBookings = false);
    }
  }

  Future<void> _refresh() async {
    await _loadStaff();
  }

  Future<void> _showEditSheet() async {
    final member = _member;
    if (member == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditStaffSheet(
        member: member,
        api: ref.read(apiClientProvider),
      ),
    );
    if (changed == true) await _loadStaff();
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
                onPressed: _loadStaff,
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
            _buildHeader(context, member, isSelf),
            SliverToBoxAdapter(child: _buildKpiCard()),
            if (!isSelf) SliverToBoxAdapter(child: _buildQuickActions(member)),
            SliverToBoxAdapter(child: _buildBookingHistoryHeader()),
            _buildBookingsSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, StaffUser member, bool isSelf) {
    final rc = _roleColor(member);
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: const Color(0xFF7C3AED),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: isSelf ? null : [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Edit',
            onPressed: _showEditSheet,
          ),
        ),
      ],
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Phone number
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, color: Colors.white.withValues(alpha: 0.75), size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          member.phoneNumber ?? '—',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

  // ─── Bookings-created KPI card ─────────────────────────────────────────────

  Widget _buildKpiCard() {
    final total     = (_stats?['totalBookings'] as int?) ?? 0;
    final active    = (_stats?['activeBookings'] as int?) ?? 0;
    final cancelled = (_stats?['cancelledBookings'] as int?) ?? 0;
    final rate      = total == 0 ? 0 : ((active / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F3FF), Color(0xFFFAF9FF)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9D5FF)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.event_available_rounded, color: Color(0xFF7C3AED), size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BOOKINGS CREATED',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total.toString(),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED),
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _KpiPill(label: '$active active',    color: const Color(0xFF059669), bg: const Color(0xFFECFDF5), icon: Icons.check_circle_outline_rounded),
                      _KpiPill(label: '$cancelled cancelled', color: const Color(0xFFDC2626), bg: const Color(0xFFFEF2F2), icon: Icons.cancel_outlined),
                    ],
                  ),
                ],
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.only(left: 14),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE9D5FF))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$rate%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'COMPLETION',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

  // ─── Booking history ──────────────────────────────────────────────────────

  Widget _buildBookingHistoryHeader() {
    final total = (_stats?['totalBookings'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          const Text(
            'Booking history',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          if (total > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Text('$total', style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingsSliver() {
    if (_bookings.isEmpty && !_loadingBookings) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.receipt_long_outlined, size: 30, color: Color(0xFFCBD5E1)),
                SizedBox(height: 8),
                Text('No bookings created yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i < _bookings.length) return _BookingRow(booking: _bookings[i]);
            if (_loadingBookings) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2)));
            if (_hasMoreBookings) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton(
                  onPressed: () => _loadBookings(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    foregroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Load more', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              );
            }
            return const SizedBox.shrink();
          },
          childCount: _bookings.length + 1,
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingRow({required this.booking});

  Color _statusColor(String? s) {
    switch (s) {
      case 'CONFIRMED': return const Color(0xFF3B82F6);
      case 'PICKED_UP': return const Color(0xFFF59E0B);
      case 'RETURNED':  return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFFEF4444);
      default:          return const Color(0xFF64748B);
    }
  }
  Color _statusBg(String? s) => _statusColor(s).withValues(alpha: 0.10);

  @override
  Widget build(BuildContext context) {
    final invoice   = booking['invoice_number'] as String? ?? '—';
    final firstName = booking['first_name'] as String? ?? '';
    final lastName  = booking['last_name'] as String? ?? '';
    final phone     = booking['phone_number'] as String? ?? '';
    final total     = booking['total_agreed_price'];
    final date      = booking['booking_date'] as String?;
    final status    = booking['status'] as String?;
    String dateLabel = '';
    if (date != null) {
      try {
        dateLabel = DateFormat('MMM d, y').format(DateTime.parse(date));
      } catch (_) { dateLabel = date; }
    }
    final totalStr = total is num ? total.toStringAsFixed(0) : (total?.toString() ?? '0');

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(invoice, style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(6)),
                  child: Text(status ?? '', style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('$firstName $lastName'.trim(), style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13.5)),
            if (phone.isNotEmpty)
              Text(phone, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(dateLabel, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                const Spacer(),
                Text('$totalStr ETB', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _KpiPill({required this.label, required this.color, required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
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
  late String _emailLanguage = appLocale == 'am' ? 'am' : 'en';

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  void _genPassword() {
    setState(() {
      _passCtrl.text = generatePassword();
      _showPass = true;
    });
  }

  Widget _langChip(String value, String label) {
    final active = _emailLanguage == value;
    return GestureDetector(
      onTap: () => setState(() => _emailLanguage = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFF7C3AED) : Colors.transparent, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hasEmail = widget.member.email.isNotEmpty;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{'password': _passCtrl.text};
      if (hasEmail) payload['emailLanguage'] = _emailLanguage;
      final res = await widget.api.putRoot(
        '/shop/staff/${widget.member.id}/reset-password',
        data: payload,
      );
      final data = (res.data ?? {}) as Map<String, dynamic>;
      if (!mounted) return;

      // Pop the reset sheet, then open the credentials share sheet from the
      // root navigator so the admin can share the new password immediately.
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Password reset for ${widget.member.name}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      await CredentialsShareSheet.show(
        rootCtx,
        firstName: widget.member.firstName,
        lastName:  widget.member.lastName,
        phone:     widget.member.phoneNumber ?? '',
        password:  (data['plainPassword'] as String?) ?? _passCtrl.text,
        recoveryCode: null,   // reset doesn't rotate the recovery code
        userEmail: hasEmail ? widget.member.email : null,
        emailSent: data['emailQueued'] as bool? ?? false,
      );
    } catch (e) {
      if (mounted) setState(() {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _genPassword,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F0FF),
                        foregroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.auto_fix_high, size: 14),
                      label: Text(appLocale == 'am' ? 'ጠንካራ ፓስዎርድ ፍጠር' : 'Generate strong password'),
                    ),
                  ),
                  if (widget.member.email.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          appLocale == 'am' ? 'የመልሶ ማስተካከል ኢሜይል ቋንቋ' : 'Reset email language',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 10),
                        _langChip('en', '🇬🇧 EN'),
                        const SizedBox(width: 6),
                        _langChip('am', '🇪🇹 አማ'),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              appLocale == 'am'
                                  ? 'ኢሜይል የለም — ከተስተካከለ በኋላ ይጋራሉ።'
                                  : "No email on file — you can share after reset.",
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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

// ─── Edit Staff Sheet ────────────────────────────────────────────────────────

class _EditStaffSheet extends StatefulWidget {
  final StaffUser member;
  final ApiClient api;
  const _EditStaffSheet({required this.member, required this.api});

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _emailCtrl;
  String _phoneNormalized = '';
  String _countryDial = '+251';
  String _role = 'ROLE_STAFF';
  int? _branchId;
  List<Map<String, dynamic>> _branches = [];
  bool _loadingBranches = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.member.firstName);
    _lastCtrl  = TextEditingController(text: widget.member.lastName);
    _emailCtrl = TextEditingController(text: widget.member.email);
    _phoneNormalized = widget.member.phoneNumber ?? '';
    // Try to infer role from the member (assume single primary role).
    if (widget.member.roles.contains('ROLE_BRANCH_MANAGER')) _role = 'ROLE_BRANCH_MANAGER';
    _branchId = widget.member.branchId;
    _fetchBranches();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBranches() async {
    try {
      final res = await widget.api.get('/branches');
      final raw = res.data;
      final list = (raw is List ? raw : (raw['data'] ?? raw['content'] ?? [])) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _branches = list.map((e) => e as Map<String, dynamic>).toList();
        _loadingBranches = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_phoneNormalized.isEmpty) { setState(() => _error = 'Please enter a phone number.'); return; }
    if (_branchId == null) { setState(() => _error = 'Please select a branch.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final payload = <String, dynamic>{
        'firstName':   _firstCtrl.text.trim(),
        'lastName':    _lastCtrl.text.trim(),
        'phone':       _phoneNormalized,
        'countryCode': _countryDial,
        'email':       _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'role':        _role,
        'branchId':    _branchId,
      };
      await widget.api.putRoot('/shop/staff/${widget.member.id}', data: payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = _detailErr(e); _saving = false; });
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
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
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
            const Text('Edit staff member',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text('Update ${widget.member.name}\'s details',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
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
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDec('First name', Icons.person_outline_rounded),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDec('Last name', null),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  PhoneInputField(
                    initialDigits: _phoneNormalized,
                    initialCountryDial: _countryDial,
                    onChanged: (digits, dial, normalized) {
                      _phoneNormalized = normalized ?? '';
                      _countryDial = dial;
                    },
                    validator: (norm) => (norm == null || norm.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDec('Email (optional)', Icons.email_outlined),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: _inputDec('Role', Icons.badge_outlined),
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(value: 'ROLE_BRANCH_MANAGER', child: Text('Branch manager')),
                      DropdownMenuItem(value: 'ROLE_STAFF',          child: Text('Staff')),
                    ],
                    onChanged: (v) => setState(() { _role = v!; }),
                  ),
                  const SizedBox(height: 12),
                  _loadingBranches
                      ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2)))
                      : DropdownButtonFormField<int>(
                          value: _branchId,
                          decoration: _inputDec('Branch', Icons.store_outlined),
                          borderRadius: BorderRadius.circular(12),
                          items: _branches.map((b) => DropdownMenuItem<int>(
                            value: b['id'] as int,
                            child: Text(b['name'] as String? ?? ''),
                          )).toList(),
                          onChanged: (v) => setState(() { _branchId = v; }),
                          validator: (v) => v == null ? 'Required' : null,
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
                    : const Text('Save changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
