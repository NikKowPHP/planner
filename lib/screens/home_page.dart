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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final TextEditingController _taskController = TextEditingController();
  final TodoService _todoService = TodoService();
  
  // Cache for tasks
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      setState(() => _isLoading = true);
      final tasks = await _todoService.getTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Show error snackbar
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tasks: $e')));
      }
    }
  }

  Future<void> _createTask(String title) async {
    if (title.trim().isEmpty) return;
    
    // 1. Optimistic Update: Create temp task
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempTask = Task(
      id: tempId,
      userId: 'current_user', // Placeholder, ignored by UI or Service usually
      title: title,
      priority: 0,
      isCompleted: false,
    );

    setState(() {
      _tasks.insert(0, tempTask); // Add to top immediately
      _taskController.clear();
    });

    try {
      // 2. Perform actual API call
      final newTask = await _todoService.createTask(title: title);
      
      // 3. Replace temp task with real task
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == tempId);
        if (index != -1) {
          _tasks[index] = newTask;
        } else {
          // If list changed in between, just add to top
          _tasks.insert(0, newTask);
        }
      });
    } catch (e) {
      // 4. Revert on error
      setState(() {
        _tasks.removeWhere((t) => t.id == tempId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating task: $e')));
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
    // Filter tasks based on sections
    final noDateTasks = _tasks
        .where((t) => !t.isCompleted && t.dueDate == null)
        .toList();
    final completedTasks = _tasks.where((t) => t.isCompleted).toList();
    // For now, put dated tasks in "No Date" or create separate section
    final datedTasks = _tasks
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
                  const Text(
                    "All",
                    style: TextStyle(
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

          // Add Task Input
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _taskController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '+ Add task to "Inbox"',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              ),
              onSubmitted: _createTask,
            ),
          ),
          const SizedBox(height: 24),

          // Task Lists
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
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
