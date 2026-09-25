import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/glass_widgets.dart';
import '../auth/auth_controller.dart';
import '../repositories/repo_provider.dart';
import '../shell/app_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final repoState = ref.watch(repoListControllerProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 120),
        children: [
          _ProfileHeader(name: user?.displayName ?? user?.githubLogin, login: user?.githubLogin, avatarUrl: user?.avatarUrl),
          const SizedBox(height: AppSpacing.lg),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _QuickActionsRow(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent repositories', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => ref.read(selectedTabProvider.notifier).state = 1,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _RecentRepos(state: repoState),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({this.name, this.login, this.avatarUrl});
  final String? name;
  final String? login;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      strong: true,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.glassSurfaceStrong,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.textSecondary) : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back${name != null ? ', $name' : ''}', style: Theme.of(context).textTheme.titleMedium),
                if (login != null) Text('@$login', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      (icon: Icons.folder_open_rounded, label: 'Open Repo', tab: 1, needsRepo: false),
      (icon: Icons.upload_file_rounded, label: 'Upload Files', tab: 1, needsRepo: true),
      (icon: Icons.note_add_rounded, label: 'Create File', tab: 1, needsRepo: true),
      (icon: Icons.auto_awesome_rounded, label: 'AI Assistant', tab: 3, needsRepo: false),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final action = actions[index];
          return SizedBox(
            width: 92,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 4),
              blurred: false, // 4 of these render side by side — see GlassCard.blurred
              onTap: () {
                if (action.needsRepo) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pick a repository first')),
                  );
                }
                ref.read(selectedTabProvider.notifier).state = action.tab;
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: AppColors.accentCyan, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentRepos extends ConsumerWidget {
  const _RecentRepos({required this.state});
  final RepoListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return Column(children: List.generate(3, (_) => const GlassCardSkeleton(height: 64)));
    }

    if (state.repos.isEmpty) {
      return GlassCard(
        child: Text(
          state.error ?? 'No repositories yet — check which repos the GitHub App is installed on.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final recent = state.repos.take(3).toList();
    return Column(
      children: recent
          .map(
            (repo) => GlassCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              blurred: false, // up to 3 of these stack here — see GlassCard.blurred
              onTap: () => ref.read(selectedTabProvider.notifier).state = 1,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(repo.name, style: Theme.of(context).textTheme.titleMedium),
                        Text('Updated ${timeAgo(repo.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
