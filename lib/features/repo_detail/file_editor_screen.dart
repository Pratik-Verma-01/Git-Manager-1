import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/animated_background.dart';
import '../../theme/glass/glass_widgets.dart';
import '../repositories/repo_models.dart';

/// Opens one repository file for editing. Loading, saving (a real commit
/// via the backend's Contents API endpoint), and the unsaved-changes
/// guard are all real — this is a plain-text editor (no syntax
/// highlighting yet), not a mockup.
class FileEditorScreen extends ConsumerStatefulWidget {
  const FileEditorScreen({super.key, required this.repo, required this.path, this.initialSha});
  final GitRepo repo;
  final String path;
  final String? initialSha;

  @override
  ConsumerState<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends ConsumerState<FileEditorScreen> {
  final _controller = TextEditingController();
  String _originalContent = '';
  String? _sha;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  bool get _isDirty => _controller.text != _originalContent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await unwrapApi(
        () => api.raw.get(
          '/api/repos/${widget.repo.owner}/${widget.repo.name}/file',
          queryParameters: {'path': widget.path, 'ref': widget.repo.defaultBranch},
        ),
      );
      final data = response.data as Map<String, dynamic>;
      final content = data['content'] as String;
      setState(() {
        _originalContent = content;
        _controller.text = content;
        _sha = data['sha'] as String?;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundIndigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Discard changes?'),
        content: const Text("You have unsaved edits to this file. Leave without saving?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Discard', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    final message = await _promptCommitMessage();
    if (message == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final isWorkflow = widget.path.startsWith('.github/workflows/');
      Map<String, dynamic> body = {
        'content': _controller.text,
        'message': message,
        'branch': widget.repo.defaultBranch,
        if (_sha != null) 'sha': _sha,
      };

      doSave({bool confirmWorkflow = false}) => api.raw.put(
            '/api/repos/${widget.repo.owner}/${widget.repo.name}/file',
            queryParameters: {'path': widget.path},
            data: {...body, if (confirmWorkflow) 'confirmWorkflowChange': true},
          );

      try {
        final response = await unwrapApi(() => doSave());
        _onSaveSuccess(response.data as Map<String, dynamic>);
      } on ApiException catch (e) {
        if (e.errorCode == 'workflow_confirmation_required' && isWorkflow && mounted) {
          final confirmed = await _confirmWorkflowChange();
          if (confirmed == true) {
            final response = await unwrapApi(() => doSave(confirmWorkflow: true));
            _onSaveSuccess(response.data as Map<String, dynamic>);
          }
        } else {
          rethrow;
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger.withOpacity(0.85)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onSaveSuccess(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _originalContent = _controller.text;
      _sha = data['contentSha'] as String? ?? _sha;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Committed to GitHub.')));
  }

  Future<bool?> _confirmWorkflowChange() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundIndigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('This changes CI/CD'),
        content: const Text('This file is under .github/workflows/, which can change how your automated builds and deployments run. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue', style: TextStyle(color: AppColors.warning))),
        ],
      ),
    );
  }

  Future<String?> _promptCommitMessage() {
    final messageController = TextEditingController(text: 'Update ${widget.path.split('/').last}');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundIndigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Commit message'),
        content: TextField(
          controller: messageController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Describe your change'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(messageController.text.trim().isEmpty ? null : messageController.text.trim()),
            child: const Text('Commit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedAuroraBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () async {
                          if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.path.split('/').last, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                            Row(
                              children: [
                                Expanded(child: Text(widget.path, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                                if (_isDirty) ...[
                                  const SizedBox(width: 6),
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoading && _loadError == null)
                        GradientButton(
                          label: 'Save',
                          isLoading: _isSaving,
                          expand: false,
                          onPressed: (_isDirty && !_isSaving) ? _save : null,
                        ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accentViolet));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: GlassCard(
            blurred: false,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.warning),
                const SizedBox(height: AppSpacing.md),
                Text(_loadError!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                GradientButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _load, expand: false),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceStrong,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontFamily: 'monospace', height: 1.5),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(AppSpacing.md),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
