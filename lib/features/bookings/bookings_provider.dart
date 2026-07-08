import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/models/booking.dart';

// ─── Bookings list ────────────────────────────────────────────────────────────

class BookingsState {
  final List<Booking> bookings;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int totalPages;
  final String statusFilter;
  final String search;

  const BookingsState({
    this.bookings = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.statusFilter = '',
    this.search = '',
  });

  bool get hasMore => currentPage < totalPages;

  BookingsState copyWith({
    List<Booking>? bookings,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? totalPages,
    String? statusFilter,
    String? search,
    bool clearError = false,
  }) =>
      BookingsState(
        bookings: bookings ?? this.bookings,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
        statusFilter: statusFilter ?? this.statusFilter,
        search: search ?? this.search,
      );
}

class BookingsNotifier extends StateNotifier<BookingsState> {
  final ApiClient _api;
  final int? branchId;

  BookingsNotifier(this._api, {this.branchId}) : super(const BookingsState()) {
    load();
  }

  Future<void> load({bool reset = true}) async {
    if (reset) {
      state = state.copyWith(isLoading: true, clearError: true, currentPage: 1, bookings: []);
    } else {
      state = state.copyWith(isLoading: true);
    }
    try {
      final page = reset ? 1 : state.currentPage + 1;
      final params = <String, dynamic>{'page': page, 'size': 20};
      if (branchId != null) params['branchId'] = branchId;
      if (state.statusFilter.isNotEmpty) params['status'] = state.statusFilter;
      if (state.search.isNotEmpty) {
        // Phone: starts with +, 0, or is all digits
        final isPhone = RegExp(r'^(\+|0|\d+$)').hasMatch(state.search);
        if (isPhone) {
          params['phone'] = state.search;
        } else {
          params['invoiceNumber'] = state.search;
        }
      }

      final res = await _api.get('/bookings', params: params);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        bookings: reset ? list : [...state.bookings, ...list],
        isLoading: false,
        currentPage: data['current_page'] as int? ?? page,
        totalPages: data['last_page'] as int? ?? 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load bookings. Check your connection.',
      );
    }
  }

  void setStatus(String status) {
    state = state.copyWith(statusFilter: status);
    load();
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
    load();
  }

  Future<void> loadMore() async {
    if (state.hasMore && !state.isLoading) await load(reset: false);
  }
}

// Recreated when branchScopeProvider changes so the list auto-refreshes on branch switch
final bookingsProvider = StateNotifierProvider<BookingsNotifier, BookingsState>((ref) {
  final branchId = ref.watch(branchScopeProvider);
  return BookingsNotifier(ref.read(apiClientProvider), branchId: branchId);
});

// ─── Single booking ───────────────────────────────────────────────────────────

final bookingDetailProvider = FutureProvider.family<Booking, int>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/bookings/$id');
  return Booking.fromJson(res.data as Map<String, dynamic>);
});

// ─── Operations (active, pickups today, returns today) ────────────────────────

final operationsProvider = FutureProvider<_OperationsData>((ref) async {
  final api = ref.read(apiClientProvider);
  final branchId = ref.watch(branchScopeProvider);
  final Map<String, dynamic> branchParam =
      branchId != null ? {'branchId': branchId} : {};

  final results = await Future.wait([
    api.get('/bookings', params: {'status': 'PICKED_UP', 'size': 100, ...branchParam}),
    api.get('/bookings/today-pickups',
        params: branchParam.isEmpty ? null : branchParam),
    api.get('/bookings/due-today',
        params: branchParam.isEmpty ? null : branchParam),
  ]);

  List<Booking> parsePaginated(dynamic res) {
    final data = (res as dynamic).data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<Booking> parseList(dynamic res) {
    final raw = (res as dynamic).data;
    final list = raw is List ? raw : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
    return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  return _OperationsData(
    active: parsePaginated(results[0]),
    pickupsToday: parseList(results[1]),
    returnsToday: parseList(results[2]),
  );
});

class _OperationsData {
  final List<Booking> active;
  final List<Booking> pickupsToday;
  final List<Booking> returnsToday;

  const _OperationsData({
    required this.active,
    required this.pickupsToday,
    required this.returnsToday,
  });
}
