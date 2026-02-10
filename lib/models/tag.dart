class Tag {
  final String id;
  final String userId;
  final String name;
  final String? color;

  Tag({
    required this.id,
    required this.userId,
    required this.name,
    this.color,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'color': color,
    };
  }
}
