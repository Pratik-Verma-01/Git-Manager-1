import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/glass_widgets.dart';
import '../repositories/repo_models.dart';
import '../repositories/repo_provider.dart';
import 'ai_chat_provider.dart';
import 'ai_proposal_models.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(aiChatControllerProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatControllerProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Text('AI Assistant', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                GlassChip(
                  label: state.attachedRepo == null ? 'Ask mode' : 'Edit mode',
                  icon: state.attachedRepo == null ? Icons.chat_bubble_outline_rounded : Icons.edit_note_rounded,
                  dense: true,
                ),
              ],
            ),
          ),
          _RepoAttachmentBar(state: state),
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyChatState(hasRepo: state.attachedRepo != null)
                : _MessageList(state: state, scrollController: _scrollController),
          ),
          _ChatInputBar(controller: _inputController, isSending: state.isSending, onSend: _send),
        ],
      ),
    );
  }
}

class _RepoAttachmentBar extends ConsumerWidget {
  const _RepoAttachmentBar({required this.state});
  final AiChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          if (state.attachedRepo == null)
            GlassChip(
              label: 'Attach a repo',
              icon: Icons.add_circle_outline_rounded,
              dense: true,
              onTap: () => _showRepoPicker(context, ref),
            )
          else
            GlassChip(
              label: state.attachedRepo!.name,
              icon: Icons.folder_rounded,
              selected: true,
              dense: true,
              onTap: () => ref.read(aiChatControllerProvider.notifier).detachRepo(),
            ),
          if (state.attachedRepo != null) ...[
            const SizedBox(width: 8),
            Text('tap to remove', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

void _showRepoPicker(BuildContext context, WidgetRef ref) {
  final repoState = ref.read(repoListControllerProvider);
  if (repoState.repos.isEmpty) {
    ref.read(repoListControllerProvider.notifier).fetch(reset: true);
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _RepoPickerSheet(),
  );
}

class _RepoPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoState = ref.watch(repoListControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        top: AppSpacing.sm,
      ),
      child: GlassCard(
        strong: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Attach a repository', style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              if (repoState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accentViolet)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: repoState.repos.length,
                    itemBuilder: (context, index) {
                      final repo = repoState.repos[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded, color: AppColors.accentCyan),
                        title: Text(repo.name),
                        subtitle: Text(repo.owner, style: Theme.of(context).textTheme.bodySmall),
                        onTap: () {
                          ref.read(aiChatControllerProvider.notifier).attachRepo(repo);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.hasRepo});
  final bool hasRepo;

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
              const Icon(Icons.auto_awesome_rounded, size: 36, color: AppColors.accentCyan),
              const SizedBox(height: AppSpacing.md),
              Text(hasRepo ? 'Ask for a change' : 'Ask me anything about code', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hasRepo
                    ? 'Describe what you want changed. I\'ll propose the edit — nothing '
                        'reaches GitHub until you tap Accept. I don\'t have your file tree yet, '
                        'so be specific about file names and paths.'
                    : 'General coding help for now — attach a repo above once you want '
                        'real edits proposed for it.',
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

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state, required this.scrollController});
  final AiChatState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      itemCount: state.messages.length + (state.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.messages.length) {
          return const _TypingIndicator();
        }
        final message = state.messages[index];
        return message.proposal != null ? _ProposalBubble(message: message) : _MessageBubble(message: message);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: isUser
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
              )
            : GlassCard(
                borderRadius: AppRadius.md,
                blurred: false, // a long conversation renders many of these — see GlassCard.blurred
                child: Text(
                  message.text,
                  style: TextStyle(color: message.isError ? AppColors.danger : AppColors.textPrimary, fontSize: 14.5, height: 1.35),
                ),
              ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level});
  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'high' => AppColors.danger,
      'medium' => AppColors.warning,
      _ => AppColors.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text('${level[0].toUpperCase()}${level.substring(1)} risk', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Renders an AI edit-mode proposal: summary, changed files, risk level,
/// and — the one place in the app an AI suggestion can actually reach
/// GitHub — Accept/Decline. Nothing here applies itself; Accept makes one
/// explicit API call the user just triggered.
class _ProposalBubble extends ConsumerWidget {
  const _ProposalBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposal = message.proposal!;
    final status = message.proposalStatus ?? ProposalStatus.pending;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: GlassCard(
          borderRadius: AppRadius.md,
          strong: true,
          blurred: false, // proposal cards can repeat down a long conversation — see GlassCard.blurred
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentCyan),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Proposed change', style: Theme.of(context).textTheme.bodySmall)),
                  _RiskBadge(level: proposal.riskLevel),
                ],
              ),
              const SizedBox(height: 8),
              Text(proposal.summary, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.35)),
              const SizedBox(height: 10),
              ...proposal.changes.map((c) => _ChangeLine(change: c)),
              if (proposal.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...proposal.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(child: Text(w, style: const TextStyle(color: AppColors.warning, fontSize: 12.5))),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _ProposalActions(message: message, status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change});
  final AiProposalChange change;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (change.operation) {
      'create' => (Icons.add_rounded, AppColors.success),
      'delete' => (Icons.remove_rounded, AppColors.danger),
      'rename' => (Icons.drive_file_rename_outline_rounded, AppColors.warning),
      _ => (Icons.edit_rounded, AppColors.accentBlue),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              change.path,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalActions extends ConsumerWidget {
  const _ProposalActions({required this.message, required this.status});
  final ChatMessage message;
  final ProposalStatus status;

  Future<void> _accept(BuildContext context, WidgetRef ref, {bool confirmWorkflowChange = false}) async {
    try {
      await ref.read(aiChatControllerProvider.notifier).acceptProposal(message, confirmWorkflowChange: confirmWorkflowChange);
    } on ApiException catch (e) {
      if (e.errorCode == 'workflow_confirmation_required' && context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.backgroundIndigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            title: const Text('This changes CI/CD'),
            content: const Text('This proposal edits a file under .github/workflows/, which can change how your automated builds and deployments run. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue', style: TextStyle(color: AppColors.warning))),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await _accept(context, ref, confirmWorkflowChange: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (status) {
      case ProposalStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref.read(aiChatControllerProvider.notifier).declineProposal(message),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(label: 'Accept & Commit', onPressed: () => _accept(context, ref)),
            ),
          ],
        );
      case ProposalStatus.committing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accentCyan))),
        );
      case ProposalStatus.accepted:
        return Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            const Text('Committed', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
            if (message.commitHtmlUrl != null) ...[
              const Spacer(),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(message.commitHtmlUrl!), mode: LaunchMode.externalApplication),
                child: const Text('View commit'),
              ),
            ],
          ],
        );
      case ProposalStatus.declined:
        return const Row(
          children: [
            Icon(Icons.cancel_rounded, size: 16, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text('Declined — nothing was changed', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        );
      case ProposalStatus.failed:
        return Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
            const SizedBox(width: 6),
            const Expanded(child: Text('Commit failed — see message below', style: TextStyle(color: AppColors.danger, fontSize: 13))),
            TextButton(onPressed: () => _accept(context, ref), child: const Text('Retry')),
          ],
        );
    }
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: GlassCard(
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: const SizedBox(
            width: 20,
            height: 14,
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accentCyan))),
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends ConsumerWidget {
  const _ChatInputBar({required this.controller, required this.isSending, required this.onSend});
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachedRepo = ref.watch(aiChatControllerProvider.select((s) => s.attachedRepo));

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: GlassCard(
        borderRadius: AppRadius.pill,
        padding: const EdgeInsets.only(left: AppSpacing.md, right: 6, top: 6, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: attachedRepo == null ? 'Ask a coding question…' : 'Describe the change you want…',
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isSending ? null : onSend,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: isSending ? null : AppColors.primaryGradient,
                    color: isSending ? AppColors.glassSurfaceStrong : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_upward_rounded, size: 19, color: isSending ? AppColors.textMuted : Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
