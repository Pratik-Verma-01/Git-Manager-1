class AiProposalChange {
  const AiProposalChange({required this.path, required this.operation, this.content, this.previousPath});

  final String path;
  final String operation; // create | modify | delete | rename
  final String? content;
  final String? previousPath;

  factory AiProposalChange.fromJson(Map<String, dynamic> json) => AiProposalChange(
        path: json['path'] as String,
        operation: json['operation'] as String,
        content: json['content'] as String?,
        previousPath: json['previousPath'] as String?,
      );

  Map<String, dynamic> toCommitJson() => {
        'path': path,
        'operation': operation,
        if (content != null) 'content': content,
        if (previousPath != null) 'previousPath': previousPath,
      };
}

class AiProposal {
  const AiProposal({
    required this.summary,
    required this.changes,
    required this.warnings,
    required this.testsSuggested,
    required this.riskLevel,
  });

  final String summary;
  final List<AiProposalChange> changes;
  final List<String> warnings;
  final List<String> testsSuggested;
  final String riskLevel; // low | medium | high

  factory AiProposal.fromJson(Map<String, dynamic> json) => AiProposal(
        summary: json['summary'] as String,
        changes: (json['changes'] as List).map((c) => AiProposalChange.fromJson(c as Map<String, dynamic>)).toList(),
        warnings: (json['warnings'] as List?)?.map((w) => w as String).toList() ?? const [],
        testsSuggested: (json['testsSuggested'] as List?)?.map((t) => t as String).toList() ?? const [],
        riskLevel: json['riskLevel'] as String? ?? 'low',
      );

  bool get touchesWorkflows => changes.any((c) => c.path.startsWith('.github/workflows/'));
}

enum ProposalStatus { pending, committing, accepted, declined, failed }
