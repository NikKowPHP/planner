class Task {
  final String id;
  final String userId;
  final String? listId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final int priority;
  // NEW FIELDS
  final DateTime? deletedAt;
  final List<String> tagIds;

  Task({
    required this.id,
    required this.userId,
    this.listId,
    required this.title,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.priority = 0,
    this.deletedAt,
    this.tagIds = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Extract tags from junction table relation if present
    List<String> tags = [];
    if (json['task_tags'] != null) {
      tags = (json['task_tags'] as List)
          .map((t) => t['tag_id'] as String)
          .toList();
    }

    return Task(
      id: json['id'],
      userId: json['user_id'],
      listId: json['list_id'],
      title: json['title'],
      description: json['description'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      isCompleted: json['is_completed'] ?? false,
      priority: json['priority'] ?? 0,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      tagIds: tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'list_id': listId,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted,
      'priority': priority,
      'deleted_at': deletedAt?.toIso8601String(),
      // Note: tagIds are usually handled via separate inserts in Supabase,
      // not directly in the tasks table insert.
    };
  }
}
