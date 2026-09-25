/// A lightweight "time ago" formatter so we don't pull in a whole package
/// for one string. Good enough granularity for repo/commit lists; not
/// intended for anything needing second-level precision.
String timeAgo(DateTime date) {
  final diff = DateTime.now().toUtc().difference(date.toUtc());

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
