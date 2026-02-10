import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_navigation_bar.dart';
import '../widgets/glass_sidebar.dart';
import '../widgets/responsive_layout.dart';
import '../providers/auth_provider.dart';
import '../models/task.dart';
import '../widgets/task_list_group.dart';
import '../services/todo_service.dart';
import '../models/task_list.dart';
import '../widgets/task_detail_panel.dart';
import '../theme/glass_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}



// NEW CODE START: Enums
enum GroupBy { date, priority, list, none }
enum SortBy { date, priority, title }
// NEW CODE END

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final TextEditingController _taskController = TextEditingController();
  final TodoService _todoService = TodoService();
  
  // Cache for tasks and lists
  List<Task> _tasks = [];
  List<TaskList> _lists = [];
  bool _isLoading = true;
  Task? _selectedTask;

  // NEW CODE START: Mock Tags
  final List<String> _tags = ['Urgent', 'Work', 'Personal'];
  // NEW CODE END

  // NEW CODE START: View State
  GroupBy _groupBy = GroupBy.date;
  SortBy _sortBy = SortBy.date;
  bool _hideCompleted = false;
  // NEW CODE END

  // ADD: Date utility to strip time
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
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _lists = lists;
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
  

  // MODIFY: Update _createTask to handle dates based on current view
  Future<void> _createTask(String title, {String? listId}) async {
    if (title.trim().isEmpty) return;
    
    // Determine default date based on selected view
    DateTime? defaultDate;
    if (_selectedIndex == 1) {
      // Today View
      defaultDate = DateTime.now();
    }
    // "Next 7 Days" usually defaults to Today in TickTick, or user picks.
    // We will default to Today for convenience.
    else if (_selectedIndex == 2) {
      defaultDate = DateTime.now();
    }

    // 1. Optimistic Update: Create temp task
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempTask = Task(
      id: tempId,
      userId: 'current_user',
      title: title,
      listId: listId,
      priority: 0,
      isCompleted: false,
      dueDate: defaultDate, // Set the date
    );

    setState(() {
      _tasks.insert(0, tempTask);
      _taskController.clear();
    });

    try {
      // 2. Perform actual API call
      final newTask = await _todoService.createTask(
        title: title,
        listId: listId,
        dueDate: defaultDate, // Pass date to service
      );
      
      // 3. Replace temp task with real task
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == tempId);
        if (index != -1) {
          _tasks[index] = newTask;
        } else {
          _tasks.insert(0, newTask);
        }
      });
    } catch (e) {
      // 4. Revert on error
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

  // ADD: Method to reschedule/regroup tasks
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
    );

    // Optimistic update
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

  // ADD: Date Picker Dialog
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

    // 1. Optimistic Update
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
    );

    setState(() {
      _tasks[index] = updatedTask;
    });

    try {
      // 2. API Call
      await _todoService.toggleTaskCompletion(task.id, value);
    } catch (e) {
      // 3. Revert
      if (mounted) {
        setState(() {
          // Find it again in case index changed
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
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    // 1. Optimistic Update
    final deletedTask = _tasks[index];
    setState(() {
      _tasks.removeAt(index);
    });

    try {
      // 2. API Call
      await _todoService.deleteTask(task.id);
    } catch (e) {
      // 3. Revert
      if (mounted) {
        setState(() {
          _tasks.insert(index, deletedTask);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting task: $e')));
      }
    }
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
    );

    // Optimistic update
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
    // Optimistic Update
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

  // ADD: Edit Task Dialog (Title/Description)
  Future<void> _showEditTaskDialog(Task task) async {
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Edit Task', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty) {
                final updatedTask = Task(
                  id: task.id,
                  userId: task.userId,
                  listId: task.listId,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  dueDate: task.dueDate,
                  isCompleted: task.isCompleted,
                  priority: task.priority,
                );
                Navigator.pop(context);

                // Optimistic Update
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
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ADD: Context Menu Logic
  void _showTaskContextMenu(Task task, TapUpDetails details) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final position = details.globalPosition;

    // Menu Items Data
    final items = [
      _ContextMenuItem('Edit', Icons.edit, () => _showEditTaskDialog(task)),
      _ContextMenuItem(
        'Set Date',
        Icons.calendar_today,
        () => _showDatePicker(task),
      ),
      _ContextMenuItem('Priority', Icons.flag, () => _showPrioritySheet(task)),
      _ContextMenuItem(
        'Delete',
        Icons.delete_outline,
        () => _deleteTask(task),
        isDestructive: true,
      ),
    ];

    if (isDesktop) {
      // Desktop: Popup Menu at cursor
      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        color: const Color(0xFF1E1E1E),
        items: items
            .map(
              (item) => PopupMenuItem(
                onTap: item.onTap,
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: item.isDestructive
                          ? Colors.redAccent
                          : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.title,
                      style: TextStyle(
                        color: item.isDestructive
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    } else {
      // Mobile: Bottom Sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map(
                  (item) => ListTile(
                    leading: Icon(
                      item.icon,
                      color: item.isDestructive
                          ? Colors.redAccent
                          : Colors.white70,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: item.isDestructive
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      item.onTap();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
  }

  // ADD: Priority Selection Sheet (Sub-menu)
  void _showPrioritySheet(Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Select Priority',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            _buildPriorityTile(task, 3, 'High', Colors.redAccent),
            _buildPriorityTile(task, 2, 'Medium', Colors.orangeAccent),
            _buildPriorityTile(task, 1, 'Low', Colors.blueAccent),
            _buildPriorityTile(task, 0, 'None', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityTile(
    Task task,
    int priority,
    String label,
    Color color,
  ) {
    return ListTile(
      leading: Icon(Icons.flag, color: color),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: task.priority == priority
          ? const Icon(Icons.check, color: Colors.white)
          : null,
      onTap: () {
        Navigator.pop(context);
        _setTaskPriority(task, priority);
      },
    );
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

  // Filtering Logic
  List<Task> get _filteredTasks {
    List<Task> filtered;
    
    // 1. Basic Filter by View (Inbox, Today, List, Tag, etc.)
    if (_selectedIndex == -1) {
      filtered = _tasks.where((t) => t.isCompleted).toList();
    } else if (_selectedIndex == -2) {
      filtered = []; 
    } else {
      final activeTasks = _tasks; // Start with all
      
      switch (_selectedIndex) {
        case 0: // All
          filtered = activeTasks;
          break;
        case 1: // Today
          final now = _stripTime(DateTime.now());
          filtered = activeTasks.where((t) {
            if (t.dueDate == null) return false;
            final tDate = _stripTime(t.dueDate!);
            return tDate.isAtSameMomentAs(now);
          }).toList();
          break;
        case 2: // Next 7 Days
          final now = _stripTime(DateTime.now());
          final nextWeek = now.add(const Duration(days: 7));
          filtered = activeTasks.where((t) {
            if (t.dueDate == null) return false;
            final tDate = _stripTime(t.dueDate!);
            return !tDate.isBefore(now) && tDate.isBefore(nextWeek);
          }).toList();
          break;
        case 3: // Inbox
          filtered = activeTasks.where((t) => t.listId == null).toList();
          break;
        default:
          final listCount = _lists.length;
          if (_selectedIndex >= 4 && _selectedIndex < 4 + listCount) {
             filtered = activeTasks.where((t) => t.listId == _lists[_selectedIndex - 4].id).toList();
          } else if (_selectedIndex >= 4 + listCount) {
             filtered = activeTasks; // Mock tags: return all for now
          } else {
             filtered = [];
          }
      }
    }

    // 2. Apply "Hide Completed" Filter
    // If not in "Completed" view (-1), and _hideCompleted is true, remove completed
    if (_selectedIndex != -1 && _hideCompleted) {
      filtered = filtered.where((t) => !t.isCompleted).toList();
    }
    
    return filtered;
  }

  // NEW CODE START: Grouping Logic
  Map<String, List<Task>> _getGroupedTasks(List<Task> tasks) {
    Map<String, List<Task>> groups = {};

    if (_groupBy == GroupBy.date) {
      // Existing Smart Date Logic
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
      
      // Enforce specific order for Date view
      final orderedKeys = ['Overdue', 'Today', 'Tomorrow', 'Next 7 Days', 'Later', 'No Date', 'Completed'];
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
      // Order: High -> None
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
      return groups; // Alphabetical order default by map insertion usually, or sort keys if needed

    } else {
      // None
      groups['Tasks'] = tasks;
      return groups;
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 3: return 'High';
      case 2: return 'Medium';
      case 1: return 'Low';
      default: return 'None';
    }
  }

  void _sortList(List<Task> list) {
    list.sort((a, b) {
      switch (_sortBy) {
        case SortBy.title:
          return a.title.compareTo(b.title);
        case SortBy.priority:
          return b.priority.compareTo(a.priority); // Descending
        case SortBy.date:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
      }
    });
  }
  // NEW CODE END

  String get _currentTitle {
    if (_selectedIndex == -1) return 'Completed';
    if (_selectedIndex == -2) return 'Trash';

    switch (_selectedIndex) {
      case 0: return 'All';
      case 1: return 'Today';
      case 2: return 'Next 7 Days';
      case 3: return 'Inbox';
      default:
        final listCount = _lists.length;
        
        if (_selectedIndex >= 4 && _selectedIndex < 4 + listCount) {
          return _lists[_selectedIndex - 4].name;
        }
        
        if (_selectedIndex >= 4 + listCount) {
           final tagIndex = _selectedIndex - (4 + listCount);
           if (tagIndex >= 0 && tagIndex < _tags.length) {
             return '# ${_tags[tagIndex]}';
           }
        }
        return 'Glassy';
    }
  }

  // MODIFY: Helper to get dynamic placeholder text
  String get _inputPlaceholder {
    switch (_selectedIndex) {
      case 0:
        return '+ Add task to Inbox'; // All usually dumps to Inbox
      case 1:
        return '+ Add task to Today';
      case 2:
        return '+ Add task to Next 7 Days';
      case 3:
        return '+ Add task to Inbox';
      default:
        // List indices start at 4
        final listIndex = _selectedIndex - 4;
        if (listIndex >= 0 && listIndex < _lists.length) {
          return '+ Add task to ${_lists[listIndex].name}';
        }
        return '+ Add a task';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final authProvider = Provider.of<AuthProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background
          const LiquidBackground(),

          // Content
          if (isDesktop)
            Row(
              children: [
                GlassSidebar(
                  selectedIndex: _selectedIndex,
                  userLists: _lists,
                  // NEW CODE START
                  tags: _tags,
                  // NEW CODE END
                  onAddList: _createList,
                  onItemSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
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
                  child: ResponsiveLayout(
                    child: _buildMainContent(),
                  ),
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
    
    // NEW CODE START: Process Groups
    final groupedTasks = _getGroupedTasks(tasksToShow);
    groupedTasks.forEach((key, list) => _sortList(list));
    // NEW CODE END

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Row(
                children: [
                   const Icon(Icons.menu, color: Colors.white, size: 28),
                   const SizedBox(width: 16),
                   Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              
              // Actions
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
                  
                  // NEW CODE START: Sort/Group Menu
                  Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: const Color(0xFF1E1E1E),
                      popupMenuTheme: PopupMenuThemeData(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                        textStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                    child: PopupMenuButton<dynamic>(
                      icon: const Icon(Icons.swap_vert, color: Colors.white),
                      tooltip: 'Sort & Group',
                      itemBuilder: (context) => [
                        // Grouping Header
                        const PopupMenuItem(enabled: false, child: Text('GROUP BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        _buildRadioItem('Date', _groupBy == GroupBy.date, () => setState(() => _groupBy = GroupBy.date)),
                        _buildRadioItem('Priority', _groupBy == GroupBy.priority, () => setState(() => _groupBy = GroupBy.priority)),
                        _buildRadioItem('List', _groupBy == GroupBy.list, () => setState(() => _groupBy = GroupBy.list)),
                        _buildRadioItem('None', _groupBy == GroupBy.none, () => setState(() => _groupBy = GroupBy.none)),
                        const PopupMenuDivider(),
                        // Sorting Header
                        const PopupMenuItem(enabled: false, child: Text('SORT BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        _buildRadioItem('Date', _sortBy == SortBy.date, () => setState(() => _sortBy = SortBy.date)),
                        _buildRadioItem('Priority', _sortBy == SortBy.priority, () => setState(() => _sortBy = SortBy.priority)),
                        _buildRadioItem('Title', _sortBy == SortBy.title, () => setState(() => _sortBy = SortBy.title)),
                      ],
                    ),
                  ),

                  // NEW CODE START: View Options Menu
                  Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: const Color(0xFF1E1E1E),
                      popupMenuTheme: PopupMenuThemeData(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                        textStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                    child: PopupMenuButton<dynamic>(
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      tooltip: 'View Options',
                      itemBuilder: (context) => [
                        // View Toggles (Visual only for now)
                        PopupMenuItem(
                          enabled: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Icon(Icons.list, color: GlassTheme.accentColor),
                              const Icon(Icons.view_column_outlined, color: Colors.white38),
                              const Icon(Icons.calendar_view_month, color: Colors.white38),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        CheckedPopupMenuItem(
                          checked: _hideCompleted,
                          value: 'hide',
                          child: const Text('Hide Completed'),
                          onTap: () => setState(() => _hideCompleted = !_hideCompleted),
                        ),
                        const CheckedPopupMenuItem(
                          checked: true, // Mock logic
                          value: 'details',
                          child: Text('Show Details'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          child: Row(
                             children: [Icon(Icons.print, size: 18, color: Colors.white70), SizedBox(width: 12), Text('Print')],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // NEW CODE END
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          // Input Field (Existing)
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

          // NEW CODE START: Dynamic List Building
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
          // NEW CODE END
        ],
      ),
    );
  }

  // Helper for menu items
  PopupMenuItem _buildRadioItem(String text, bool selected, VoidCallback onTap) {
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
          Text(text, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
        ],
      ),
    );
  }
}

class _ContextMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  _ContextMenuItem(
    this.title,
    this.icon,
    this.onTap, {
    this.isDestructive = false,
  });
}
