class FocusSession {
  final String id;
  final String userId;
  final String? taskId;
  final String? habitId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  FocusSession({
    required this.id,
    required this.userId,
    this.taskId,
    this.habitId,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'],
      userId: json['user_id'],
      taskId: json['task_id'],
      habitId: json['habit_id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      durationSeconds: json['duration_seconds'],
    );
  }
}
