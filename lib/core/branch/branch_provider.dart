import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../auth/auth_state.dart';
import '../models/branch.dart';

class BranchState {
  final List<Branch> branches;
  final Branch? activeBranch;
  final bool isLoading;
  final String? error;
  final bool isRestored;

  const BranchState({
    this.branches = const [],
    this.activeBranch,
    this.isLoading = false,
    this.error,
    this.isRestored = false,
  });

  BranchState copyWith({
    List<Branch>? branches,
    Branch? activeBranch,
    bool? isLoading,
    String? error,
    bool? isRestored,
    bool clearActiveBranch = false,
  }) =>
      BranchState(
        branches: branches ?? this.branches,
        activeBranch: clearActiveBranch ? null : (activeBranch ?? this.activeBranch),
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        isRestored: isRestored ?? this.isRestored,
      );
}

class BranchNotifier extends StateNotifier<BranchState> {
  final ApiClient _api;

  BranchNotifier(this._api) : super(const BranchState()) {
    _restoreActiveBranch();
  }

  Future<void> _restoreActiveBranch() async {
    final prefs = await SharedPreferences.getInstance();
    final branchId = prefs.getInt('active_branch_id');
    final branchName = prefs.getString('active_branch_name');
    Branch? active;
    if (branchId != null && branchName != null) {
      active = Branch(id: branchId, name: branchName);
    }
    state = state.copyWith(activeBranch: active, isRestored: true);
  }

  Future<void> loadBranches() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.get('/branches');
      final raw = res.data as List<dynamic>;
      final branches = raw
          .map((e) => Branch.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(branches: branches, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load branches');
    }
  }

  Future<void> setActiveBranch(Branch branch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_branch_id', branch.id);
    await prefs.setString('active_branch_name', branch.name);
    state = state.copyWith(activeBranch: branch);
  }

  Future<void> clearActiveBranch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_branch_id');
    await prefs.remove('active_branch_name');
    state = state.copyWith(clearActiveBranch: true);
  }

  /// Fully reset branch state — used on logout AND right before a new login,
  /// so a fresh user never inherits the previous user's branches / active branch.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_branch_id');
    await prefs.remove('active_branch_name');
    state = const BranchState(isRestored: true);   // isRestored=true so the router guard doesn't stall
  }
}

final branchProvider = StateNotifierProvider<BranchNotifier, BranchState>((ref) {
  return BranchNotifier(ref.read(apiClientProvider));
});

// branchId to pass in API calls:
// - SHOP_ADMIN: selected branch id (null if none selected yet)
// - BRANCH_MANAGER / STAFF: null (backend scopes by their own branchId from JWT)
final branchScopeProvider = Provider<int?>((ref) {
  final user = ref.watch(authProvider.select((s) => s.user));
  if (user?.isShopAdmin != true) return null;
  return ref.watch(branchProvider.select((s) => s.activeBranch?.id));
});
