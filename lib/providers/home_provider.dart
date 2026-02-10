import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/tag.dart';
import '../models/custom_filter.dart';
import '../services/todo_service.dart';
import '../services/logger.dart';

enum GroupBy { date, priority, list, none }
enum SortBy { date, priority, title }

class HomeProvider extends ChangeNotifier {
  final TodoService _todoService = TodoService();
  final FileLogger _logger = FileLogger();

  // Data State
  List<Task> _tasks = [];
  List<TaskList> _lists = [];
  List<Tag> _tags = [];
  List<CustomFilter> _filters = [];
  bool _isLoading = true;

  // View State
  int _selectedIndex = 0;
  GroupBy _groupBy = GroupBy.date;
  SortBy _sortBy = SortBy.date;
  bool _hideCompleted = false;
  Task? _selectedTask;

  // Getters
  List<Task> get tasks => _tasks;
  List<TaskList> get lists => _lists;
  List<Tag> get tags => _tags;
  List<CustomFilter> get filters => _filters;
  bool get isLoading => _isLoading;
  int get selectedIndex => _selectedIndex;
  GroupBy get groupBy => _groupBy;
  SortBy get sortBy => _sortBy;
  bool get hideCompleted => _hideCompleted;
  Task? get selectedTask => _selectedTask;

