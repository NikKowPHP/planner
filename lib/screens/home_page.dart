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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}



class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final TextEditingController _taskController = TextEditingController();
  final TodoService _todoService = TodoService();
  
  // Cache for tasks and lists
  List<Task> _tasks = [];
  List<TaskList> _lists = [];
  bool _isLoading = true;
  Task? _selectedTask;

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
  
  // Helper to load only tasks (for refresh)
  Future<void> _loadTasks() async {
    try {
      final tasks = await _todoService.getTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
        });
      }
    } catch (e) {
      // Handle silently or show snackbar
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
    switch (_selectedIndex) {
      case 0: // All
        return _tasks;
      case 1: // Today
        final now = _stripTime(DateTime.now());
        return _tasks.where((t) {
          if (t.dueDate == null) return false;
          final tDate = _stripTime(t.dueDate!);
          return tDate.isAtSameMomentAs(now);
        }).toList();
      case 2: // Next 7 Days
        final now = _stripTime(DateTime.now());
        final nextWeek = now.add(const Duration(days: 7));
        return _tasks.where((t) {
          if (t.dueDate == null) return false;
          final tDate = _stripTime(t.dueDate!);
          return !tDate.isBefore(now) && tDate.isBefore(nextWeek);
        }).toList();
      case 3: // Inbox (No list assigned)
        return _tasks.where((t) => t.listId == null).toList();
      default:
        // Lists
        // Index 4 onwards corresponds to _lists[index - 4]
        final listIndex = _selectedIndex - 4;
        if (listIndex >= 0 && listIndex < _lists.length) {
          return _tasks.where((t) => t.listId == _lists[listIndex].id).toList();
        }
        return [];
    }
  }

  String get _currentTitle {
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
        final listIndex = _selectedIndex - 4;
        if (listIndex >= 0 && listIndex < _lists.length) {
          return _lists[listIndex].name;
        }
        return 'Lists';
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

  // MODIFY: Refined filtering and grouping logic (TickTick Style)
  Widget _buildMainContent() {
    final tasksToShow = _filteredTasks;
    
    // Sort logic: Overdue -> Today -> Tomorrow -> Future -> No Date -> Completed
    final now = _stripTime(DateTime.now());
    final tomorrow = now.add(const Duration(days: 1));
    final nextWeek = now.add(const Duration(days: 7));

    final List<Task> overdue = [];
    final List<Task> today = [];
    final List<Task> tmrw = [];
    final List<Task> next7Days = []; // Days after tomorrow, up to 7 days
    final List<Task> later = [];
    final List<Task> noDate = [];
    final List<Task> completed = [];

    for (var t in tasksToShow) {
      if (t.isCompleted) {
        completed.add(t);
        continue;
      }

      if (t.dueDate == null) {
        noDate.add(t);
        continue;
      }

      final tDate = _stripTime(t.dueDate!);

      if (tDate.isBefore(now)) {
        overdue.add(t);
      } else if (tDate.isAtSameMomentAs(now)) {
        today.add(t);
      } else if (tDate.isAtSameMomentAs(tomorrow)) {
        tmrw.add(t);
      } else if (tDate.isBefore(nextWeek)) {
        next7Days.add(t);
      } else {
        later.add(t);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                  IconButton(
                    icon: const Icon(Icons.sort, color: Colors.white),
                    onPressed: _loadTasks,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Input
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _taskController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _inputPlaceholder, // Dynamic Placeholder
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              onSubmitted: (value) {
                String? targetListId;
                // If in a custom list view, use that list ID
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

          // Task Lists
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  if (overdue.isNotEmpty) ...[
                    TaskListGroup(
                      title: "Overdue",
                      tasks: overdue,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (today.isNotEmpty) ...[
                    TaskListGroup(
                      title: "Today",
                      tasks: today,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (tmrw.isNotEmpty) ...[
                    TaskListGroup(
                      title: "Tomorrow",
                      tasks: tmrw,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (next7Days.isNotEmpty) ...[
                    TaskListGroup(
                      title: "Next 7 Days",
                      tasks: next7Days,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (later.isNotEmpty) ...[
                    TaskListGroup(
                      title: "Later",
                      tasks: later,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (noDate.isNotEmpty) ...[
                    TaskListGroup(
                      title: "No Date",
                      tasks: noDate,
                      onTaskToggle: _toggleTask,
                      onTaskTap: _selectTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (completed.isNotEmpty)
                    TaskListGroup(
                      title: "Completed",
                      tasks: completed,
                      onTaskToggle: _toggleTask,
                      onTaskContextMenu: _showTaskContextMenu,
                    ),
                  // Add bottom padding to avoid FAB overlap if added later
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
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
