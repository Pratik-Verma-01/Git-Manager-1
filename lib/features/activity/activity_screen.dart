import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/glass_widgets.dart';
import 'activity_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityControllerProvider);
    final controller = ref.read(activityControllerProvider.notifier);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Activity', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentViolet,
              backgroundColor: AppColors.backgroundIndigo,
              onRefresh: controller.fetch,
              child: _buildBody(context, state, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ActivityState state, ActivityController controller) {
    if (state.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
        itemCount: 6,
        itemBuilder: (context, index) => const GlassCardSkeleton(height: 72),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 120),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.warning),
                const SizedBox(height: AppSpacing.md),
                Text(state.error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                GradientButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: controller.fetch, expand: false),
              ],
            ),
          ),
        ],
      );
    }

    if (state.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 120),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 36, color: AppColors.accentCyan),
                const SizedBox(height: AppSpacing.md),
                Text('No recent activity', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Commits, pull requests, and other activity across your repos will show up here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
      itemCount: state.items.length,
      itemBuilder: (context, index) => _ActivityCard(item: state.items[index]),
    );
  }
}

IconData _iconForType(String type) {
  switch (type) {
    case 'PushEvent':
      return Icons.upload_rounded;
    case 'PullRequestEvent':
      return Icons.merge_type_rounded;
    case 'IssuesEvent':
    case 'IssueCommentEvent':
      return Icons.chat_bubble_outline_rounded;
    case 'PullRequestReviewEvent':
      return Icons.rate_review_outlined;
    case 'CreateEvent':
      return Icons.add_circle_outline_rounded;
    case 'DeleteEvent':
      return Icons.delete_outline_rounded;
    case 'WatchEvent':
      return Icons.star_outline_rounded;
    case 'ForkEvent':
      return Icons.call_split_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      blurred: false, // scrolling list — see GlassCard.blurred
      onTap: () => launchUrl(Uri.parse(item.htmlUrl), mode: LaunchMode.externalApplication),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_iconForType(item.type), size: 17, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.summary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.repoFullName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(timeAgo(item.createdAt!), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
