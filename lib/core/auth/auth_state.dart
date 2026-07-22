import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../branch/branch_provider.dart';

// ─── User model ──────────────────────────────────────────────────────────────

class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? countryCode;
  final List<String> roles;
  final String itemLabel;
  final int? shopId;
  final int? branchId;
  final String? branchName;
  final String? shopName;
  final bool hasRecoveryCode;
  final bool mustChangePassword;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.countryCode,
    required this.roles,
    required this.itemLabel,
    this.shopId,
    this.branchId,
    this.branchName,
    this.shopName,
    this.hasRecoveryCode = false,
    this.mustChangePassword = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phoneNumber: j['phoneNumber'] as String?,
        countryCode: j['countryCode'] as String?,
        roles: (j['roles'] as List<dynamic>? ?? []).cast<String>(),
        itemLabel: j['itemLabel'] ?? 'Item',
        shopId: j['shopId'] as int?,
        branchId: j['branchId'] as int?,
        branchName: j['branchName'],
        shopName: j['shopName'],
        hasRecoveryCode: j['hasRecoveryCode'] as bool? ?? false,
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'countryCode': countryCode,
        'roles': roles,
        'itemLabel': itemLabel,
        'shopId': shopId,
        'branchId': branchId,
        'branchName': branchName,
        'shopName': shopName,
        'hasRecoveryCode': hasRecoveryCode,
        'mustChangePassword': mustChangePassword,
      };

  bool get isSuperAdmin => roles.contains('ROLE_SUPER_ADMIN');
  bool get isShopAdmin => roles.contains('ROLE_SHOP_ADMIN');
  bool get isBranchManager => roles.contains('ROLE_BRANCH_MANAGER');
  bool get isManager => isShopAdmin || isBranchManager;
  bool get isStaff => roles.contains('ROLE_STAFF');

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Auth state ───────────────────────────────────────────────────────────────

class AuthState {
  final AppUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.token, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    AppUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        token: clearUser ? null : (token ?? this.token),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Auth notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final Ref _ref;

  AuthNotifier(this._api, this._ref) : super(const AuthState(isLoading: true)) {
    _api.setOnSessionExpired(logout);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final refreshToken = prefs.getString('refresh_token');
    final userJson = prefs.getString('user');
    if (token != null && userJson != null) {
      try {
        final user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        _api.setToken(token);
        if (refreshToken != null) _api.setRefreshToken(refreshToken);
        state = AuthState(user: user, token: token);
      } catch (_) {
        state = const AuthState();
      }
    } else {
      state = const AuthState();
    }
  }

  /// Legacy email login (kept for the transition period).
  Future<bool> login(String email, String password) =>
      _doLogin({'email': email, 'password': password});

  /// New phone-based login.
  Future<bool> loginByPhone(String phone, String countryCode, String password) =>
      _doLogin({'phone': phone, 'countryCode': countryCode, 'password': password});

  Future<bool> _doLogin(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, clearError: true);
    // Belt-and-suspenders: wipe any lingering branch state from a previous
    // session so user B never inherits user A's branches.
    await _ref.read(branchProvider.notifier).reset();
    try {
      final res = await _api.postRoot('/login', data: payload);
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final firstName = (data['firstName'] as String?) ?? '';
      final lastName = (data['lastName'] as String?) ?? '';
      final user = AppUser(
        id: data['userId'] as int,
        name: '$firstName $lastName'.trim(),
        email: (data['email'] as String?) ?? '',
        phoneNumber: data['phoneNumber'] as String?,
        countryCode: data['countryCode'] as String? ?? '+251',
        roles: (data['roles'] as List<dynamic>? ?? []).cast<String>(),
        itemLabel: (data['itemLabel'] as String?) ?? 'Dress',
        shopId: data['shopId'] as int?,
        branchId: data['branchId'] as int?,
        branchName: data['branchName'] as String?,
        shopName: null,
        hasRecoveryCode: data['hasRecoveryCode'] as bool? ?? false,
        mustChangePassword: data['mustChangePassword'] as bool? ?? false,
      );

      final refreshToken = data['refreshToken'] as String?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user.toJson()));
      if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);

      _api.setToken(token);
      if (refreshToken != null) _api.setRefreshToken(refreshToken);
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<void> refreshUser() async {
    if (state.user == null) return;
    try {
      final res = await _api.get('/me');
      final data = res.data as Map<String, dynamic>;
      final firstName = (data['firstName'] as String?) ?? '';
      final lastName  = (data['lastName']  as String?) ?? '';
      final updated = AppUser(
        id: state.user!.id,
        name: '$firstName $lastName'.trim(),
        email: (data['email'] as String?) ?? state.user!.email,
        roles: state.user!.roles,
        itemLabel: state.user!.itemLabel,
        shopId: state.user!.shopId,
        branchId: state.user!.branchId,
        branchName: state.user!.branchName,
        shopName: state.user!.shopName,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updated.toJson()));
      state = state.copyWith(user: updated);
    } catch (_) {}
  }

  /// Clears the `mustChangePassword` flag after the user completes the
  /// first-login password change.
  Future<void> clearMustChangePassword() async {
    final u = state.user;
    if (u == null) return;
    final updated = AppUser(
      id: u.id, name: u.name, email: u.email,
      phoneNumber: u.phoneNumber, countryCode: u.countryCode,
      roles: u.roles, itemLabel: u.itemLabel,
      shopId: u.shopId, branchId: u.branchId,
      branchName: u.branchName, shopName: u.shopName,
      hasRecoveryCode: u.hasRecoveryCode,
      mustChangePassword: false,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(updated.toJson()));
    state = state.copyWith(user: updated);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    _api.clearToken();
    // Wipe branch state (both in-memory + persisted keys) so the next user
    // starts with a clean slate.
    await _ref.read(branchProvider.notifier).reset();
    state = const AuthState();
  }

  String _extractError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('credentials') || msg.contains('Unauthorized')) {
      return 'Invalid phone number or password';
    }
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Failed host lookup') ||
        msg.contains('connect_error') ||
        msg.contains('connection timed out') ||
        msg.contains('ConnectException')) {
      return 'Cannot reach server.\n\nMake sure:\n• Server is running\n• Use your computer\'s LAN IP (not localhost)\n  e.g. http://192.168.x.x:8080';
    }
    if (msg.contains('DioException') || msg.contains('dio')) {
      return 'Network error: $msg';
    }
    return 'Login failed: $msg';
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.read(apiClientProvider);
  return AuthNotifier(api, ref);
});
