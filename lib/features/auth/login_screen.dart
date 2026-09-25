import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/animated_background.dart';
import '../../theme/glass/glass_widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Local, UI-only loading flag for the moment the system browser is open
  // and the handoff/session-exchange calls are in flight. Deliberately not
  // part of AuthState — nothing outside this screen needs to know about it,
  // and AuthStatus.checking already means something different (validating
  // a stored session at app startup, before this screen is ever shown).
  bool _isSigningIn = false;

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    try {
      await ref.read(authControllerProvider.notifier).signInWithGitHub();
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.danger.withOpacity(0.85)),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedAuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                _AppMark(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Git Manager',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 30),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Browse, edit, and ship your GitHub repos\nright from your phone — with Gemini at your side.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(flex: 4),
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const _PermissionLine(
                        icon: Icons.folder_open_rounded,
                        text: 'Access only the repositories you choose to share',
                      ),
                      const SizedBox(height: 10),
                      const _PermissionLine(
                        icon: Icons.edit_note_rounded,
                        text: 'Read and write files, branches, and commits',
                      ),
                      const SizedBox(height: 10),
                      const _PermissionLine(
                        icon: Icons.shield_outlined,
                        text: 'Nothing is ever pushed without your approval',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GradientButton(
                        label: _isSigningIn ? 'Waiting for GitHub…' : 'Continue with GitHub',
                        icon: Icons.merge_type_rounded,
                        isLoading: _isSigningIn,
                        onPressed: _isSigningIn ? null : _signIn,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Your GitHub credentials are never stored on this device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: AppColors.auroraGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.accentViolet.withOpacity(0.45), blurRadius: 32, offset: const Offset(0, 12))],
      ),
      child: const Icon(Icons.merge_type_rounded, color: Colors.white, size: 40),
    );
  }
}

class _PermissionLine extends StatelessWidget {
  const _PermissionLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accentCyan),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))),
      ],
    );
  }
}
