class PageModel {
  final String id;
  final String userId;
  final String? parentId;
  final String title;
  final String content;
  final String? icon;
  final bool isExpanded;
  final DateTime updatedAt;

  PageModel({
    required this.id,
    required this.userId,
    this.parentId,
    required this.title,
    this.content = '',
    this.icon,
    this.isExpanded = false,
    required this.updatedAt,
  });

  factory PageModel.fromJson(Map<String, dynamic> json) {
    return PageModel(
      id: json['id'],
      userId: json['user_id'],
      parentId: json['parent_id'],
      title: json['title'] ?? 'Untitled',
      content: json['content'] ?? '',
      icon: json['icon'],
      isExpanded: json['is_expanded'] ?? false,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'parent_id': parentId,
      'title': title,
      'content': content,
      'icon': icon,
      'is_expanded': isExpanded,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
