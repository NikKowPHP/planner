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

  Future<void> _createTask(String title, {String? listId}) async {
    if (title.trim().isEmpty) return;
    
    // 1. Optimistic Update: Create temp task
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempTask = Task(
      id: tempId,
      userId: 'current_user',
      title: title,
      listId: listId,
      priority: 0,
      isCompleted: false,
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
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return _tasks.where((t) {
          if (t.dueDate == null) return false;
          final tDate = DateTime(
            t.dueDate!.year,
            t.dueDate!.month,
            t.dueDate!.day,
          );
          return tDate.isAtSameMomentAs(today);
        }).toList();
      case 2: // Next 7 Days
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextWeek = today.add(const Duration(days: 7));
        return _tasks.where((t) {
          if (t.dueDate == null) return false;
          final tDate = DateTime(
            t.dueDate!.year,
            t.dueDate!.month,
            t.dueDate!.day,
          );
          return !tDate.isBefore(today) && tDate.isBefore(nextWeek);
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

    // Filter tasks based on sections
    final noDateTasks = tasksToShow
        .where((t) => !t.isCompleted && t.dueDate == null)
        .toList();
    final completedTasks = tasksToShow.where((t) => t.isCompleted).toList();
    // For now, put dated tasks in "No Date" or create separate section
    final datedTasks = tasksToShow
        .where((t) => !t.isCompleted && t.dueDate != null)
        .toList();

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
                    onPressed: () {
                      _loadTasks();
                    }, // Reload button for now
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
          
          // Add Task Input (Only for All, Inbox, or Custom Lists - or maybe everywhere with varying logic?)
          // For now, default to Inbox logic if 'All' or 'Inbox' is selected.
          // If a specific list is selected, implementation details for adding to that list are needed.
          // Let's assume adding task adds to current list if selected, or inbox otherwise.
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _taskController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText:
                    '+ Add task to "${_currentTitle == 'All' || _currentTitle == 'Next 7 Days' || _currentTitle == 'Today' ? 'Inbox' : _currentTitle}"',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              onSubmitted: (value) {
                // Determine listId
                String? targetListId;
                if (_selectedIndex >= 4) {
                  final listIndex = _selectedIndex - 4;
                  if (listIndex < _lists.length) {
                    targetListId = _lists[listIndex].id;
                  }
                }
                // Pass targetListId to _createTask (need to refactor _createTask to accept it)
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
                  if (datedTasks.isNotEmpty) ...[
                    TaskListGroup(
                      title: "Planned",
                      tasks: datedTasks,
                      onTaskToggle: _toggleTask,
                      onTaskLongPress: _deleteTask,
                    ),
                    const SizedBox(height: 24),
                  ],
                  TaskListGroup(
                    title: "No Date",
                    tasks: noDateTasks,
                    onTaskToggle: _toggleTask,
                    onTaskLongPress: _deleteTask,
                  ),
                  const SizedBox(height: 24),
                  if (completedTasks.isNotEmpty)
                    TaskListGroup(
                      title: "Completed",
                      tasks: completedTasks,
                      onTaskToggle: _toggleTask,
                      onTaskTap: (task) {
                        // Optional: Edit logic here
                      },
                      onTaskLongPress: _deleteTask,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
