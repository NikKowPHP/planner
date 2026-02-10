import 'package:flutter/material.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_navigation_bar.dart';
import '../widgets/glass_sidebar.dart';
import '../widgets/responsive_layout.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/tag.dart';
import '../models/custom_filter.dart';
import '../widgets/task_list_group.dart';
import '../widgets/filter_editor_dialog.dart';
import '../widgets/task_detail_panel.dart';
import '../theme/glass_theme.dart';
import '../services/todo_service.dart';
import '../widgets/task_context_menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// Enums
enum GroupBy { date, priority, list, none }
enum SortBy { date, priority, title }

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final TextEditingController _taskController = TextEditingController();
  final TodoService _todoService = TodoService();
  
  List<Task> _tasks = [];
  List<TaskList> _lists = [];
  List<Tag> _tags = [];
  List<CustomFilter> _filters = [];
  bool _isLoading = true;
  Task? _selectedTask;

  GroupBy _groupBy = GroupBy.date;
  SortBy _sortBy = SortBy.date;
  bool _hideCompleted = false;

  DateTime _stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final tasks = await _todoService.getTasks();
      final lists = await _todoService.getLists();
      final tags = await _todoService.getTags();
      final filters = await _todoService.getFilters();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _lists = lists;
          _tags = tags;
          _filters = filters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _createTask(String title, {String? listId}) async {
    if (title.trim().isEmpty) return;
    
    DateTime? defaultDate;
    if (_selectedIndex == 1) {
      defaultDate = DateTime.now();
    } else if (_selectedIndex == 2) {
      defaultDate = DateTime.now();
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempTask = Task(
      id: tempId,
      userId: 'current_user',
      title: title,
      listId: listId,
      priority: 0,
      isCompleted: false,
      dueDate: defaultDate,
    );

    setState(() {
      _tasks.insert(0, tempTask);
      _taskController.clear();
    });

    try {
      final newTask = await _todoService.createTask(
        title: title,
        listId: listId,
        dueDate: defaultDate,
      );
      
      if (mounted) {
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == tempId);
          if (index != -1) {
            _tasks[index] = newTask;
          } else {
            _tasks.insert(0, newTask);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasks.removeWhere((t) => t.id == tempId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating task: $e')));
      }
    }
  }

  Future<void> _updateTaskDate(Task task, DateTime? newDate) async {
    final updatedTask = Task(
      id: task.id,
      userId: task.userId,
      listId: task.listId,
      title: task.title,
      description: task.description,
      isCompleted: task.isCompleted,
      priority: task.priority,
      dueDate: newDate,
      tagIds: task.tagIds,
      deletedAt: task.deletedAt,
    );

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    final oldTask = _tasks[index];

    setState(() {
      _tasks[index] = updatedTask;
    });

    try {
      await _todoService.updateTask(updatedTask);
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasks[index] = oldTask;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update date')));
      }
    }
  }

  Future<void> _showDatePicker(Task task) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      _updateTaskDate(task, pickedDate);
    }
  }

  Future<void> _toggleTask(Task task, bool value) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    final originalTask = _tasks[index];
    final updatedTask = Task(
      id: originalTask.id,
      userId: originalTask.userId,
      title: originalTask.title,
      description: originalTask.description,
      dueDate: originalTask.dueDate,
      priority: originalTask.priority,
      listId: originalTask.listId,
      isCompleted: value,
      tagIds: originalTask.tagIds,
      deletedAt: originalTask.deletedAt,
    );

    setState(() {
      _tasks[index] = updatedTask;
    });

    try {
      await _todoService.toggleTaskCompletion(task.id, value);
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _tasks.indexWhere((t) => t.id == task.id);
          if (idx != -1) _tasks[idx] = originalTask;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating task: $e')));
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    if (!mounted) return;

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    final originalTask = _tasks[index];
    final softDeletedTask = Task(
      id: originalTask.id,
      userId: originalTask.userId,
      title: originalTask.title,
      description: originalTask.description,
      dueDate: originalTask.dueDate,
      isCompleted: originalTask.isCompleted,
      priority: originalTask.priority,
      listId: originalTask.listId,
      tagIds: originalTask.tagIds,
      isPinned: originalTask.isPinned,
      deletedAt: DateTime.now(),
    );

    setState(() {
      _tasks[index] = softDeletedTask;
    });

    try {
      await _todoService.deleteTask(task.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _tasks.indexWhere((t) => t.id == task.id);
          if (idx != -1) _tasks[idx] = originalTask;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting task: $e')));
      }
    }
  }

  // NEW: Update Task Pin Status
  Future<void> _toggleTaskPin(Task task) async {
    final updatedTask = Task(
      id: task.id,
      userId: task.userId,
      listId: task.listId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      isCompleted: task.isCompleted,
      priority: task.priority,
      tagIds: task.tagIds,
      isPinned: !task.isPinned, // Toggle
    );
    await _updateTaskGeneric(updatedTask);
  }

  // NEW: Duplicate Task
  Future<void> _duplicateTask(Task task) async {
    try {
      final newTask = await _todoService.duplicateTask(task);
      setState(() {
        _tasks.insert(0, newTask);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task Duplicated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // NEW: Show Tag Selection Dialog
  Future<void> _showTagSelectionDialog(Task task) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Manage Tags', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final isSelected = task.tagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<String> newTags = List.from(task.tagIds);
                    if (selected) {
                      newTags.add(tag.id);
                    } else {
                      newTags.remove(tag.id);
                    }

                    final updatedTask = Task(
                      id: task.id,
                      userId: task.userId,
                      listId: task.listId,
                      title: task.title,
                      description: task.description,
                      dueDate: task.dueDate,
                      priority: task.priority,
                      isCompleted: task.isCompleted,
                      isPinned: task.isPinned,
                      tagIds: newTags,
                    );
                    _updateTaskGeneric(updatedTask);
                  },
                  backgroundColor: Colors.white10,
                  selectedColor: GlassTheme.accentColor.withValues(alpha: 0.3),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // NEW: Show Move To Dialog
  Future<void> _showMoveToDialog(Task task) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Container(
          width: 300,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Move to List',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text(
                        'Inbox',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        final updated = Task(
                          id: task.id,
                          userId: task.userId,
                          title: task.title,
                          description: task.description,
                          dueDate: task.dueDate,
                          priority: task.priority,
                          isCompleted: task.isCompleted,
                          isPinned: task.isPinned,
                          tagIds: task.tagIds,
                          listId: null,
                        );
                        _updateTaskGeneric(updated);
                      },
                    ),
                    ..._lists.map(
                      (l) => ListTile(
                        title: Text(
                          l.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final updated = Task(
                            id: task.id,
                            userId: task.userId,
                            title: task.title,
                            description: task.description,
                            dueDate: task.dueDate,
                            priority: task.priority,
                            isCompleted: task.isCompleted,
                            isPinned: task.isPinned,
                            tagIds: task.tagIds,
                            listId: l.id,
                          );
                          _updateTaskGeneric(updated);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setTaskPriority(Task task, int priority) async {
    final updatedTask = Task(
      id: task.id,
      userId: task.userId,
      listId: task.listId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      isCompleted: task.isCompleted,
      priority: priority,
      tagIds: task.tagIds,
      deletedAt: task.deletedAt,
    );

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      final oldTask = _tasks[index];
      setState(() => _tasks[index] = updatedTask);
      try {
        await _todoService.updateTask(updatedTask);
      } catch (e) {
        if (mounted) setState(() => _tasks[index] = oldTask);
      }
    }
  }

  void _selectTask(Task task) {
    setState(() {
      _selectedTask = task;
    });

    if (!ResponsiveLayout.isDesktop(context)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.85,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: TaskDetailPanel(
              task: task,
              onClose: () => Navigator.pop(context),
              onUpdate: _updateTaskGeneric,
              onDelete: (t) {
                Navigator.pop(context);
                _deleteTask(t);
              },
              userLists: _lists,
            ),
          ),
        ),
      );
    }
  }

  void _closeSidePanel() {
    setState(() {
      _selectedTask = null;
    });
  }

  Future<void> _updateTaskGeneric(Task updatedTask) async {
    if (!mounted) return;

    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return;

    final oldTask = _tasks[index];
    setState(() {
      _tasks[index] = updatedTask;
      if (_selectedTask?.id == updatedTask.id) {
        _selectedTask = updatedTask;
      }
    });

    try {
      await _todoService.updateTask(updatedTask);
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasks[index] = oldTask;
          if (_selectedTask?.id == oldTask.id) {
            _selectedTask = oldTask;
          }
        });
      }
    }
  }



  void _showTaskContextMenu(Task task, TapUpDetails details) {
    final position = details.globalPosition;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 260),
      items: TaskContextMenu.buildItems(
        context: context,
        task: task,
        onDateSelect: (date) {
          if (date != null) {
            _updateTaskDate(task, date);
          } else {
            _showDatePicker(task);
          }
        },
        onPrioritySelect: (priority) => _setTaskPriority(task, priority),
        onPin: () {
          Navigator.pop(context);
          _toggleTaskPin(task);
        },
        onDuplicate: () {
          Navigator.pop(context);
          _duplicateTask(task);
        },
        onMove: () {
          Navigator.pop(context);
          _showMoveToDialog(task);
        },
        onTags: () {
          Navigator.pop(context);
          _showTagSelectionDialog(task);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteTask(task);
        },
      ),
    );
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('New Tag', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tag Name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                try {
                  final newTag = await _todoService.createTag(
                    controller.text.trim(),
                  );
                  setState(() => _tags.add(newTag));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // NEW: CRUD Methods for Filters
  void _createFilter() {
    showDialog(
      context: context,
      builder: (context) => FilterEditorDialog(
        onSave: (name, criteria) async {
          try {
            final newFilter = CustomFilter(
              id: '',
              userId: '',
              name: name,
              criteria: criteria,
            );
            final created = await _todoService.createFilter(newFilter);
            setState(() => _filters.add(created));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error creating filter: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _editFilter(CustomFilter filter) {
    showDialog(
      context: context,
      builder: (context) => FilterEditorDialog(
        filter: filter,
        onSave: (name, criteria) async {
          try {
            final updated = CustomFilter(
              id: filter.id,
              userId: filter.userId,
              name: name,
              icon: filter.icon,
              color: filter.color,
              criteria: criteria,
            );
            final result = await _todoService.updateFilter(updated);
            setState(() {
              final index = _filters.indexWhere((f) => f.id == filter.id);
              if (index != -1) _filters[index] = result;
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating filter: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteFilter(CustomFilter filter) async {
    try {
      await _todoService.deleteFilter(filter.id);
      setState(() {
        _filters.removeWhere((f) => f.id == filter.id);
        if (_selectedIndex >= 4 && _selectedIndex < 4 + _filters.length) {
          _selectedIndex = 0;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting filter: $e')));
      }
    }
  }

  Future<void> _createList() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('New List', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'List Name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                navigator.pop();
                try {
                  final newList = await _todoService.createList(
                    controller.text.trim(),
                  );
                  if (mounted) {
                    setState(() {
                      _lists.add(newList);
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error creating list: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<Task> get _filteredTasks {
    // Handle special views
    if (_selectedIndex == -2) {
      return _tasks.where((t) => t.deletedAt != null).toList();
    }

    final activeTasks = _tasks.where((t) => t.deletedAt == null).toList();

    if (_selectedIndex == -1) {
      return activeTasks.where((t) => t.isCompleted).toList();
    }

    // Calculate index boundaries
    final filterStartIndex = 4;
    final listStartIndex = 4 + _filters.length;
    final tagStartIndex = listStartIndex + _lists.length;

    List<Task> filtered;

    // Standard Views (0-3)
    if (_selectedIndex >= 0 && _selectedIndex < 4) {
      switch (_selectedIndex) {
        case 0:
          filtered = activeTasks;
          break;
        case 1:
          final now = _stripTime(DateTime.now());
          filtered = activeTasks.where((t) {
            if (t.dueDate == null) return false;
            final tDate = _stripTime(t.dueDate!);
            return tDate.isAtSameMomentAs(now);
          }).toList();
          break;
        case 2:
          final now = _stripTime(DateTime.now());
          final nextWeek = now.add(const Duration(days: 7));
          filtered = activeTasks.where((t) {
            if (t.dueDate == null) return false;
            final tDate = _stripTime(t.dueDate!);
            return !tDate.isBefore(now) && tDate.isBefore(nextWeek);
          }).toList();
          break;
        case 3:
          filtered = activeTasks.where((t) => t.listId == null).toList();
          break;
        default:
          filtered = [];
      }
    }
    // Custom Filters
    else if (_selectedIndex >= filterStartIndex &&
        _selectedIndex < listStartIndex) {
      final filterIndex = _selectedIndex - filterStartIndex;
      if (filterIndex >= 0 && filterIndex < _filters.length) {
        final filter = _filters[filterIndex];
        filtered = activeTasks.where((t) => filter.matches(t)).toList();
      } else {
        filtered = [];
      }
    }
    // Lists
    else if (_selectedIndex >= listStartIndex &&
        _selectedIndex < tagStartIndex) {
      final listIndex = _selectedIndex - listStartIndex;
      if (listIndex >= 0 && listIndex < _lists.length) {
        final listId = _lists[listIndex].id;
        filtered = activeTasks.where((t) => t.listId == listId).toList();
      } else {
        filtered = [];
      }
    }
    // Tags
    else if (_selectedIndex >= tagStartIndex) {
      final tagIndex = _selectedIndex - tagStartIndex;
      if (tagIndex >= 0 && tagIndex < _tags.length) {
        final tagId = _tags[tagIndex].id;
        filtered = activeTasks.where((t) => t.tagIds.contains(tagId)).toList();
      } else {
        filtered = [];
      }
    } else {
      filtered = [];
    }

    if (_hideCompleted) {
      filtered = filtered.where((t) => !t.isCompleted).toList();
    }

    return filtered;
  }

  Map<String, List<Task>> _getGroupedTasks(List<Task> tasks) {
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
        final tDate = _stripTime(t.dueDate!);
        if (tDate.isBefore(now)) {
          (groups['Overdue'] ??= []).add(t);
        } else if (tDate.isAtSameMomentAs(now)) {
          (groups['Today'] ??= []).add(t);
        } else if (tDate.isAtSameMomentAs(tomorrow)) {
          (groups['Tomorrow'] ??= []).add(t);
        } else if (tDate.isBefore(nextWeek)) {
          (groups['Next 7 Days'] ??= []).add(t);
        } else {
          (groups['Later'] ??= []).add(t);
        }
      }

      final orderedKeys = [
        'Overdue',
        'Today',
        'Tomorrow',
        'Next 7 Days',
        'Later',
        'No Date',
        'Completed',
      ];
      final Map<String, List<Task>> orderedGroups = {};
      for (var key in orderedKeys) {
        if (groups.containsKey(key)) orderedGroups[key] = groups[key]!;
      }
      return orderedGroups;
    } else if (_groupBy == GroupBy.priority) {
      for (var t in tasks) {
        if (t.isCompleted && !_hideCompleted) {
          (groups['Completed'] ??= []).add(t);
          continue;
        }
        final key = _getPriorityLabel(t.priority);
        (groups[key] ??= []).add(t);
      }
      final orderedKeys = ['High', 'Medium', 'Low', 'None', 'Completed'];
      final Map<String, List<Task>> orderedGroups = {};
      for (var key in orderedKeys) {
        if (groups.containsKey(key)) orderedGroups[key] = groups[key]!;
      }
      return orderedGroups;
    } else if (_groupBy == GroupBy.list) {
      for (var t in tasks) {
        if (t.isCompleted && !_hideCompleted) {
          (groups['Completed'] ??= []).add(t);
          continue;
        }
        String listName = 'Inbox';
        if (t.listId != null) {
          try {
            listName = _lists.firstWhere((l) => l.id == t.listId).name;
          } catch (_) {}
        }
        (groups[listName] ??= []).add(t);
      }
      return groups;
    } else {
      groups['Tasks'] = tasks;
      return groups;
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'None';
    }
  }

  void _sortList(List<Task> list) {
    list.sort((a, b) {
      switch (_sortBy) {
        case SortBy.title:
          return a.title.compareTo(b.title);
        case SortBy.priority:
          return b.priority.compareTo(a.priority);
        case SortBy.date:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
      }
    });
  }

  String get _currentTitle {
    if (_selectedIndex == -1) return 'Completed';
    if (_selectedIndex == -2) return 'Trash';

    // Calculate index boundaries
    final filterStartIndex = 4;
    final listStartIndex = 4 + _filters.length;
    final tagStartIndex = listStartIndex + _lists.length;

    // Standard views
    if (_selectedIndex >= 0 && _selectedIndex < 4) {
      switch (_selectedIndex) {
        case 0:
          return 'All';
        case 1:
          return 'Today';
        case 2:
          return 'Next 7 Days';
        case 3:
          return 'Inbox';
        default:
          return 'Glassy';
      }
    }

    // Custom Filters
    if (_selectedIndex >= filterStartIndex && _selectedIndex < listStartIndex) {
      final filterIndex = _selectedIndex - filterStartIndex;
      if (filterIndex >= 0 && filterIndex < _filters.length) {
        return _filters[filterIndex].name;
      }
    }

    // Lists
    if (_selectedIndex >= listStartIndex && _selectedIndex < tagStartIndex) {
      final listIndex = _selectedIndex - listStartIndex;
      if (listIndex >= 0 && listIndex < _lists.length) {
        return _lists[listIndex].name;
      }
    }

    // Tags
    if (_selectedIndex >= tagStartIndex) {
      final tagIndex = _selectedIndex - tagStartIndex;
      if (tagIndex >= 0 && tagIndex < _tags.length) {
        return '# ${_tags[tagIndex].name}';
      }
    }

    return 'Glassy';
  }

  String get _inputPlaceholder {
    switch (_selectedIndex) {
      case 0:
        return '+ Add task to Inbox';
      case 1:
        return '+ Add task to Today';
      case 2:
        return '+ Add task to Next 7 Days';
      case 3:
        return '+ Add task to Inbox';
      default:
        final listIndex = _selectedIndex - 4;
        if (listIndex >= 0 && listIndex < _lists.length) {
          return '+ Add task to ${_lists[listIndex].name}';
        }
        return '+ Add a task';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const LiquidBackground(),
          if (isDesktop)
            Row(
              children: [
                GlassSidebar(
                  selectedIndex: _selectedIndex,
                  userLists: _lists,
                  tags: _tags.map((t) => t.name).toList(),
                  customFilters: _filters,
                  onAddList: _createList,
                  onAddTag: _createTag,
                  onAddFilter: _createFilter,
                  onEditFilter: _editFilter,
                  onDeleteFilter: _deleteFilter,
                  onItemSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
                Expanded(child: _buildMainContent()),
                if (_selectedTask != null) ...[
                  const VerticalDivider(width: 1, color: Colors.white10),
                  SizedBox(
                    width: 400,
                    child: TaskDetailPanel(
                      task: _selectedTask!,
                      onClose: _closeSidePanel,
                      onUpdate: _updateTaskGeneric,
                      onDelete: (t) {
                        _closeSidePanel();
                        _deleteTask(t);
                      },
                      userLists: _lists,
                    ),
                  ),
                ],
              ],
            )
          else
            Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: ResponsiveLayout(child: _buildMainContent()),
                ),
                GlassNavigationBar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final tasksToShow = _filteredTasks;
    final groupedTasks = _getGroupedTasks(tasksToShow);
    groupedTasks.forEach((key, list) => _sortList(list));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu, color: Colors.white, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    _currentTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: const Color(0xFF1E1E1E),
                      popupMenuTheme: PopupMenuThemeData(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        textStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                    child: PopupMenuButton<dynamic>(
                      icon: const Icon(Icons.swap_vert, color: Colors.white),
                      tooltip: 'Sort & Group',
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'GROUP BY',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildRadioItem(
                          'Date',
                          _groupBy == GroupBy.date,
                          () => setState(() => _groupBy = GroupBy.date),
                        ),
                        _buildRadioItem(
                          'Priority',
                          _groupBy == GroupBy.priority,
                          () => setState(() => _groupBy = GroupBy.priority),
                        ),
                        _buildRadioItem(
                          'List',
                          _groupBy == GroupBy.list,
                          () => setState(() => _groupBy = GroupBy.list),
                        ),
                        _buildRadioItem(
                          'None',
                          _groupBy == GroupBy.none,
                          () => setState(() => _groupBy = GroupBy.none),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'SORT BY',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildRadioItem(
                          'Date',
                          _sortBy == SortBy.date,
                          () => setState(() => _sortBy = SortBy.date),
                        ),
                        _buildRadioItem(
                          'Priority',
                          _sortBy == SortBy.priority,
                          () => setState(() => _sortBy = SortBy.priority),
                        ),
                        _buildRadioItem(
                          'Title',
                          _sortBy == SortBy.title,
                          () => setState(() => _sortBy = SortBy.title),
                        ),
                      ],
                    ),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: const Color(0xFF1E1E1E),
                      popupMenuTheme: PopupMenuThemeData(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        textStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                    child: PopupMenuButton<dynamic>(
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      tooltip: 'View Options',
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          enabled: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Icon(Icons.list, color: GlassTheme.accentColor),
                              const Icon(
                                Icons.view_column_outlined,
                                color: Colors.white38,
                              ),
                              const Icon(
                                Icons.calendar_view_month,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        CheckedPopupMenuItem(
                          checked: _hideCompleted,
                          value: 'hide',
                          child: const Text('Hide Completed'),
                          onTap: () =>
                              setState(() => _hideCompleted = !_hideCompleted),
                        ),
                        const CheckedPopupMenuItem(
                          checked: true,
                          value: 'details',
                          child: Text('Show Details'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(
                                Icons.print,
                                size: 18,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 12),
                              Text('Print'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _taskController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _inputPlaceholder,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              onSubmitted: (value) {
                String? targetListId;
                if (_selectedIndex >= 4) {
                  final listIndex = _selectedIndex - 4;
                  if (listIndex < _lists.length) {
                    targetListId = _lists[listIndex].id;
                  }
                }
                _createTask(value, listId: targetListId);
              },
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: groupedTasks.length,
                itemBuilder: (context, index) {
                  final groupName = groupedTasks.keys.elementAt(index);
                  final tasks = groupedTasks[groupName]!;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TaskListGroup(
                      title: groupName,
                      tasks: tasks,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem _buildRadioItem(
    String text,
    bool selected,
    VoidCallback onTap,
  ) {
    return PopupMenuItem(
      onTap: onTap,
      height: 40,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? GlassTheme.accentColor : Colors.white38,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: selected ? Colors.white : Colors.white70),
          ),
        ],
      ),
    );
  }
}
