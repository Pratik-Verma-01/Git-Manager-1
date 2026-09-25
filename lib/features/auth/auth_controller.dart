import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/network/secure_storage.dart';

class GitHubUser {
  const GitHubUser({required this.id, required this.githubLogin, this.avatarUrl, this.displayName});

  final String id;
  final String githubLogin;
  final String? avatarUrl;
  final String? displayName;

  factory GitHubUser.fromJson(Map<String, dynamic> json) => GitHubUser(
        id: json['id'] as String,
        githubLogin: json['githubLogin'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        displayName: json['displayName'] as String?,
      );
}

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user, this.error});

  final AuthStatus status;
  final GitHubUser? user;
  final String? error;

  static const checking = AuthState(status: AuthStatus.checking);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);

  AuthState copyWith({AuthStatus? status, GitHubUser? user, String? error, bool clearError = false}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The ApiClient is recreated with this provider container so its
/// onSessionExpired callback can reach back into AuthController — see
/// main.dart for where these are wired together.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(onSessionExpired: () => ref.read(authControllerProvider.notifier).handleSessionExpired());
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Fire-and-forget: check for an existing session as soon as the
    // provider is first read (app startup), without blocking `build()`.
    Future.microtask(_restoreSession);
    return AuthState.checking;
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _restoreSession() async {
    final token = await SecureSessionStorage.instance.readSessionToken();
    if (token == null) {
      state = AuthState.unauthenticated;
      return;
    }

    try {
      final response = await unwrapApi(() => _api.raw.get('/api/auth/me'));
      final user = GitHubUser.fromJson((response.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException {
      await SecureSessionStorage.instance.clear();
      state = AuthState.unauthenticated;
    }
  }

  Future<void> signInWithGitHub() async {
    state = state.copyWith(clearError: true);

    try {
      final authorizeUrl = Uri.parse('${Env.backendBaseUrl}/api/auth/github').replace(queryParameters: {
        'mobile_redirect': Env.authCallbackUrl,
      });

      final resultUrl = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: Env.authCallbackScheme,
      );

      final uri = Uri.parse(resultUrl);
      final errorParam = uri.queryParameters['error'];
      if (errorParam != null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: _friendlyAuthError(errorParam));
        return;
      }

      final handoffCode = uri.queryParameters['handoff'];
      if (handoffCode == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: 'Sign-in did not complete. Please try again.');
        return;
      }

      final response = await unwrapApi(
        () => _api.raw.post('/api/auth/session/exchange', data: {'code': handoffCode}),
      );
      final data = response.data as Map<String, dynamic>;
      final sessionToken = data['sessionToken'] as String;
      final user = GitHubUser.fromJson(data['user'] as Map<String, dynamic>);

      await SecureSessionStorage.instance.writeSessionToken(sessionToken);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.message);
    } catch (_) {
      // FlutterWebAuth2 throws when the user dismisses the browser tab
      // before completing sign-in (not an ApiException, so it doesn't hit
      // the branch above). Treated as a quiet, expected outcome rather
      // than an alarming error.
      state = state.copyWith(status: AuthStatus.unauthenticated, error: 'Sign-in was cancelled.');
    }
  }

  Future<void> signOut() async {
    try {
      await unwrapApi(() => _api.raw.post('/api/auth/logout'));
    } on ApiException {
      // Still clear local state even if the network call failed — the
      // session token becomes useless to the user either way once it's
      // wiped from the device.
    }
    await SecureSessionStorage.instance.clear();
    state = AuthState.unauthenticated;
  }

  /// Called by ApiClient when any request comes back 401 mid-session —
  /// the token expired or was revoked server-side.
  Future<void> handleSessionExpired() async {
    await SecureSessionStorage.instance.clear();
    state = state.copyWith(status: AuthStatus.unauthenticated, error: 'Your session has expired. Please sign in again.');
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'cancelled':
        return 'Sign-in was cancelled.';
      case 'missing_code':
      case 'github_error':
        return 'GitHub could not complete sign-in. Please try again.';
      default:
        return 'Something went wrong signing in. Please try again.';
    }
  }
}
