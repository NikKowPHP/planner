class Habit {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final String? color;
  final int goalValue;
  final DateTime createdAt;
  final DateTime? deletedAt;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    this.color,
    this.goalValue = 1,
    required this.createdAt,
    this.deletedAt,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      icon: json['icon'],
      color: json['color'],
      goalValue: json['goal_value'] ?? 1,
      createdAt: DateTime.parse(json['created_at']),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
    );
  }
}

class HabitLog {
  final String id;
  final String habitId;
  final DateTime completedAt;
  final int value;

  HabitLog({
    required this.id,
    required this.habitId,
    required this.completedAt,
    required this.value,
  });

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'],
      habitId: json['habit_id'],
      completedAt: DateTime.parse(json['completed_at'] + 'T00:00:00Z'), // Add time for parsing if it's just a date
      value: json['value'] ?? 1,
    );
  }
}
