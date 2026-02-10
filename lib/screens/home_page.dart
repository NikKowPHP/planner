import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_navigation_bar.dart';
import '../widgets/glass_sidebar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/task_list_group.dart';
import '../widgets/filter_editor_dialog.dart';
import '../widgets/task_detail_panel.dart';
import '../widgets/home/home_app_bar.dart';
import '../providers/home_provider.dart';
import '../models/task.dart';
import '../models/custom_filter.dart';
import '../widgets/task_context_menu.dart';
import '../services/logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _taskController = TextEditingController();
  final FileLogger _logger = FileLogger();

  @override
  void initState() {
    super.initState();
    // Load data once
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Provider.of<HomeProvider>(context, listen: false).loadData();
      } catch (e, s) {
        await _logger.error('UI: Initial load failed', e, s);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final provider = Provider.of<HomeProvider>(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const LiquidBackground(),
          if (isDesktop)
            Row(
              children: [
                GlassSidebar(
                  selectedIndex: provider.selectedIndex,
                  userLists: provider.lists,
                  tags: provider.tags.map((t) => t.name).toList(),
                  customFilters: provider.filters,
                  onAddList: _createList,
                  onAddTag: _createTag,
                  onAddFilter: _createFilter,
                  onEditFilter: _editFilter,
                  onDeleteFilter: (f) => _safeAction(
                    () => provider.deleteFilter(f.id),
                    'Delete filter',
                  ),
                  onItemSelected: (i) => _safeAction(
                    () => provider.setSelectedIndex(i),
                    'Select index $i',
                  ),
                ),
                Expanded(child: _buildMainContent(provider)),
                if (provider.selectedTask != null) ...[
                  const VerticalDivider(width: 1, color: Colors.white10),
                  SizedBox(
                    width: 400,
                    child: TaskDetailPanel(
                      task: provider.selectedTask!,
                      onClose: () => _safeAction(
                        () => provider.selectTask(null),
                        'Close detail panel',
                      ),
                      onUpdate: (t) => _safeAction(
                        () => provider.updateTask(t),
                        'Update task',
                      ),
                      onDelete: (t) {
                        _safeAction(() async {
                          await provider.selectTask(null);
                          await provider.deleteTask(t);
                        }, 'Delete task from panel');
                      },
                      userLists: provider.lists,
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
                  child: ResponsiveLayout(child: _buildMainContent(provider)),
                ),
                GlassNavigationBar(
                  selectedIndex: provider.selectedIndex,
                  onItemSelected: (i) => _safeAction(
                    () => provider.setSelectedIndex(i),
                    'Nav Bar Select $i',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(HomeProvider provider) {
    final groupedTasks = provider.groupedTasks;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeAppBar(),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _taskController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: provider.inputPlaceholder,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              onSubmitted: (value) async {
                await _safeAction(() async {
                  await provider.createTask(value);
                  _taskController.clear();
                }, 'Create task via input');
              },
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.loadData,
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
                      onTaskToggle: (task, val) {
                        final updated = Task(
                          id: task.id,
                          userId: task.userId,
                          listId: task.listId,
                          title: task.title,
                          description: task.description,
                          dueDate: task.dueDate,
                          priority: task.priority,
                          tagIds: task.tagIds,
                          isPinned: task.isPinned,
                          isCompleted: val,
                        );
                        _safeAction(
                          () => provider.updateTask(updated),
                          'Toggle task completion',
                        );
                      },
                      onTaskTap: (task) {
                        _safeAction(() async {
                          await provider.selectTask(task);
                          if (!context.mounted) return;
                          if (!ResponsiveLayout.isDesktop(context)) {
                            _showMobileDetailSheet(context, provider, task);
                          }
                        }, 'Tap task item');
                      },
                      onTaskContextMenu: (task, details) =>
                          _showTaskContextMenu(
                            context,
                            provider,
                            task,
                            details,
                          ),
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

  // --- Helper Methods with Try/Catch Logging ---

  Future<void> _safeAction(
    Future<void> Function() action,
    String actionName,
  ) async {
    try {
      await _logger.log('UI Action: $actionName started');
      await action();
    } catch (e, stack) {
      await _logger.error('UI Action: $actionName failed', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showMobileDetailSheet(
    BuildContext context,
    HomeProvider provider,
    Task task,
  ) {
    _logger.log('UI: Opening mobile detail sheet');
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
            onUpdate: (t) =>
                _safeAction(() => provider.updateTask(t), 'Update task mobile'),
              onDelete: (t) {
                Navigator.pop(context);
              _safeAction(() => provider.deleteTask(t), 'Delete task mobile');
              },
            userLists: provider.lists,
            ),
          ),
        ),
      );
  }

  Future<void> _createList() async {
    await _logger.log('UI: Opened Create List Dialog');
    final controller = TextEditingController();
    if (!mounted) return;
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _safeAction(
                  () => Provider.of<HomeProvider>(
                    context,
                    listen: false,
                  ).createList(controller.text),
                  'Create List Confirmed',
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createTag() async {
    await _logger.log('UI: Opened Create Tag Dialog');
    final controller = TextEditingController();
    if (!mounted) return;
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _safeAction(
                  () => Provider.of<HomeProvider>(
                    context,
                    listen: false,
                  ).createTag(controller.text),
                  'Create Tag Confirmed',
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createFilter() {
    _logger.log('UI: Opened Create Filter Dialog');
    showDialog(
      context: context,
      builder: (context) => FilterEditorDialog(
        onSave: (name, criteria) {
          final newFilter = CustomFilter(
            id: '',
            userId: '',
            name: name,
            criteria: criteria,
          );
          _safeAction(
            () => Provider.of<HomeProvider>(
              context,
              listen: false,
            ).createFilter(newFilter),
            'Create Filter Confirmed',
          );
        },
      ),
    );
  }

  void _editFilter(CustomFilter filter) {
    _logger.log('UI: Opened Edit Filter Dialog for ${filter.id}');
    showDialog(
      context: context,
      builder: (context) => FilterEditorDialog(
        filter: filter,
        onSave: (name, criteria) {
          final updated = CustomFilter(
            id: filter.id,
            userId: filter.userId,
            name: name,
            criteria: criteria,
            icon: filter.icon,
            color: filter.color,
          );
          _safeAction(
            () => Provider.of<HomeProvider>(
              context,
              listen: false,
            ).updateFilter(updated),
            'Edit Filter Confirmed',
          );
        },
      ),
    );
  }

  void _showTaskContextMenu(
    BuildContext context,
    HomeProvider provider,
    Task task,
    TapUpDetails details,
  ) {
    _logger.log('UI: Opened Task Context Menu for ${task.id}');
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
      items: TaskContextMenu.buildItems(
        context: context,
        task: task,
        onDateSelect: (date) {
          final updated = Task(
            id: task.id,
            userId: task.userId,
            title: task.title,
            isCompleted: task.isCompleted,
            priority: task.priority,
            dueDate: date ?? DateTime.now(),
            tagIds: task.tagIds,
            listId: task.listId,
            isPinned: task.isPinned,
          );
          _safeAction(
            () => provider.updateTask(updated),
            'Context Menu: Update Date',
          );
        },
        onPrioritySelect: (p) {
          final updated = Task(
            id: task.id,
            userId: task.userId,
            title: task.title,
            isCompleted: task.isCompleted,
            priority: p,
            dueDate: task.dueDate,
            tagIds: task.tagIds,
            listId: task.listId,
            isPinned: task.isPinned,
          );
          _safeAction(
            () => provider.updateTask(updated),
            'Context Menu: Update Priority',
          );
        },
        onPin: () {
          Navigator.pop(context);
          final updated = Task(
            id: task.id,
            userId: task.userId,
            title: task.title,
            isCompleted: task.isCompleted,
            priority: task.priority,
            dueDate: task.dueDate,
            tagIds: task.tagIds,
            listId: task.listId,
            isPinned: !task.isPinned,
          );
          _safeAction(
            () => provider.updateTask(updated),
            'Context Menu: Toggle Pin',
          );
        },
        onDuplicate: () {
          Navigator.pop(context);
          _safeAction(
            () => provider.createTask(task.title),
            'Context Menu: Duplicate Task',
          );
        }, 
        onMove: () {
          Navigator.pop(context);
          _logger.log(
            'UI: Move task requested (not implemented completely in new refactor yet)',
          );
        },
        onTags: () {
          Navigator.pop(context);
          _logger.log(
            'UI: Tags requested (not implemented completely in new refactor yet)',
          );
        },
        onDelete: () {
          Navigator.pop(context);
          _safeAction(
            () => provider.deleteTask(task),
            'Context Menu: Delete Task',
          );
        },
      ),
    );
  }
}
