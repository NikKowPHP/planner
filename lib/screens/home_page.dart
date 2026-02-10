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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final TextEditingController _taskController = TextEditingController();

  // Mock data for now
  final List<Task> _mockTasks = [
    Task(id: '1', userId: '1', title: 'Find delivery service', priority: 0),
    Task(id: '2', userId: '1', title: 'Car license', priority: 0),
    Task(
      id: '3',
      userId: '1',
      title: 'set the backups for the dbs',
      priority: 0,
    ),
  ];

  final List<Task> _mockCompletedTasks = [
    Task(
      id: '4',
      userId: '1',
      title: 'Create document for Emma',
      isCompleted: true,
    ),
    Task(
      id: '5',
      userId: '1',
      title: 'find the sponge big for cleaning',
      isCompleted: true,
    ),
    Task(
      id: '6',
      userId: '1',
      title: 'find the rooms / house',
      isCompleted: true,
    ),
    Task(id: '7', userId: '1', title: 'workout', isCompleted: true),
  ];

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
                  IconButton(
                    icon: const Icon(Icons.sort, color: Colors.white),
                    onPressed: () {},
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
              onSubmitted: (value) {
                // TODO: Implement task addition
                _taskController.clear();
              },
            ),
          ),
          const SizedBox(height: 24),

          // Task Lists
          Expanded(
            child: ListView(
              children: [
                TaskListGroup(
                  title: "No Date",
                  tasks: _mockTasks,
                  onTaskToggle: (task, val) {
                    setState(() {
                      // Mock toggle
                    });
                  },
                ),
                const SizedBox(height: 24),
                TaskListGroup(
                  title: "Completed",
                  tasks: _mockCompletedTasks,
                  onTaskToggle: (task, val) {
                    setState(() {
                      // Mock toggle
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
