import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/network/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/glass_widgets.dart';
import 'repo_models.dart';
import 'repo_provider.dart';

class RepoListScreen extends ConsumerStatefulWidget {
  const RepoListScreen({super.key});

  @override
  ConsumerState<RepoListScreen> createState() => _RepoListScreenState();
}

class _RepoListScreenState extends ConsumerState<RepoListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(repoListControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repoListControllerProvider);
    final controller = ref.read(repoListControllerProvider.notifier);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Repositories', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                _SearchField(controller: _searchController, onChanged: controller.setSearch),
                const SizedBox(height: AppSpacing.sm),
                _FilterRow(state: state, controller: controller),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentViolet,
              backgroundColor: AppColors.backgroundIndigo,
              onRefresh: () => controller.fetch(reset: true),
              child: _buildBody(state, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(RepoListState state, RepoListController controller) {
    if (state.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
        itemCount: 6,
        itemBuilder: (context, index) => const GlassCardSkeleton(),
      );
    }

    if (state.error != null && state.repos.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: () => controller.fetch(reset: true));
    }

    if (state.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
      itemCount: state.repos.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.repos.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accentViolet)),
          );
        }
        return _RepoCard(repo: state.repos[index]);
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
      decoration: const InputDecoration(
        hintText: 'Search your repositories',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
        isDense: true,
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.state, required this.controller});
  final RepoListState state;
  final RepoListController controller;

  @override
  Widget build(BuildContext context) {
    final isRecentPreset = state.typeFilter == RepoTypeFilter.all && state.sort == RepoSort.updated;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GlassChip(
            label: 'All',
            dense: true,
            selected: state.typeFilter == RepoTypeFilter.all && !isRecentPreset,
            onTap: () => controller.setTypeFilter(RepoTypeFilter.all),
          ),
          const SizedBox(width: 8),
          GlassChip(
            label: 'Public',
            dense: true,
            selected: state.typeFilter == RepoTypeFilter.public,
            onTap: () => controller.setTypeFilter(RepoTypeFilter.public),
          ),
          const SizedBox(width: 8),
          GlassChip(
            label: 'Private',
            dense: true,
            selected: state.typeFilter == RepoTypeFilter.private,
            onTap: () => controller.setTypeFilter(RepoTypeFilter.private),
          ),
          const SizedBox(width: 8),
          GlassChip(
            label: 'Recently updated',
            dense: true,
            icon: Icons.schedule_rounded,
            selected: isRecentPreset,
            onTap: () {
              controller.setSort(RepoSort.updated);
              controller.setTypeFilter(RepoTypeFilter.all);
            },
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends ConsumerWidget {
  const _RepoCard({required this.repo});
  final GitRepo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      blurred: false, // a scrolling list of these is the exact case GlassCard.blurred exists for
      onTap: () {
        // Repository detail (file explorer, editor, commits, PRs) lands in
        // the next update — this card is fully wired to real data already.
      },
      onLongPress: () => _showRepoActions(context, ref, repo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: repo.ownerAvatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: repo.ownerAvatarUrl!,
                        width: 36,
                        height: 36,
                        placeholder: (context, url) => const GlassSkeleton(height: 36, width: 36, borderRadius: AppRadius.sm),
                      )
                    : Container(width: 36, height: 36, color: AppColors.glassSurfaceStrong),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    Text(repo.owner, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                repo.isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
          if (repo.description != null && repo.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              repo.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (repo.language != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.accentCyan, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(repo.language!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: AppSpacing.md),
              ],
              const Icon(Icons.star_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text('${repo.stargazersCount}', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(timeAgo(repo.updatedAt), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_rounded, size: 36, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text('No repositories found', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try a different search, or check which repositories\nthe GitHub App is installed on.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.warning),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              GradientButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
            ],
          ),
        ),
      ),
    );
  }
}

void _showRepoActions(BuildContext context, WidgetRef ref, GitRepo repo) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      child: GlassCard(
        strong: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(repo.fullName, style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
            ),
            _ActionRow(
              icon: repo.isPrivate ? Icons.public_rounded : Icons.lock_rounded,
              label: repo.isPrivate ? 'Make public' : 'Make private',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _toggleVisibility(context, ref, repo);
              },
            ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete repository',
              isDestructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, repo);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _toggleVisibility(BuildContext context, WidgetRef ref, GitRepo repo) async {
  final makingPrivate = !repo.isPrivate;
  try {
    await ref.read(repoListControllerProvider.notifier).setVisibility(repo, isPrivate: makingPrivate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${repo.name} is now ${makingPrivate ? 'private' : 'public'}.')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger.withOpacity(0.85)),
      );
    }
  }
}

void _confirmDelete(BuildContext context, WidgetRef ref, GitRepo repo) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.backgroundIndigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      title: const Text('Delete this repository?'),
      content: Text(
        '"${repo.fullName}" will be permanently deleted from GitHub, including all commits, issues, and pull requests. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              await ref.read(repoListControllerProvider.notifier).deleteRepo(repo);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${repo.name} was deleted.')));
              }
            } on ApiException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: AppColors.danger.withOpacity(0.85)),
                );
              }
            }
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.isDestructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isDestructive ? AppColors.danger : AppColors.textSecondary),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    );
  }
}
