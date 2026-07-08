import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bookings_provider.dart';
import 'widgets/booking_card.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../shared/widgets/app_error.dart';
import '../../shared/widgets/branch_chip.dart';
import '../../shared/widgets/shimmer_widgets.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(bookingsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final state = ref.watch(bookingsProvider);
    final top = MediaQuery.of(context).padding.top;

    final statusFilters = [
      ('', S.bookings.allStatuses),
      ('CONFIRMED', S.status.confirmed),
      ('PICKED_UP', S.status.pickedUp),
      ('RETURNED', S.status.returned),
      ('CANCELLED', S.status.cancelled),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top + 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    S.nav.bookings,
                    style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A), letterSpacing: -0.5,
                    ),
                  ),
                ),
                const BranchChip(),
              ],
            ),
          ),
          _buildSearch(state),
          const SizedBox(height: 10),
          _buildFilterChips(state, statusFilters),
          const SizedBox(height: 4),
          Expanded(child: _buildList(state)),
        ],
      ),
    );
  }

  Widget _buildSearch(BookingsState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => ref.read(bookingsProvider.notifier).setSearch(v),
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: S.bookings.searchHint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF94A3B8)),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(bookingsProvider.notifier).setSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BookingsState state, List<(String, String)> filters) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = filters[i];
          final selected = state.statusFilter == value;
          return GestureDetector(
            onTap: () => ref.read(bookingsProvider.notifier).setStatus(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF7C3AED) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected
                    ? [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(BookingsState state) {
    if (state.isLoading && state.bookings.isEmpty) {
      return ShimmerList(cardBuilder: () => const ShimmerBookingCard());
    }
    if (state.error != null && state.bookings.isEmpty) {
      return AppError(
        message: state.error!,
        onRetry: () => ref.read(bookingsProvider.notifier).load(),
      );
    }
    if (state.bookings.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: S.bookings.noBookings,
        subtitle: state.search.isNotEmpty || state.statusFilter.isNotEmpty
            ? S.bookings.tryDifferent : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(bookingsProvider.notifier).load(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: state.bookings.length + (state.isLoading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == state.bookings.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final b = state.bookings[i];
          return BookingCard(booking: b, onTap: () => context.push('/bookings/${b.id}'));
        },
      ),
    );
  }
}
