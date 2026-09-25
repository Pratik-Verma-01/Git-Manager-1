class TreeEntry {
  const TreeEntry({required this.name, required this.path, required this.type, this.size, this.sha});

  final String name;
  final String path;
  final String type; // file | dir | symlink | submodule
  final int? size;
  final String? sha;

  bool get isDirectory => type == 'dir';

  factory TreeEntry.fromJson(Map<String, dynamic> json) => TreeEntry(
        name: json['name'] as String,
        path: json['path'] as String,
        type: json['type'] as String,
        size: json['size'] as int?,
        sha: json['sha'] as String?,
      );
}
