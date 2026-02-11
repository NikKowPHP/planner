import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../services/todo_service.dart';
import '../services/auth_service.dart';
import '../services/logger.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../models/focus_session.dart';
import '../services/focus_service.dart';
import '../services/notification_service.dart';

// --- Services ---

final loggerProvider = Provider((ref) => FileLogger());
final todoServiceProvider = Provider((ref) => TodoService());
final authServiceProvider = Provider((ref) => AuthService());

// --- Auth State ---

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges.map((event) => event.session?.user);
});

final userProfileProvider = FutureProvider((ref) async {
  final authState = ref.watch(authUserProvider);
  return authState.when(
    data: (user) {
      if (user == null) return null;
      return ref.read(authServiceProvider).getCurrentProfile();
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// --- Data Notifiers (CRUD) ---

// 1. Tasks
class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    final tasks = await ref.read(todoServiceProvider).getTasks();
    
    // NEW: Automatically sync all reminders on app launch/refresh
    _syncAllReminders(tasks);
    
    return tasks;
  }

  Future<void> _syncAllReminders(List<Task> tasks) async {
    final notifier = NotificationService();
    for (final task in tasks) {
      if (task.dueDate != null && !task.isCompleted && task.deletedAt == null) {
        await notifier.scheduleTaskReminder(task);
      } else {
        await notifier.cancelTaskReminder(task.id);
      }
    }
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
      
      // NEW: Schedule notification if due date exists
      if (newTask.dueDate != null) {
        await NotificationService().scheduleTaskReminder(newTask);
      }
    } catch (e, s) {
      await logger.error('TasksProvider: Create failed', e, s);
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    final logger = ref.read(loggerProvider);
    await logger.log(
      'CRUD: Starting update for Task(id: ${task.id}, title: ${task.title})',
    );
    try {
      // Optimistic update
      final current = state.value ?? [];
      final index = current.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updatedList = List<Task>.from(current);
        updatedList[index] = task;
        state = AsyncData(updatedList);
      }
      
      await ref.read(todoServiceProvider).updateTask(task);
      await logger.log(
        'CRUD: Successfully updated Task ${task.id} in database',
      );
      
      // NEW: Update Scheduling logic
      if (task.isCompleted || task.deletedAt != null) {
        await NotificationService().cancelTaskReminder(task.id);
      } else if (task.dueDate != null) {
        // Rescheduling will overwrite the previous one because we use the same ID
        await NotificationService().scheduleTaskReminder(task);
      } else {
        await NotificationService().cancelTaskReminder(task.id);
      }
    } catch (e, s) {
      await logger.error('CRUD: Failed to update Task ${task.id}', e, s);
      ref.invalidateSelf(); // Rollback state on failure
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

       // NEW: Cancel notification when task is deleted
       await NotificationService().cancelTaskReminder(task.id);
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
enum AppTab { tasks, calendar, focus, habit }

class HomeViewState {
  final AppTab activeTab;
  final int selectedIndex;
  final GroupBy groupBy;
  final SortBy sortBy;
  final bool hideCompleted;
  final Task? selectedTask;
  final Habit? selectedHabit;
  final bool isSidebarVisible;
  final bool isSearchVisible;
  final String searchQuery;

  HomeViewState({
    this.activeTab = AppTab.tasks,
    this.selectedIndex = 0,
    this.groupBy = GroupBy.date,
    this.sortBy = SortBy.date,
    this.hideCompleted = false,
    this.selectedTask,
    this.selectedHabit,
    this.isSidebarVisible = true,
    this.isSearchVisible = false,
    this.searchQuery = '',
  });

  HomeViewState copyWith({
    AppTab? activeTab,
    int? selectedIndex,
    GroupBy? groupBy,
    SortBy? sortBy,
    bool? hideCompleted,
    Task? selectedTask,
    Habit? selectedHabit,
    bool nullSelectedTask = false,
    bool nullSelectedHabit = false,
    bool? isSidebarVisible,
    bool? isSearchVisible,
    String? searchQuery,
  }) {
    return HomeViewState(
      activeTab: activeTab ?? this.activeTab,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      groupBy: groupBy ?? this.groupBy,
      sortBy: sortBy ?? this.sortBy,
      hideCompleted: hideCompleted ?? this.hideCompleted,
      selectedTask: nullSelectedTask ? null : (selectedTask ?? this.selectedTask),
      selectedHabit: nullSelectedHabit ? null : (selectedHabit ?? this.selectedHabit),
      isSidebarVisible: isSidebarVisible ?? this.isSidebarVisible,
      isSearchVisible: isSearchVisible ?? this.isSearchVisible,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HomeViewNotifier extends Notifier<HomeViewState> {
  @override
  HomeViewState build() => HomeViewState();

  void setActiveTab(AppTab tab) {
    ref.read(loggerProvider).log('GESTURE: Navigation Rail/Bar switched to $tab');
    state = state.copyWith(activeTab: tab);
  }

  void setIndex(int index) {
    ref.read(loggerProvider).log('GESTURE: Sidebar item selected at index $index');
    state = state.copyWith(selectedIndex: index);
  }
  void setGroupBy(GroupBy group) => state = state.copyWith(groupBy: group);
  void setSortBy(SortBy sort) => state = state.copyWith(sortBy: sort);
  void toggleHideCompleted() => state = state.copyWith(hideCompleted: !state.hideCompleted);
  void selectTask(Task? task) {
    ref.read(loggerProvider).log('GESTURE: Task ${task?.id ?? "none"} selected for detail view');
    state = state.copyWith(selectedTask: task, nullSelectedTask: task == null);
  }
  void selectHabit(Habit? habit) => state = state.copyWith(selectedHabit: habit, nullSelectedHabit: habit == null);
  void toggleSidebar() => state = state.copyWith(isSidebarVisible: !state.isSidebarVisible);
  void toggleSearch() {
    final bool currentlyVisible = state.isSearchVisible;
    ref.read(loggerProvider).log('ACTION: Fuzzy Search triggered. Visible: ${!currentlyVisible}');
    
    state = state.copyWith(
      isSearchVisible: !currentlyVisible,
      searchQuery: '',
      // Ensure detail panels are closed if search opens
      nullSelectedTask: !currentlyVisible,
    );
  }
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  // Navigation helper for search results
  void navigateToItem(dynamic item) {
    final name = item is Task ? item.title : (item is Habit ? item.name : (item is TaskList ? item.name : "Unknown"));
    ref.read(loggerProvider).log('GESTURE: Search result clicked -> Navigating to $name');
    state = state.copyWith(isSearchVisible: false, searchQuery: '');

    if (item is Task) {
      state = state.copyWith(activeTab: AppTab.tasks, selectedTask: item);
    } else if (item is Habit) {
      state = state.copyWith(activeTab: AppTab.habit, selectedHabit: item);
    } else if (item is TaskList) {
      // Logic to find the list index in sidebar
      final lists = ref.read(listsProvider).value ?? [];
      final filters = ref.read(filtersProvider).value ?? [];
      final index = lists.indexWhere((l) => l.id == item.id);
      if (index != -1) {
        state = state.copyWith(
          activeTab: AppTab.tasks,
          selectedIndex: 4 + filters.length + index,
        );
      }
    }
  }
}

final homeViewProvider = NotifierProvider<HomeViewNotifier, HomeViewState>(HomeViewNotifier.new);

// --- Derived State (Selects/Filters) ---

final currentTitleProvider = Provider<String>((ref) {
  final view = ref.watch(homeViewProvider);
  final activeTab = view.activeTab;
  final idx = view.selectedIndex;
  final filters = ref.watch(filtersProvider).asData?.value ?? [];
  final lists = ref.watch(listsProvider).asData?.value ?? [];
  final tags = ref.watch(tagsProvider).asData?.value ?? [];

  if (activeTab == AppTab.focus) return 'Focus';
  if (activeTab == AppTab.calendar) return 'Calendar';
  if (activeTab == AppTab.habit) return 'Habit';

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

// --- Calendar State ---

final calendarTasksProvider = Provider<Map<DateTime, List<Task>>>((ref) {
  final tasks = ref.watch(tasksProvider).asData?.value ?? [];

  final Map<DateTime, List<Task>> grouped = {};

  for (var task in tasks) {
    // Skip deleted or tasks without dates
    if (task.deletedAt != null || task.dueDate == null) continue;

    // Normalize date to midnight for the key
    final date = task.dueDate!;
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (grouped[normalizedDate] == null) {
      grouped[normalizedDate] = [];
    }
    grouped[normalizedDate]!.add(task);
  }
  return grouped;
});

// --- Habit Providers ---
final habitServiceProvider = Provider((ref) => HabitService());

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<Habit>>(
  HabitsNotifier.new,
);

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() async {
    return ref.read(habitServiceProvider).getHabits();
  }

  Future<void> createHabit(String name, {String? icon, String? color}) async {
    final logger = ref.read(loggerProvider);
    await logger.log('CRUD: Attempting to create Habit: $name');
    try {
      final newHabit = await ref
          .read(habitServiceProvider)
          .createHabit(name, icon: icon, color: color);
      state = AsyncData([...state.value ?? [], newHabit]);
      await logger.log('CRUD: Successfully created Habit ${newHabit.id}');
      
      // Show notification
      await NotificationService().showNotification(
        title: "New Habit Added",
        body: "Time to start building: $name",
      );
    } catch (e, s) {
      await logger.error('CRUD: Habit creation failed for $name', e, s);
      rethrow;
    }
  }

  Future<void> deleteHabit(String id) async {
    await ref.read(habitServiceProvider).deleteHabit(id);
    state = AsyncData((state.value ?? []).where((h) => h.id != id).toList());
  }

  Future<void> updateHabit(
    String id, {
    String? name,
    String? icon,
    String? color,
    int? goalValue,
  }) async {
    final updated = await ref
        .read(habitServiceProvider)
        .updateHabit(
          id,
          name: name,
          icon: icon,
          color: color,
          goalValue: goalValue,
        );
    final current = state.value ?? [];
    state = AsyncData(current.map((h) => h.id == id ? updated : h).toList());
  }
}

// Fetches logs and groups them by Habit ID
final habitLogsProvider = FutureProvider<Map<String, List<DateTime>>>(
  (ref) async {
    final habits = ref.watch(habitsProvider).asData?.value ?? [];
    if (habits.isEmpty) return {};

    final logs = await ref
        .read(habitServiceProvider)
        .getLogs(habits.map((h) => h.id).toList());

    final Map<String, List<DateTime>> grouped = {};
    for (var log in logs) {
      if (grouped[log.habitId] == null) grouped[log.habitId] = [];
      // Normalize to midnight
      final d = DateTime(
        log.completedAt.year,
        log.completedAt.month,
        log.completedAt.day,
      );
      grouped[log.habitId]!.add(d);
    }
    return grouped;
  },
);

// Helper to toggle locally and remotely
final habitToggleProvider = Provider((ref) {
  return (String habitId, DateTime date) async {
    await ref.read(habitServiceProvider).toggleHabitForDate(habitId, date);
    
    // Find habit name for notification
    final habit = ref.read(habitsProvider).value?.firstWhere((h) => h.id == habitId);
    if (habit != null) {
      await NotificationService().showNotification(
        title: "Habit Logged",
        body: "You checked in for: ${habit.name}",
      );
    }
    
    ref.invalidate(habitLogsProvider); // Refresh logs
  };
});

// --- Focus Providers ---

final focusServiceProvider = Provider((ref) => FocusService());

final focusHistoryProvider = FutureProvider<List<FocusSession>>((ref) async {
  return ref.read(focusServiceProvider).getHistory();
});

// Helper to refresh history after saving
final focusSessionSaverProvider = Provider((ref) {
  return ({required DateTime startTime, required int duration, String? taskId, String? habitId}) async {
    try {
      await ref.read(focusServiceProvider).saveSession(
        startTime: startTime,
        durationSeconds: duration,
        taskId: taskId,
        habitId: habitId,
      );
      ref.invalidate(focusHistoryProvider);
    } catch (e, s) {
      await ref.read(loggerProvider).error('focusSessionSaverProvider: Save failed', e, s);
      rethrow;
    }
  };
});

// --- Search Provider ---

final searchResultsProvider = Provider<Map<String, List<dynamic>>>((ref) {
  final query = ref.watch(homeViewProvider.select((s) => s.searchQuery)).toLowerCase();
  if (query.isEmpty) return {};

  final tasks = ref.watch(tasksProvider).value ?? [];
  final habits = ref.watch(habitsProvider).value ?? [];
  final lists = ref.watch(listsProvider).value ?? [];
  final tags = ref.watch(tagsProvider).value ?? [];

  bool matches(String text) => text.toLowerCase().contains(query);

  return {
    'Tasks': tasks.where((t) => matches(t.title) || (t.description ?? '').toLowerCase().contains(query)).toList(),
    'Habits': habits.where((h) => matches(h.name)).toList(),
    'Lists': lists.where((l) => matches(l.name)).toList(),
    'Tags': tags.where((tag) => matches(tag.name)).toList(),
  }..removeWhere((key, value) => value.isEmpty);
});
