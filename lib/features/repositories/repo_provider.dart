import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import 'repo_models.dart';

class RepoListState {
  const RepoListState({
    this.repos = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasNextPage = false,
    this.page = 1,
    this.search = '',
    this.typeFilter = RepoTypeFilter.all,
    this.sort = RepoSort.updated,
    this.error,
  });

  final List<GitRepo> repos;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasNextPage;
  final int page;
  final String search;
  final RepoTypeFilter typeFilter;
  final RepoSort sort;
  final String? error;

  bool get isEmpty => !isLoading && repos.isEmpty;

  RepoListState copyWith({
    List<GitRepo>? repos,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasNextPage,
    int? page,
    String? search,
    RepoTypeFilter? typeFilter,
    RepoSort? sort,
    String? error,
    bool clearError = false,
  }) {
    return RepoListState(
      repos: repos ?? this.repos,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      page: page ?? this.page,
      search: search ?? this.search,
      typeFilter: typeFilter ?? this.typeFilter,
      sort: sort ?? this.sort,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final repoListControllerProvider = NotifierProvider<RepoListController, RepoListState>(RepoListController.new);

class RepoListController extends Notifier<RepoListState> {
  Timer? _debounce;

  @override
  RepoListState build() {
    Future.microtask(() => fetch(reset: true));
    ref.onDispose(() => _debounce?.cancel());
    return const RepoListState(isLoading: true);
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetch({bool reset = false}) async {
    final targetPage = reset ? 1 : state.page + 1;
    state = state.copyWith(
      isLoading: reset,
      isLoadingMore: !reset,
      clearError: true,
    );

    try {
      final response = await unwrapApi(
        () => _api.raw.get('/api/repos', queryParameters: {
          if (state.search.isNotEmpty) 'search': state.search,
          'type': state.typeFilter.value,
          'sort': state.sort.value,
          'page': targetPage,
          'per_page': 20,
        }),
      );

      final data = response.data as Map<String, dynamic>;
      final fetched = (data['repos'] as List).map((r) => GitRepo.fromJson(r as Map<String, dynamic>)).toList();

      state = state.copyWith(
        repos: reset ? fetched : [...state.repos, ...fetched],
        isLoading: false,
        isLoadingMore: false,
        hasNextPage: data['hasNextPage'] as bool? ?? false,
        page: targetPage,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: e.message);
    }
  }

  void loadMore() {
    if (state.isLoadingMore || !state.hasNextPage) return;
    fetch();
  }

  void refresh() => fetch(reset: true);

  /// Debounced so fast typing doesn't fire a request per keystroke —
  /// spec section 5 asks for fast, paginated, debounced repo search.
  void setSearch(String query) {
    state = state.copyWith(search: query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => fetch(reset: true));
  }

  void setTypeFilter(RepoTypeFilter filter) {
    if (filter == state.typeFilter) return;
    state = state.copyWith(typeFilter: filter);
    fetch(reset: true);
  }

  void setSort(RepoSort sort) {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
    fetch(reset: true);
  }

  /// Deletes a repository on GitHub permanently, then removes it from the
  /// local list on success. Throws ApiException on failure (most likely
  /// cause: the GitHub App doesn't have Administration permission yet —
  /// see the comment on the backend route) so the caller can show it.
  Future<void> deleteRepo(GitRepo repo) async {
    await unwrapApi(() => _api.raw.delete('/api/repos/${repo.owner}/${repo.name}'));
    state = state.copyWith(repos: state.repos.where((r) => r.id != repo.id).toList());
  }

  /// Flips a repo's visibility, then updates it in place in the local list.
  Future<void> setVisibility(GitRepo repo, {required bool isPrivate}) async {
    await unwrapApi(
      () => _api.raw.patch('/api/repos/${repo.owner}/${repo.name}', data: {'isPrivate': isPrivate}),
    );
    state = state.copyWith(
      repos: [
        for (final r in state.repos)
          if (r.id == repo.id) _withVisibility(r, isPrivate) else r,
      ],
    );
  }

  GitRepo _withVisibility(GitRepo repo, bool isPrivate) => GitRepo(
        id: repo.id,
        name: repo.name,
        fullName: repo.fullName,
        owner: repo.owner,
        ownerAvatarUrl: repo.ownerAvatarUrl,
        description: repo.description,
        isPrivate: isPrivate,
        defaultBranch: repo.defaultBranch,
        language: repo.language,
        stargazersCount: repo.stargazersCount,
        updatedAt: repo.updatedAt,
        htmlUrl: repo.htmlUrl,
      );
}
