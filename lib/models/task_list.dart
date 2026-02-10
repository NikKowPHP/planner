class TaskList {
  final String id;
  final String userId;
  final String name;
  final String? color;
  final String? icon;

  TaskList({
    required this.id,
    required this.userId,
    required this.name,
    this.color,
    this.icon,
  });

  factory TaskList.fromJson(Map<String, dynamic> json) {
    return TaskList(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      color: json['color'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'color': color,
      'icon': icon,
    };
  }
}
