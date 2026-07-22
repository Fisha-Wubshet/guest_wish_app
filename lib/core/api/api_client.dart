import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  late final Dio _dio;
  late String _serverRootUrl;
  bool _initialized = false;

  String? _refreshToken;
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshWaiters = [];
  Future<void> Function()? _onSessionExpired;
  void Function(bool online)? _onNetworkStatusChange;

  void setOnNetworkStatusChange(void Function(bool online) cb) => _onNetworkStatusChange = cb;

  bool _isNetworkError(DioException err) {
    // Real "no internet" symptoms: DNS/connection issues + total absence of any
    // HTTP response. A 4xx/5xx from the server means we ARE online.
    if (err.response != null) return false;
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.error is SocketException;
  }

  String _normalize(String url) {
    String u = url;
    if (Platform.isAndroid) {
      u = u.replaceFirst('localhost', '10.0.2.2').replaceFirst('127.0.0.1', '10.0.2.2');
    }
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final rawUrl = prefs.getString('server_url') ?? 'https://rent.gizebit.com';
    final baseUrl = _normalize(rawUrl);

    _serverRootUrl = baseUrl;
    final token = prefs.getString('token');
    _refreshToken = prefs.getString('refresh_token');

    _dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        // Any successful HTTP round-trip means we're online.
        _onNetworkStatusChange?.call(true);
        handler.next(response);
      },
      onError: (DioException err, ErrorInterceptorHandler handler) async {
        if (_isNetworkError(err)) {
          _onNetworkStatusChange?.call(false);
        } else {
          // Got a response (even a 4xx/5xx) — we're online.
          _onNetworkStatusChange?.call(true);
        }
        if (err.response?.statusCode == 401 && _refreshToken != null) {
          await _handleTokenRefresh(err, handler);
        } else {
          handler.next(err);
        }
      },
    ));

    _initialized = true;
  }

  // Intercepts a 401, refreshes the token, then retries the original request.
  // Concurrent 401s queue up and all retry once the single refresh completes.
  Future<void> _handleTokenRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshWaiters.add(completer);
      try {
        await completer.future;
        final retryOpts = err.requestOptions;
        retryOpts.headers['Authorization'] =
            _dio.options.headers['Authorization'];
        final response = await _dio.fetch(retryOpts);
        handler.resolve(response);
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;
    try {
      // Fresh Dio with no interceptors to avoid a recursive 401 loop.
      // Refresh endpoint is at root (no /api prefix), so use _serverRootUrl.
      final refreshDio = Dio(BaseOptions(
        baseUrl: _serverRootUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));
      final res = await refreshDio.post(
        '/auth/refresh-token',
        data: {'refreshToken': _refreshToken},
      );
      final data = res.data as Map<String, dynamic>;
      final newToken = data['token'] as String;
      final newRefresh =
          (data['refreshToken'] as String?) ?? _refreshToken!;

      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', newToken);
      await prefs.setString('refresh_token', newRefresh);

      // Update in-memory state
      _refreshToken = newRefresh;
      _dio.options.headers['Authorization'] = 'Bearer $newToken';

      // Unblock all queued requests
      for (final c in _refreshWaiters) {
        c.complete();
      }
      _refreshWaiters.clear();

      // Retry the original request with new token
      final retryOpts = err.requestOptions;
      retryOpts.headers['Authorization'] = 'Bearer $newToken';
      final response = await _dio.fetch(retryOpts);
      handler.resolve(response);
    } catch (e) {
      // Refresh token also expired — force the user back to login
      for (final c in _refreshWaiters) {
        c.completeError(e);
      }
      _refreshWaiters.clear();
      _onSessionExpired?.call();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void setRefreshToken(String token) => _refreshToken = token;

  void setOnSessionExpired(Future<void> Function() callback) {
    _onSessionExpired = callback;
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
    _refreshToken = null;
  }

  void updateBaseUrl(String serverUrl) {
    final url = _normalize(serverUrl);
    _serverRootUrl = url;
    _dio.options.baseUrl = '$url/api';
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> getRoot(String path, {Map<String, dynamic>? params}) =>
      _dio.get('$_serverRootUrl$path', queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> postRoot(String path, {dynamic data}) =>
      _dio.post('$_serverRootUrl$path', data: data);

  Future<Response> putRoot(String path, {dynamic data}) =>
      _dio.put('$_serverRootUrl$path', data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<List<int>> getBytes(String path, {Map<String, dynamic>? params}) async {
    final response = await _dio.get<List<int>>(
      path,
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }
}
