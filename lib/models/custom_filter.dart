import 'task.dart';

class CustomFilter {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final String? color;
  final FilterCriteria criteria;

  CustomFilter({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    this.color,
    required this.criteria,
  });

  factory CustomFilter.fromJson(Map<String, dynamic> json) {
    return CustomFilter(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      icon: json['icon'],
      color: json['color'],
      criteria: FilterCriteria.fromJson(json['criteria'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'criteria': criteria.toJson(),
    };
  }

  // LOGIC: Check if a task matches this filter
  bool matches(Task task) {
    // 1. Check Completed
    if (criteria.isCompleted != null) {
      if (task.isCompleted != criteria.isCompleted) return false;
    }

    // 2. Check Priority
    if (criteria.priorities.isNotEmpty) {
      if (!criteria.priorities.contains(task.priority)) return false;
    }

    // 3. Check Lists
    if (criteria.listIds.isNotEmpty) {
      if (task.listId == null || !criteria.listIds.contains(task.listId)) {
        // Handle "No List" case if we want to filter for Inbox explicitly, logic can vary
        return false;
      }
    }

    // 4. Check Tags
    if (criteria.tagIds.isNotEmpty) {
      // If task has NO tags, but filter requires tags -> false
      // If filter requires ANY of the tags
      bool hasMatch = false;
      for (var id in criteria.tagIds) {
        if (task.tagIds.contains(id)) {
          hasMatch = true;
          break;
        }
      }
      if (!hasMatch) return false;
    }

    // 5. Check Date Range
    if (criteria.dateRange != null) {
      if (task.dueDate == null && criteria.dateRange != 'no_date') return false;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = task.dueDate != null 
          ? DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day) 
          : null;

      switch (criteria.dateRange) {
        case 'today':
          if (taskDate != today) return false;
          break;
        case 'tomorrow':
          if (taskDate != today.add(const Duration(days: 1))) return false;
          break;
        case 'week':
          final nextWeek = today.add(const Duration(days: 7));
          if (taskDate == null || taskDate.isBefore(today) || taskDate.isAfter(nextWeek)) return false;
          break;
        case 'overdue':
          if (taskDate == null || !taskDate.isBefore(today)) return false;
          break;
        case 'no_date':
          if (taskDate != null) return false;
          break;
      }
    }

    return true;
  }
}

class FilterCriteria {
  final List<int> priorities; // [3, 2]
  final List<String> listIds;
  final List<String> tagIds;
  final String? dateRange; // 'today', 'week', 'overdue', 'no_date'
  final bool? isCompleted; // null = all, true = completed, false = active

  FilterCriteria({
    this.priorities = const [],
    this.listIds = const [],
    this.tagIds = const [],
    this.dateRange,
    this.isCompleted = false, // Default to active tasks usually
  });

  factory FilterCriteria.fromJson(Map<String, dynamic> json) {
    return FilterCriteria(
      priorities: (json['priorities'] as List?)?.map((e) => e as int).toList() ?? [],
      listIds: (json['list_ids'] as List?)?.map((e) => e as String).toList() ?? [],
      tagIds: (json['tag_ids'] as List?)?.map((e) => e as String).toList() ?? [],
      dateRange: json['date_range'],
      isCompleted: json['is_completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'priorities': priorities,
      'list_ids': listIds,
      'tag_ids': tagIds,
      'date_range': dateRange,
      'is_completed': isCompleted,
    };
  }
}
