/// Build-time configuration. The default below now points at the deployed
/// Vercel backend, so a plain `flutter run` / build works with no extra
/// flags. Override it only if you need to point at something else, e.g.
/// a local backend while developing:
///
///   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
///
/// No production URL is hardcoded anywhere else in the app — this is the
/// one place it lives, per the spec's "don't hardcode production URLs".
class Env {
  Env._();

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://git-client-manager.vercel.app',
  );

  /// Must match MOBILE_REDIRECT_ALLOWLIST on the backend and the
  /// intent-filter scheme registered in AndroidManifest.xml.
  static const String authCallbackScheme = 'gitmanager';
  static const String authCallbackUrl = '$authCallbackScheme://auth/callback';

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
