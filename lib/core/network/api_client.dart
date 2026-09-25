import 'package:dio/dio.dart';
import '../config/env.dart';
import 'secure_storage.dart';

/// A backend error response, normalized. The backend always replies with
/// `{ error, message }` on failure (see backend/src/middleware/errorHandler.ts
/// and github/errors.ts) so the UI can show `message` directly without
/// screen-specific error copy everywhere it calls the API.
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.errorCode, required this.message});

  final int? statusCode;
  final String errorCode;
  final String message;

  bool get isReauthRequired => statusCode == 401 || errorCode == 'reauth_required';
  bool get isRateLimited => statusCode == 429 || errorCode == 'rate_limited';

  @override
  String toString() => message;
}

/// Thin wrapper around a single shared Dio instance. Every repository in
/// the app goes through this rather than constructing its own Dio, so the
/// auth header, error mapping, and session-expiry signal all live in one
/// place.
class ApiClient {
  ApiClient({void Function()? onSessionExpired}) : _onSessionExpired = onSessionExpired {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.backendBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        // AI endpoints (propose-changes especially) can legitimately take
        // a while — this is a client-side ceiling, not a hint to the
        // backend, so it's set generously rather than tightly.
        receiveTimeout: const Duration(seconds: 45),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureSessionStorage.instance.readSessionToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final apiError = _mapError(error);
          if (apiError.isReauthRequired) {
            _onSessionExpired?.call();
          }
          handler.reject(DioException(requestOptions: error.requestOptions, error: apiError, response: error.response));
        },
      ),
    );
  }

  late final Dio _dio;
  final void Function()? _onSessionExpired;

  Dio get raw => _dio;

  ApiException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException(
        statusCode: error.response?.statusCode,
        errorCode: (data['error'] as String?) ?? 'unknown_error',
        message: (data['message'] as String?) ?? 'Something went wrong. Please try again.',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.connectionError) {
      return ApiException(statusCode: null, errorCode: 'offline', message: "You're offline — check your connection and try again.");
    }
    if (error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.sendTimeout) {
      return ApiException(statusCode: null, errorCode: 'timeout', message: 'That took too long. Please try again.');
    }

    return ApiException(statusCode: error.response?.statusCode, errorCode: 'unknown_error', message: 'Something went wrong. Please try again.');
  }
}

/// Unwraps the ApiException a Dio call throws so call sites can `catch (e)`
/// and get the typed exception directly instead of a DioException wrapper.
Future<T> unwrapApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    if (e.error is ApiException) throw e.error as ApiException;
    throw ApiException(statusCode: e.response?.statusCode, errorCode: 'unknown_error', message: 'Something went wrong. Please try again.');
  }
}
