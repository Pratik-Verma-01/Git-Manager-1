import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../repositories/repo_models.dart';
import 'ai_proposal_models.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.isError = false,
    this.proposal,
    this.proposalStatus,
    this.commitHtmlUrl,
  });

  final int id;
  final ChatRole role;
  final String text;
  final bool isError;
  final AiProposal? proposal;
  final ProposalStatus? proposalStatus;
  final String? commitHtmlUrl;

  ChatMessage copyWith({ProposalStatus? proposalStatus, String? commitHtmlUrl}) => ChatMessage(
        id: id,
        role: role,
        text: text,
        isError: isError,
        proposal: proposal,
        proposalStatus: proposalStatus ?? this.proposalStatus,
        commitHtmlUrl: commitHtmlUrl ?? this.commitHtmlUrl,
      );
}

class AiChatState {
  const AiChatState({this.messages = const [], this.isSending = false, this.attachedRepo});
  final List<ChatMessage> messages;
  final bool isSending;
  final GitRepo? attachedRepo;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    GitRepo? attachedRepo,
    bool clearAttachedRepo = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      attachedRepo: clearAttachedRepo ? null : (attachedRepo ?? this.attachedRepo),
    );
  }
}

final aiChatControllerProvider = NotifierProvider<AiChatController, AiChatState>(AiChatController.new);

class AiChatController extends Notifier<AiChatState> {
  int _nextId = 0;

  @override
  AiChatState build() => const AiChatState();

  ApiClient get _api => ref.read(apiClientProvider);

  void attachRepo(GitRepo repo) => state = state.copyWith(attachedRepo: repo);

  void detachRepo() => state = state.copyWith(clearAttachedRepo: true);

  /// With no repo attached: general ask-mode chat (no repository context —
  /// that needs the file explorer, which isn't built yet). With a repo
  /// attached: EDIT MODE — the backend returns a structured, validated
  /// proposal rather than plain text, rendered with Accept/Decline instead
  /// of applying anything automatically.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final attachedRepo = state.attachedRepo;
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(id: _nextId++, role: ChatRole.user, text: trimmed)],
      isSending: true,
    );

    try {
      if (attachedRepo == null) {
        final response = await unwrapApi(
          () => _api.raw.post('/api/ai/chat', data: {
            'userInstruction': trimmed,
            'selectedFiles': [],
            'fileTreePaths': [],
          }),
        );
        final explanation = (response.data as Map<String, dynamic>)['explanation'] as String? ?? '';
        state = state.copyWith(
          messages: [...state.messages, ChatMessage(id: _nextId++, role: ChatRole.assistant, text: explanation)],
          isSending: false,
        );
        return;
      }

      final response = await unwrapApi(
        () => _api.raw.post('/api/ai/propose-changes', data: {
          'repoFullName': attachedRepo.fullName,
          'userInstruction': trimmed,
          'selectedFiles': [],
          // No file tree yet (needs the file explorer) — the assistant works
          // from the instruction alone for now, which the empty state and
          // the message below are upfront about rather than implying full
          // repo awareness it doesn't have.
          'fileTreePaths': [],
        }),
      );
      final data = response.data as Map<String, dynamic>;
      final proposal = AiProposal.fromJson(data['proposal'] as Map<String, dynamic>);
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: _nextId++,
            role: ChatRole.assistant,
            text: proposal.summary,
            proposal: proposal,
            proposalStatus: ProposalStatus.pending,
          ),
        ],
        isSending: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(id: _nextId++, role: ChatRole.assistant, text: e.message, isError: true)],
        isSending: false,
      );
    }
  }

  void _updateMessage(int id, ChatMessage Function(ChatMessage) update) {
    state = state.copyWith(
      messages: [for (final m in state.messages) if (m.id == id) update(m) else m],
    );
  }

  void declineProposal(ChatMessage message) {
    _updateMessage(message.id, (m) => m.copyWith(proposalStatus: ProposalStatus.declined));
  }

  /// The only place in the whole app where an AI proposal actually reaches
  /// GitHub — a real, explicit tap, never automatic. Reuses the same batch
  /// commit endpoint the (future) manual Review Changes screen will use,
  /// so a multi-file proposal lands as one real commit.
  Future<void> acceptProposal(ChatMessage message, {bool confirmWorkflowChange = false}) async {
    final proposal = message.proposal;
    final repo = state.attachedRepo;
    if (proposal == null || repo == null) return;

    _updateMessage(message.id, (m) => m.copyWith(proposalStatus: ProposalStatus.committing));

    try {
      final response = await unwrapApi(
        () => _api.raw.post('/api/repos/${repo.owner}/${repo.name}/commit', data: {
          'branch': repo.defaultBranch,
          'message': proposal.summary,
          'changes': proposal.changes.map((c) => c.toCommitJson()).toList(),
          if (confirmWorkflowChange) 'confirmWorkflowChange': true,
        }),
      );
      final commitUrl = (response.data as Map<String, dynamic>)['htmlUrl'] as String?;
      _updateMessage(message.id, (m) => m.copyWith(proposalStatus: ProposalStatus.accepted, commitHtmlUrl: commitUrl));
    } on ApiException catch (e) {
      if (e.errorCode == 'workflow_confirmation_required' && !confirmWorkflowChange) {
        rethrow; // let the UI ask for explicit workflow confirmation, then retry
      }
      _updateMessage(message.id, (m) => m.copyWith(proposalStatus: ProposalStatus.failed));
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(id: _nextId++, role: ChatRole.assistant, text: e.message, isError: true)],
      );
    }
  }
}
