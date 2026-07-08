import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/customer.dart';

class CustomersState {
  final List<Customer> customers;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String search;
  final int page;
  final int total;
  final int lastPage;

  const CustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.search = '',
    this.page = 1,
    this.total = 0,
    this.lastPage = 1,
  });

  bool get hasMore => page < lastPage;

  CustomersState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? search,
    int? page,
    int? total,
    int? lastPage,
    bool clearError = false,
  }) =>
      CustomersState(
        customers: customers ?? this.customers,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        search: search ?? this.search,
        page: page ?? this.page,
        total: total ?? this.total,
        lastPage: lastPage ?? this.lastPage,
      );
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  static const _pageSize = 25;
  final ApiClient _api;

  CustomersNotifier(this._api) : super(const CustomersState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final params = <String, dynamic>{'size': _pageSize, 'page': 1};
      if (state.search.isNotEmpty) params['search'] = state.search;
      final res = await _api.get('/customers', params: params);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        customers: list,
        isLoading: false,
        page: 1,
        total: (data['total'] as int?) ?? list.length,
        lastPage: (data['last_page'] as int?) ?? 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load customers');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final params = <String, dynamic>{'size': _pageSize, 'page': nextPage};
      if (state.search.isNotEmpty) params['search'] = state.search;
      final res = await _api.get('/customers', params: params);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        customers: [...state.customers, ...list],
        isLoadingMore: false,
        page: nextPage,
        total: (data['total'] as int?) ?? state.total,
        lastPage: (data['last_page'] as int?) ?? nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
    load();
  }
}

final customersProvider = StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  return CustomersNotifier(ref.read(apiClientProvider));
});

final customerDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final results = await Future.wait([
    api.get('/customers/$id'),
    api.get('/customers/$id/stats').catchError((_) async => null),
  ]);
  final customer = results[0]!.data as Map<String, dynamic>;
  final stats = results[1] != null
      ? results[1]!.data as Map<String, dynamic>
      : <String, dynamic>{};
  return {...customer, 'stats': stats};
});
