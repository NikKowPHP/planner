import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../services/todo_service.dart';
import '../services/auth_service.dart';
import '../services/logger.dart';

// --- Services ---

final loggerProvider = Provider((ref) => FileLogger());
final todoServiceProvider = Provider((ref) => TodoService());
final authServiceProvider = Provider((ref) => AuthService());

// --- Auth State ---

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges.map((event) => event.session?.user);
});

// --- Data Notifiers (CRUD) ---

// 1. Tasks
class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    return ref.read(todoServiceProvider).getTasks();
  }

  Future<void> createTask(String title, {String? listId, DateTime? dueDate}) async {
    final logger = ref.read(loggerProvider);
    await logger.log('TasksProvider: Creating task "$title"');
    try {
      final newTask = await ref.read(todoServiceProvider).createTask(
        title: title, listId: listId, dueDate: dueDate
      );
      // Optimistic update
      final current = state.value ?? [];
      state = AsyncData([newTask, ...current]);
      await logger.log('TasksProvider: Created task ${newTask.id}');
    } catch (e, s) {
      await logger.error('TasksProvider: Create failed', e, s);
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    final logger = ref.read(loggerProvider);
    try {
      // Optimistic
      final current = state.value ?? [];
      final index = current.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updatedList = List<Task>.from(current);
        updatedList[index] = task;
        state = AsyncData(updatedList);
      }
      
      await ref.read(todoServiceProvider).updateTask(task);
      await logger.log('TasksProvider: Updated task ${task.id}');
    } catch (e, s) {
      await logger.error('TasksProvider: Update failed', e, s);
      // Revert logic could go here
      rethrow;
    }
  }

  Future<void> deleteTask(Task task) async {
    final logger = ref.read(loggerProvider);
    try {
       final current = state.value ?? [];
       // Soft delete locally
       final updatedList = current.map((t) {
         if (t.id == task.id) {
           return Task(
             id: t.id, userId: t.userId, title: t.title, description: t.description,
             listId: t.listId, priority: t.priority, isCompleted: t.isCompleted,
             dueDate: t.dueDate, tagIds: t.tagIds, isPinned: t.isPinned,
             deletedAt: DateTime.now()
           );
         }
         return t;
       }).toList();
       state = AsyncData(updatedList);

       await ref.read(todoServiceProvider).deleteTask(task.id);
       await logger.log('TasksProvider: Deleted task ${task.id}');
    } catch (e, s) {
       await logger.error('TasksProvider: Delete failed', e, s);
       rethrow;
    }
  }
}

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

// 2. Lists
final listsProvider = FutureProvider((ref) => ref.read(todoServiceProvider).getLists());

// 3. Tags
final tagsProvider = FutureProvider((ref) => ref.read(todoServiceProvider).getTags());

// 4. Filters
final filtersProvider = FutureProvider((ref) => ref.read(todoServiceProvider).getFilters());

// --- UI State (View Model) ---

enum GroupBy { date, priority, list, none }
enum SortBy { date, priority, title }

class HomeViewState {
  final int selectedIndex;
  final GroupBy groupBy;
  final SortBy sortBy;
  final bool hideCompleted;
  final Task? selectedTask;

  HomeViewState({
    this.selectedIndex = 0,
    this.groupBy = GroupBy.date,
    this.sortBy = SortBy.date,
    this.hideCompleted = false,
    this.selectedTask,
  });

  HomeViewState copyWith({
    int? selectedIndex,
    GroupBy? groupBy,
    SortBy? sortBy,
    bool? hideCompleted,
    Task? selectedTask,
    bool nullSelectedTask = false,
  }) {
    return HomeViewState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      groupBy: groupBy ?? this.groupBy,
      sortBy: sortBy ?? this.sortBy,
      hideCompleted: hideCompleted ?? this.hideCompleted,
      selectedTask: nullSelectedTask ? null : (selectedTask ?? this.selectedTask),
    );
  }
}

class HomeViewNotifier extends Notifier<HomeViewState> {
  @override
  HomeViewState build() => HomeViewState();

  void setIndex(int index) => state = state.copyWith(selectedIndex: index);
  void setGroupBy(GroupBy group) => state = state.copyWith(groupBy: group);
  void setSortBy(SortBy sort) => state = state.copyWith(sortBy: sort);
  void toggleHideCompleted() => state = state.copyWith(hideCompleted: !state.hideCompleted);
  void selectTask(Task? task) => state = state.copyWith(selectedTask: task, nullSelectedTask: task == null);
}

final homeViewProvider = NotifierProvider<HomeViewNotifier, HomeViewState>(HomeViewNotifier.new);

// --- Derived State (Selects/Filters) ---

final currentTitleProvider = Provider<String>((ref) {
  final idx = ref.watch(homeViewProvider.select((s) => s.selectedIndex));
  final filters = ref.watch(filtersProvider).asData?.value ?? [];
  final lists = ref.watch(listsProvider).asData?.value ?? [];
  final tags = ref.watch(tagsProvider).asData?.value ?? [];

  if (idx == -1) return 'Completed';
  if (idx == -2) return 'Trash';

  if (idx >= 0 && idx < 4) {
    return ['All', 'Today', 'Next 7 Days', 'Inbox'][idx];
  }
  
  final filterStart = 4;
  final listStart = filterStart + filters.length;
  final tagStart = listStart + lists.length;

  if (idx >= filterStart && idx < listStart) return filters[idx - filterStart].name;
  if (idx >= listStart && idx < tagStart) return lists[idx - listStart].name;
  if (idx >= tagStart && (idx - tagStart) < tags.length) return '# ${tags[idx - tagStart].name}';

  return 'Glassy';
});

final filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider).asData?.value ?? [];
  final view = ref.watch(homeViewProvider);
  final filters = ref.watch(filtersProvider).asData?.value ?? [];
  final lists = ref.watch(listsProvider).asData?.value ?? [];
  final tags = ref.watch(tagsProvider).asData?.value ?? [];

  var result = tasks.where((t) => t.deletedAt == null).toList();
  
  // Special Views
  if (view.selectedIndex == -2) return tasks.where((t) => t.deletedAt != null).toList(); // Trash
  if (view.selectedIndex == -1) return result.where((t) => t.isCompleted).toList(); // Completed

  // Filter Logic
  if (view.selectedIndex < 4) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (view.selectedIndex) {
      case 1: // Today
        result = result.where((t) => t.dueDate != null && 
          DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) == today).toList();
        break;
      case 2: // Next 7 Days
        final nextWeek = today.add(const Duration(days: 7));
        result = result.where((t) {
          if (t.dueDate == null) return false;
          final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          return !d.isBefore(today) && d.isBefore(nextWeek);
        }).toList();
        break;
      case 3: // Inbox
        result = result.where((t) => t.listId == null).toList();
        break;
    }
  } else {
    final filterStart = 4;
    final listStart = filterStart + filters.length;
    final tagStart = listStart + lists.length;

    if (view.selectedIndex >= filterStart && view.selectedIndex < listStart) {
      result = result.where((t) => filters[view.selectedIndex - filterStart].matches(t)).toList();
    } else if (view.selectedIndex >= listStart && view.selectedIndex < tagStart) {
      result = result.where((t) => t.listId == lists[view.selectedIndex - listStart].id).toList();
    } else if (view.selectedIndex >= tagStart) {
      final tagId = tags[view.selectedIndex - tagStart].id;
      result = result.where((t) => t.tagIds.contains(tagId)).toList();
    }
  }

  if (view.hideCompleted) {
    result = result.where((t) => !t.isCompleted).toList();
  }

  // Sort
  result.sort((a, b) {
    switch (view.sortBy) {
      case SortBy.title: return a.title.compareTo(b.title);
      case SortBy.priority: return b.priority.compareTo(a.priority);
      case SortBy.date: 
         if (a.dueDate == null) return 1; if (b.dueDate == null) return -1;
         return a.dueDate!.compareTo(b.dueDate!);
    }
  });

  return result;
});

final groupedTasksProvider = Provider<Map<String, List<Task>>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  final groupBy = ref.watch(homeViewProvider.select((s) => s.groupBy));
  final hideCompleted = ref.watch(homeViewProvider.select((s) => s.hideCompleted));
  final lists = ref.watch(listsProvider).asData?.value ?? [];

  Map<String, List<Task>> groups = {};

  if (groupBy == GroupBy.date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    for (var t in tasks) {
      if (t.isCompleted && !hideCompleted) {
        (groups['Completed'] ??= []).add(t);
        continue;
      }
      if (t.dueDate == null) {
        (groups['No Date'] ??= []).add(t);
        continue;
      }
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);

      if (d.isBefore(today)) {
        (groups['Overdue'] ??= []).add(t);
      } else if (d == today) {
        (groups['Today'] ??= []).add(t);
      } else if (d == tomorrow) {
        (groups['Tomorrow'] ??= []).add(t);
      } else if (d.isBefore(nextWeek)) {
        (groups['Next 7 Days'] ??= []).add(t);
      } else {
        (groups['Later'] ??= []).add(t);
      }
    }

    // Return structured map to enforce order
    final ordered = <String, List<Task>>{};
    for (final k in ['Overdue', 'Today', 'Tomorrow', 'Next 7 Days', 'Later', 'No Date', 'Completed']) {
      if (groups.containsKey(k)) {
        ordered[k] = groups[k]!;
      }
    }
    return ordered;
  }
  
  if (groupBy == GroupBy.priority) {
     for (var t in tasks) {
       if (t.isCompleted && !hideCompleted) { (groups['Completed'] ??= []).add(t); continue; }
       String k = ['None', 'Low', 'Medium', 'High'][t.priority];
       (groups[k] ??= []).add(t);
     }
     final ordered = <String, List<Task>>{};
     for (final k in ['High', 'Medium', 'Low', 'None', 'Completed']) {
        if (groups.containsKey(k)) {
          ordered[k] = groups[k]!;
        }
     }
     return ordered;
  }

  if (groupBy == GroupBy.list) {
     for (var t in tasks) {
        if (t.isCompleted && !hideCompleted) { (groups['Completed'] ??= []).add(t); continue; }
        String name = 'Inbox';
        if (t.listId != null) {
           try { name = lists.firstWhere((l) => l.id == t.listId).name; } catch (_) {}
        }
        (groups[name] ??= []).add(t);
     }
     return groups;
  }

  return {'Tasks': tasks};
});
