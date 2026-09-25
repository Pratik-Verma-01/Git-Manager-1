import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/animated_background.dart';
import '../../theme/glass/glass_widgets.dart';
import '../../theme/glass/liquid_glass_nav.dart';
import '../activity/activity_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_screen.dart';
import '../repositories/repo_list_screen.dart';

/// Which bottom-nav tab is active. Public so screens like the dashboard's
/// quick actions can switch tabs (e.g. "Open Repository" jumps to Repos).
final selectedTabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = [
    LiquidGlassNavItem(icon: Icons.home_rounded, label: 'Home'),
    LiquidGlassNavItem(icon: Icons.folder_rounded, label: 'Repos'),
    LiquidGlassNavItem(icon: Icons.bolt_rounded, label: 'Activity'),
    LiquidGlassNavItem(icon: Icons.auto_awesome_rounded, label: 'AI'),
    LiquidGlassNavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Without this, `body` stops above the bottom nav and there's
      // nothing colorful behind LiquidGlassNavBar's blur to pick up —
      // that's what was rendering as a flat white bar.
      extendBody: true,
      body: AnimatedAuroraBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: selected,
            children: const [
              DashboardScreen(),
              RepoListScreen(),
              ActivityScreen(),
              AiChatScreen(),
              _SettingsTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).padding.bottom * 0.4,
        ),
        child: LiquidGlassNavBar(
          items: _tabs,
          selectedIndex: selected,
          onSelected: (i) => ref.read(selectedTabProvider.notifier).state = i,
        ),
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.glassSurfaceStrong,
                  backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                  child: user?.avatarUrl == null ? const Icon(Icons.person, color: AppColors.textSecondary) : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? user?.githubLogin ?? '', style: Theme.of(context).textTheme.titleMedium),
                      Text('@${user?.githubLogin ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _SettingsRow(icon: Icons.auto_awesome_rounded, title: 'Gemini AI', trailing: 'Enabled'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const _SettingsRow(icon: Icons.dark_mode_rounded, title: 'Appearance', trailing: 'Dark'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  isDestructive: true,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundIndigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign in with GitHub again to continue."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, this.trailing, this.onTap, this.isDestructive = false});
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isDestructive ? AppColors.danger : AppColors.textSecondary),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: trailing != null
          ? Text(trailing!, style: const TextStyle(color: AppColors.textMuted))
          : (onTap != null ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted) : null),
    );
  }
}
