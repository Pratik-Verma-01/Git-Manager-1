# Git Manager (mobile)

Flutter Android client for **Git Manager** — browse, edit, and ship GitHub
repos from your phone, with Gemini as an in-repo assistant. Package name
`api.gitmanager.client`.

This app never holds a GitHub token, a Gemini key, or any other secret —
it only stores its own opaque session token (`flutter_secure_storage`) and
talks to the companion backend for everything else. See
`git-manager-backend/README.md` for that half.

## What's built so far

- **Design system** (`lib/theme/`): dark glassmorphism — frosted `GlassCard`
  surfaces, gradient buttons/chips, an animated drifting-blob background
  shared across every screen via one `AnimationController`, shimmer
  skeleton loaders.
- **Auth** (`lib/features/auth/`): "Continue with GitHub" → system browser
  (`flutter_web_auth_2`) → backend OAuth flow → deep-link handoff
  (`gitmanager://auth/callback`) → session token stored securely. Session
  is restored and validated on app start; a 401 anywhere in the app
  triggers an automatic sign-out back to the login screen.
- **Dashboard** (`lib/features/dashboard/`): profile header, quick actions,
  recent repositories.
- **Repository browser** (`lib/features/repositories/`): live search
  (debounced), All/Public/Private/Recently-updated filters, infinite
  scroll, pull-to-refresh, skeleton + empty + error states — all wired to
  the real backend, not sample data.
- **Shell** (`lib/features/shell/`): glass bottom nav across Home /
  Repositories / Activity / AI / Settings. Settings has a real account
  card and sign-out; Activity and AI are marked in-progress rather than
  faked.

## What's not built yet

Repository file explorer, code editor, diff/review screen, commit/branch
UI, pull requests, and the AI assistant screens — these come next, on top
of backend endpoints that already exist and are tested
(`git-manager-backend/README.md` has the full API reference).

## Running it

This project was created with `flutter create --org api.gitmanager
--project-name client`, so the Android package name is already correct —
nothing to rename.

```bash
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's alias for your host machine; point it
at your deployed backend URL for a real device:

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://your-project.vercel.app
```

No backend URL is hardcoded anywhere else in the app — `lib/core/config/env.dart`
is the one place it lives.

### Deep link

The GitHub sign-in callback uses the custom scheme `gitmanager://`,
already wired into `android/app/src/main/AndroidManifest.xml`. It must
match `MOBILE_REDIRECT_ALLOWLIST` on the backend exactly — both are set to
`gitmanager://auth/callback` by default.

### Release builds

The debug/profile manifests get internet access for free from Flutter
tooling; the main manifest now declares `INTERNET` explicitly (it isn't
there by default), so release builds can actually reach the backend —
easy to miss and a common silent-failure trap.
