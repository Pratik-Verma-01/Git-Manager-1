import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/shell/app_shell.dart';
import '../splash_screen.dart';

/// Bridges Riverpod's auth state to GoRouter's `refreshListenable`, so a
/// sign-in, sign-out, or session-expiry event re-runs the redirect logic
/// below without any screen having to manually navigate.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';

      switch (authState.status) {
        case AuthStatus.checking:
          return isSplash ? null : '/splash';
        case AuthStatus.unauthenticated:
          return isLoggingIn ? null : '/login';
        case AuthStatus.authenticated:
          return (isSplash || isLoggingIn) ? '/home' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const AppShell()),
    ],
  );
});
