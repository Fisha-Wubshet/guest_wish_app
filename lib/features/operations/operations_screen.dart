import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../bookings/bookings_provider.dart';
import '../../core/models/booking.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_error.dart';
import '../../shared/widgets/branch_chip.dart';
import '../../shared/widgets/shimmer_widgets.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(S.nav.operations),
          actions: [
            const BranchChip(),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: S.status.active),
              Tab(text: S.operations.todayPickups),
              Tab(text: S.operations.dueReturns),
            ],
            indicatorColor: Color(0xFF7C3AED),
            labelColor: Color(0xFF7C3AED),
            unselectedLabelColor: Color(0xFF94A3B8),
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          ),
        ),
        body: ref.watch(operationsProvider).when(
              loading: () => ShimmerList(cardBuilder: () => const ShimmerOperationCard()),
              error: (e, _) => AppError(
                message: 'Failed to load operations',
                onRetry: () => ref.invalidate(operationsProvider),
              ),
              data: (data) {
                final onRefresh = () async => ref.invalidate(operationsProvider);
                return TabBarView(
                  children: [
                    _OperationList(
                      bookings: data.active,
                      emptyTitle: S.operations.noPickups,
                      emptySubtitle: '',
                      icon: Icons.directions_run_rounded,
                      accentColor: const Color(0xFF10B981),
                      onRefresh: onRefresh,
                    ),
                    _OperationList(
                      bookings: data.pickupsToday,
                      emptyTitle: S.operations.noPickups,
                      emptySubtitle: '',
                      icon: Icons.local_shipping_outlined,
                      accentColor: const Color(0xFF3B82F6),
                      onRefresh: onRefresh,
                    ),
                    _OperationList(
                      bookings: data.returnsToday,
                      emptyTitle: S.operations.noDueReturns,
                      emptySubtitle: '',
                      icon: Icons.assignment_return_outlined,
                      accentColor: const Color(0xFFF59E0B),
                      onRefresh: onRefresh,
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _OperationList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData icon;
  final Color accentColor;
  final Future<void> Function() onRefresh;

  const _OperationList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.icon,
    required this.accentColor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: bookings.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: EmptyState(title: emptyTitle, subtitle: emptySubtitle, icon: icon),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: bookings.length,
              itemBuilder: (context, i) => _OperationCard(
                booking: bookings[i],
                accentColor: accentColor,
                onTap: () => context.push('/bookings/${bookings[i].id}'),
              ),
            ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  final Booking booking;
  final Color accentColor;
  final VoidCallback onTap;

  const _OperationCard({
    required this.booking,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accentColor, width: 3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        booking.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        booking.invoiceNumber,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: const Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        '${formatDate(booking.startDate)} → ${formatDate(booking.endDate)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  if (booking.items.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      () {
                        final counts = <String, int>{};
                        for (final i in booking.items) {
                          counts[i.item.name] = (counts[i.item.name] ?? 0) + (i.quantity > 0 ? i.quantity : 1);
                        }
                        return counts.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(', ');
                      }(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(booking.remainingBalance),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: booking.remainingBalance > 0
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.operations.remaining,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
