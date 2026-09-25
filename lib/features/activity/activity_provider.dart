import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.repoFullName,
    required this.summary,
    required this.createdAt,
    required this.htmlUrl,
  });

  final String id;
  final String type;
  final String repoFullName;
  final String summary;
  final DateTime? createdAt;
  final String htmlUrl;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id'] as String,
        type: json['type'] as String,
        repoFullName: json['repoFullName'] as String,
        summary: json['summary'] as String,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
        htmlUrl: json['htmlUrl'] as String,
      );
}

class ActivityState {
  const ActivityState({this.items = const [], this.isLoading = false, this.error});
  final List<ActivityItem> items;
  final bool isLoading;
  final String? error;

  bool get isEmpty => !isLoading && items.isEmpty;

  ActivityState copyWith({List<ActivityItem>? items, bool? isLoading, String? error, bool clearError = false}) {
    return ActivityState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final activityControllerProvider = NotifierProvider<ActivityController, ActivityState>(ActivityController.new);

class ActivityController extends Notifier<ActivityState> {
  @override
  ActivityState build() {
    Future.microtask(fetch);
    return const ActivityState(isLoading: true);
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await unwrapApi(() => _api.raw.get('/api/activity', queryParameters: {'per_page': 30}));
      final data = response.data as Map<String, dynamic>;
      final items = (data['activities'] as List).map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(items: items, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }
}
