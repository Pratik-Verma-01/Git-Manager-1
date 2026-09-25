class GitRepo {
  const GitRepo({
    required this.id,
    required this.name,
    required this.fullName,
    required this.owner,
    this.ownerAvatarUrl,
    this.description,
    required this.isPrivate,
    required this.defaultBranch,
    this.language,
    required this.stargazersCount,
    required this.updatedAt,
    required this.htmlUrl,
  });

  final int id;
  final String name;
  final String fullName;
  final String owner;
  final String? ownerAvatarUrl;
  final String? description;
  final bool isPrivate;
  final String defaultBranch;
  final String? language;
  final int stargazersCount;
  final DateTime updatedAt;
  final String htmlUrl;

  factory GitRepo.fromJson(Map<String, dynamic> json) => GitRepo(
        id: json['id'] as int,
        name: json['name'] as String,
        fullName: json['fullName'] as String,
        owner: json['owner'] as String,
        ownerAvatarUrl: json['ownerAvatarUrl'] as String?,
        description: json['description'] as String?,
        isPrivate: json['isPrivate'] as bool,
        defaultBranch: json['defaultBranch'] as String,
        language: json['language'] as String?,
        stargazersCount: json['stargazersCount'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        htmlUrl: json['htmlUrl'] as String,
      );
}

enum RepoTypeFilter { all, public, private }

enum RepoSort { updated, created, pushed, fullName }

extension RepoSortApi on RepoSort {
  String get value => switch (this) {
        RepoSort.updated => 'updated',
        RepoSort.created => 'created',
        RepoSort.pushed => 'pushed',
        RepoSort.fullName => 'full_name',
      };
}

extension RepoTypeFilterApi on RepoTypeFilter {
  String get value => switch (this) {
        RepoTypeFilter.all => 'all',
        RepoTypeFilter.public => 'public',
        RepoTypeFilter.private => 'private',
      };
}