  // Initial Load
  Future<void> loadData() async {
    await _logger.log('HomeProvider: loadData started');
    _isLoading = true;
    notifyListeners();
    try {
      _tasks = await _todoService.getTasks();
      _lists = await _todoService.getLists();
      _tags = await _todoService.getTags();
      _filters = await _todoService.getFilters();
      await _logger.log(
        'HomeProvider: loadData completed. Tasks: ${_tasks.length}, Lists: ${_lists.length}',
      );
    } catch (e, stack) {
      await _logger.error('HomeProvider: loadData failed', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // View Actions
  Future<void> setSelectedIndex(int index) async {
    await _logger.log('HomeProvider: Changing selected index to $index');
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> setGroupBy(GroupBy group) async {
    await _logger.log('HomeProvider: Changing GroupBy to $group');
    _groupBy = group;
    notifyListeners();
  }

  Future<void> setSortBy(SortBy sort) async {
    await _logger.log('HomeProvider: Changing SortBy to $sort');
    _sortBy = sort;
    notifyListeners();
  }

  Future<void> toggleHideCompleted() async {
    await _logger.log(
      'HomeProvider: Toggling hideCompleted. New value: ${!_hideCompleted}',
    );
    _hideCompleted = !_hideCompleted;
    notifyListeners();
  }

  Future<void> selectTask(Task? task) async {
    await _logger.log('HomeProvider: Selecting task ${task?.id ?? "None"}');
    _selectedTask = task;
    notifyListeners();
  }

  // Computed Properties (Moved from HomePage)
  String get currentTitle {
    if (_selectedIndex == -1) return 'Completed';
    if (_selectedIndex == -2) return 'Trash';

    final filterStartIndex = 4;
    final listStartIndex = 4 + _filters.length;
    final tagStartIndex = listStartIndex + _lists.length;

    if (_selectedIndex >= 0 && _selectedIndex < 4) {
      switch (_selectedIndex) {
        case 0: return 'All';
        case 1: return 'Today';
        case 2: return 'Next 7 Days';
        case 3: return 'Inbox';
      }
    }
    if (_selectedIndex >= filterStartIndex && _selectedIndex < listStartIndex) {
      final idx = _selectedIndex - filterStartIndex;
      if (idx < _filters.length) return _filters[idx].name;
    }
    if (_selectedIndex >= listStartIndex && _selectedIndex < tagStartIndex) {
      final idx = _selectedIndex - listStartIndex;
      if (idx < _lists.length) return _lists[idx].name;
    }
    if (_selectedIndex >= tagStartIndex && (_selectedIndex - tagStartIndex) < _tags.length) {
      final idx = _selectedIndex - tagStartIndex;
      if (idx < _tags.length) return '# ${_tags[idx].name}';
    }
    return 'Glassy';
  }

  String get inputPlaceholder {
     if (_selectedIndex >= 0 && _selectedIndex < 4) {
        switch (_selectedIndex) {
          case 0: return '+ Add task to Inbox';
          case 1: return '+ Add task to Today';
          case 2: return '+ Add task to Next 7 Days';
          case 3: return '+ Add task to Inbox';
        }
     }
     // Check Lists
     final listStartIndex = 4 + _filters.length;
     if (_selectedIndex >= listStartIndex) {
        final listIdx = _selectedIndex - listStartIndex;
        if (listIdx >= 0 && listIdx < _lists.length) {
           return '+ Add task to ${_lists[listIdx].name}';
        }
     }
     return '+ Add a task';
  }

  List<Task> get filteredTasks {
    if (_selectedIndex == -2) return _tasks.where((t) => t.deletedAt != null).toList();
    
    final activeTasks = _tasks.where((t) => t.deletedAt == null).toList();
    if (_selectedIndex == -1) return activeTasks.where((t) => t.isCompleted).toList();

    List<Task> result = [];
    final filterStartIndex = 4;
    final listStartIndex = 4 + _filters.length;
    final tagStartIndex = listStartIndex + _lists.length;

    if (_selectedIndex >= 0 && _selectedIndex < 4) {
      final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      switch (_selectedIndex) {
        case 0: result = activeTasks; break;
        case 1: 
          result = activeTasks.where((t) => t.dueDate != null && _isSameDay(t.dueDate!, now)).toList(); 
          break;
        case 2: 
          final nextWeek = now.add(const Duration(days: 7));
          result = activeTasks.where((t) {
            if (t.dueDate == null) return false;
            final d = _stripTime(t.dueDate!);
            return !d.isBefore(now) && d.isBefore(nextWeek);
          }).toList();
          break;
        case 3: result = activeTasks.where((t) => t.listId == null).toList(); break;
      }
    } else if (_selectedIndex >= filterStartIndex && _selectedIndex < listStartIndex) {
      final idx = _selectedIndex - filterStartIndex;
      if (idx < _filters.length) {
        result = activeTasks.where((t) => _filters[idx].matches(t)).toList();
      }
    } else if (_selectedIndex >= listStartIndex && _selectedIndex < tagStartIndex) {
      final idx = _selectedIndex - listStartIndex;
      if (idx < _lists.length) {
        final listId = _lists[idx].id;
        result = activeTasks.where((t) => t.listId == listId).toList();
      }
    } else if (_selectedIndex >= tagStartIndex) {
       final tagIdx = _selectedIndex - tagStartIndex;
       if (tagIdx < _tags.length) {
         result = activeTasks.where((t) => t.tagIds.contains(_tags[tagIdx].id)).toList();
       }
    }

    if (_hideCompleted) {
      result = result.where((t) => !t.isCompleted).toList();
    }
    return result;
  }

  Map<String, List<Task>> get groupedTasks {
    final tasks = filteredTasks;
    // Apply Sort
    tasks.sort((a, b) {
      switch (_sortBy) {
        case SortBy.title: return a.title.compareTo(b.title);
        case SortBy.priority: return b.priority.compareTo(a.priority);
        case SortBy.date: 
          if (a.dueDate == null && b.dueDate == null) return 0;
           if (a.dueDate == null) return 1; 
           if (b.dueDate == null) return -1;
           return a.dueDate!.compareTo(b.dueDate!);
      }
    });

    Map<String, List<Task>> groups = {};
    
    if (_groupBy == GroupBy.date) {
       final now = _stripTime(DateTime.now());
       final tomorrow = now.add(const Duration(days: 1));
       final nextWeek = now.add(const Duration(days: 7));

       for (var t in tasks) {
        if (t.isCompleted && !_hideCompleted) {
          (groups['Completed'] ??= []).add(t);
          continue;
        }
        if (t.dueDate == null) {
          (groups['No Date'] ??= []).add(t);
          continue;
        }
         final d = _stripTime(t.dueDate!);
        if (d.isBefore(now)) {
          (groups['Overdue'] ??= []).add(t);
        } else if (d.isAtSameMomentAs(now)) {
          (groups['Today'] ??= []).add(t);
        } else if (d.isAtSameMomentAs(tomorrow)) {
          (groups['Tomorrow'] ??= []).add(t);
        } else if (d.isBefore(nextWeek)) {
          (groups['Next 7 Days'] ??= []).add(t);
        } else {
          (groups['Later'] ??= []).add(t);
        }
       }
       
      // Order keys manually
      final ordered = <String, List<Task>>{};
      for (var k in [
        'Overdue',
        'Today',
        'Tomorrow',
        'Next 7 Days',
        'Later',
        'No Date',
        'Completed',
      ]) {
        if (groups.containsKey(k)) ordered[k] = groups[k]!;
      }
      return ordered; 
    } else if (_groupBy == GroupBy.priority) {
       for (var t in tasks) {
        if (t.isCompleted && !_hideCompleted) {
          (groups['Completed'] ??= []).add(t);
          continue;
        }
         String key = 'None';
         if (t.priority == 3) key = 'High';
         if (t.priority == 2) key = 'Medium';
         if (t.priority == 1) key = 'Low';
         (groups[key] ??= []).add(t);
       }
      final ordered = <String, List<Task>>{};
      for (var k in ['High', 'Medium', 'Low', 'None', 'Completed']) {
        if (groups.containsKey(k)) ordered[k] = groups[k]!;
      }
      return ordered;
    } else if (_groupBy == GroupBy.list) {
       for (var t in tasks) {
        if (t.isCompleted && !_hideCompleted) {
          (groups['Completed'] ??= []).add(t);
          continue;
        }
          String name = 'Inbox';
          if (t.listId != null) {
            try { name = _lists.firstWhere((l) => l.id == t.listId).name; } catch(_) {}
          }
          (groups[name] ??= []).add(t);
       }
       return groups;
    }
    
    groups['Tasks'] = tasks;
    return groups;
  }

  // CRUD Operations
  Future<void> createTask(String title) async {
    await _logger.log('HomeProvider: Creating task "$title"');
    if (title.trim().isEmpty) return;
    
    String? listId;
    DateTime? dueDate;
    
    // Derive context from selected index
    if (_selectedIndex == 1 || _selectedIndex == 2) dueDate = DateTime.now();
    final listStartIndex = 4 + _filters.length;
    if (_selectedIndex >= listStartIndex && _selectedIndex < listStartIndex + _lists.length) {
      listId = _lists[_selectedIndex - listStartIndex].id;
    }

    try {
       final newTask = await _todoService.createTask(title: title, listId: listId, dueDate: dueDate);
       _tasks.insert(0, newTask);
      await _logger.log(
        'HomeProvider: Task created successfully: ${newTask.id}',
      );
       notifyListeners();
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error creating task', e, stack);
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    await _logger.log('HomeProvider: Updating task ${task.id}');
    try {
      final updated = await _todoService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updated;
        if (_selectedTask?.id == updated.id) _selectedTask = updated;
        notifyListeners();
      }
      await _logger.log('HomeProvider: Task updated successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error updating task', e, stack);
      rethrow;
    }
  }

  Future<void> deleteTask(Task task) async {
    await _logger.log('HomeProvider: Deleting task ${task.id}');
    try {
       await _todoService.deleteTask(task.id);
       final index = _tasks.indexWhere((t) => t.id == task.id);
       if (index != -1) {
          // Simulating soft delete update locally
        final deleted = Task(
             id: task.id, userId: task.userId, title: task.title, 
             isCompleted: task.isCompleted, priority: task.priority,
             deletedAt: DateTime.now(), tagIds: task.tagIds,
             listId: task.listId, dueDate: task.dueDate, isPinned: task.isPinned
          );
        _tasks[index] = deleted;
          notifyListeners();
       }
      await _logger.log('HomeProvider: Task deleted successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error deleting task', e, stack);
      rethrow;
    }
  }

  Future<void> createList(String name) async {
    await _logger.log('HomeProvider: Creating list "$name"');
    try {
      final list = await _todoService.createList(name);
      _lists.add(list);
      notifyListeners();
      await _logger.log('HomeProvider: List created successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error creating list', e, stack);
      rethrow;
    }
  }

  Future<void> createTag(String name) async {
    await _logger.log('HomeProvider: Creating tag "$name"');
    try {
      final tag = await _todoService.createTag(name);
      _tags.add(tag);
      notifyListeners();
      await _logger.log('HomeProvider: Tag created successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error creating tag', e, stack);
      rethrow;
    }
  }

  Future<void> createFilter(CustomFilter filter) async {
    await _logger.log('HomeProvider: Creating filter "${filter.name}"');
    try {
      final f = await _todoService.createFilter(filter);
      _filters.add(f);
      notifyListeners();
      await _logger.log('HomeProvider: Filter created successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error creating filter', e, stack);
      rethrow;
    }
  }

  Future<void> deleteFilter(String id) async {
    await _logger.log('HomeProvider: Deleting filter $id');
    try {
      await _todoService.deleteFilter(id);
      _filters.removeWhere((f) => f.id == id);
      if (_selectedIndex >= 4) _selectedIndex = 0;
      notifyListeners();
      await _logger.log('HomeProvider: Filter deleted successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error deleting filter', e, stack);
      rethrow;
    }
  }
  
  Future<void> updateFilter(CustomFilter filter) async {
    await _logger.log('HomeProvider: Updating filter ${filter.id}');
    try {
      final f = await _todoService.updateFilter(filter);
      final idx = _filters.indexWhere((i) => i.id == filter.id);
      if (idx != -1) _filters[idx] = f;
      notifyListeners();
      await _logger.log('HomeProvider: Filter updated successfully');
    } catch (e, stack) {
      await _logger.error('HomeProvider: Error updating filter', e, stack);
      rethrow;
    }
  }

  // Helpers
  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDay(DateTime a, DateTime b) => 
    a.year == b.year && a.month == b.month && a.day == b.day;
}
