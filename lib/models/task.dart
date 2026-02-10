class Task {
  final String id;
  final String userId;
  final String? listId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final int priority;

  Task({
    required this.id,
    required this.userId,
    this.listId,
    required this.title,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.priority = 0,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      userId: json['user_id'],
      listId: json['list_id'],
      title: json['title'],
      description: json['description'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      isCompleted: json['is_completed'] ?? false,
      priority: json['priority'] ?? 0,
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
    };
  }
}
