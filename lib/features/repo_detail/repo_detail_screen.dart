import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass/animated_background.dart';
import '../../theme/glass/glass_widgets.dart';
import '../repositories/repo_models.dart';
import 'file_editor_screen.dart';
import 'tree_models.dart';

/// Repository file explorer: browse the real GitHub file tree, tap a
/// folder to go deeper, tap a file to open it in the editor. Pushed on
/// top of the tab shell (Navigator.push), not part of the bottom nav.
class RepoDetailScreen extends ConsumerStatefulWidget {
  const RepoDetailScreen({super.key, required this.repo});
  final GitRepo repo;

  @override
  ConsumerState<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends ConsumerState<RepoDetailScreen> {
  String _path = ''; // '' = repo root
  List<TreeEntry> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await unwrapApi(
        () => api.raw.get(
          '/api/repos/${widget.repo.owner}/${widget.repo.name}/tree',
          queryParameters: {if (_path.isNotEmpty) 'path': _path, 'ref': widget.repo.defaultBranch},
        ),
      );
      final data = response.data as Map<String, dynamic>;
      final entries = (data['entries'] as List).map((e) => TreeEntry.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _openFolder(String path) {
    setState(() => _path = path);
    _load();
  }

  void _openFile(TreeEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileEditorScreen(repo: widget.repo, path: entry.path, initialSha: entry.sha),
      ),
    );
  }

  List<String> get _breadcrumbSegments => _path.isEmpty ? [] : _path.split('/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.repo.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(widget.repo.defaultBranch, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _load),
                  ],
                ),
              ),
              _Breadcrumbs(
                repoName: widget.repo.name,
                segments: _breadcrumbSegments,
                onTapRoot: () => _openFolder(''),
                onTapSegment: (index) => _openFolder(_breadcrumbSegments.take(index + 1).join('/')),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accentViolet,
                  backgroundColor: AppColors.backgroundIndigo,
                  onRefresh: _load,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 40),
        itemCount: 6,
        itemBuilder: (context, index) => const GlassCardSkeleton(height: 56),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GlassCard(
            blurred: false,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.warning),
                const SizedBox(height: AppSpacing.md),
                Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                GradientButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _load, expand: false),
              ],
            ),
          ),
        ],
      );
    }

    if (_entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Center(child: Padding(padding: EdgeInsets.only(top: 60), child: Icon(Icons.folder_off_rounded, size: 36, color: AppColors.textMuted))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 40),
      itemCount: _entries.length,
      itemBuilder: (context, index) => _EntryRow(entry: _entries[index], onOpenFolder: _openFolder, onOpenFile: _openFile),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.repoName, required this.segments, required this.onTapRoot, required this.onTapSegment});
  final String repoName;
  final List<String> segments;
  final VoidCallback onTapRoot;
  final ValueChanged<int> onTapSegment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _crumb(context, repoName, onTapRoot, isLast: segments.isEmpty),
            for (var i = 0; i < segments.length; i++) ...[
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
              _crumb(context, segments[i], () => onTapSegment(i), isLast: i == segments.length - 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _crumb(BuildContext context, String label, VoidCallback onTap, {required bool isLast}) {
    return InkWell(
      onTap: isLast ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
            color: isLast ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onOpenFolder, required this.onOpenFile});
  final TreeEntry entry;
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<TreeEntry> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      blurred: false,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      onTap: entry.isDirectory ? () => onOpenFolder(entry.path) : () => onOpenFile(entry),
      child: Row(
        children: [
          Icon(_iconFor(entry), size: 19, color: entry.isDirectory ? AppColors.accentCyan : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(entry.name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary))),
          if (entry.isDirectory) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  IconData _iconFor(TreeEntry entry) {
    if (entry.isDirectory) return Icons.folder_rounded;
    final ext = entry.name.contains('.') ? entry.name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'dart':
        return Icons.flutter_dash_rounded;
      case 'js':
      case 'jsx':
      case 'ts':
      case 'tsx':
        return Icons.javascript_rounded;
      case 'json':
        return Icons.data_object_rounded;
      case 'md':
        return Icons.description_rounded;
      case 'yaml':
      case 'yml':
        return Icons.settings_suggest_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'svg':
        return Icons.image_rounded;
      case 'gradle':
      case 'kts':
        return Icons.build_rounded;
      case 'py':
        return Icons.code_rounded;
      case 'html':
      case 'css':
        return Icons.web_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
