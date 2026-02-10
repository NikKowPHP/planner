import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_navigation_bar.dart';
import '../widgets/glass_sidebar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/task_list_group.dart';
import '../widgets/filter_editor_dialog.dart';
import '../widgets/task_detail_panel.dart';
import '../widgets/home/home_app_bar.dart';
import '../providers/app_providers.dart';
import '../models/task.dart';
import '../models/custom_filter.dart';
import '../widgets/task_context_menu.dart';
import '../services/logger.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _taskController = TextEditingController();
  final FileLogger _logger = FileLogger();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    // Watch Data
    final listsAsync = ref.watch(listsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final filtersAsync = ref.watch(filtersProvider);
    
    // Watch UI State
    final selectedIndex = ref.watch(homeViewProvider.select((s) => s.selectedIndex));
    final selectedTask = ref.watch(homeViewProvider.select((s) => s.selectedTask));
    final notifier = ref.read(homeViewProvider.notifier);
    final tasksNotifier = ref.read(tasksProvider.notifier);

    // Inputs for Sidebar
    final lists = listsAsync.value ?? [];
    final tags = tagsAsync.value ?? [];
    final filters = filtersAsync.value ?? [];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const LiquidBackground(),
          if (isDesktop)
            Row(
              children: [
                GlassSidebar(
                  selectedIndex: selectedIndex,
                  userLists: lists,
                  tags: tags.map((t) => t.name).toList(),
                  customFilters: filters,
                  onAddList: () => _createList(context, ref),
                  onAddTag: () => _createTag(context, ref),
                  onAddFilter: () => _createFilter(context, ref),
                  onEditFilter: (f) => _editFilter(context, ref, f),
                  onDeleteFilter: (f) => _safeAction(() async {
                     await ref.read(todoServiceProvider).deleteFilter(f.id);
                     ref.invalidate(filtersProvider);
                  }, 'Delete Filter'),
                  onItemSelected: notifier.setIndex,
                ),
                Expanded(child: _buildMainContent(ref)),
                if (selectedTask != null) ...[
                  const VerticalDivider(width: 1, color: Colors.white10),
                  SizedBox(
                    width: 400,
                    child: TaskDetailPanel(
                      task: selectedTask,
                      onClose: () => notifier.selectTask(null),
                      onUpdate: (t) => _safeAction(() => tasksNotifier.updateTask(t), 'Update Task'),
                      onDelete: (t) {
                         notifier.selectTask(null);
                         _safeAction(() => tasksNotifier.deleteTask(t), 'Delete Task');
                      },
                      userLists: lists,
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
                  child: ResponsiveLayout(child: _buildMainContent(ref)),
                ),
                GlassNavigationBar(
                  selectedIndex: selectedIndex,
                  onItemSelected: notifier.setIndex,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(WidgetRef ref) {
    final groupedTasks = ref.watch(groupedTasksProvider);

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
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "+ Add a task", 
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onSubmitted: (value) async {
                 if (value.trim().isEmpty) return;
                 await _safeAction(() async {
                   await ref.read(tasksProvider.notifier).createTask(value);
                   _taskController.clear();
                 }, 'Create Task');
              },
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                 ref.invalidate(tasksProvider);
                 ref.invalidate(listsProvider);
                 await ref.read(tasksProvider.future);
              },
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
                           id: task.id, userId: task.userId, listId: task.listId, title: task.title, 
                           description: task.description, dueDate: task.dueDate, priority: task.priority,
                           tagIds: task.tagIds, isPinned: task.isPinned, isCompleted: val
                         );
                         _safeAction(() => ref.read(tasksProvider.notifier).updateTask(updated), 'Toggle Task');
                      },
                      onTaskTap: (task) {
                        ref.read(homeViewProvider.notifier).selectTask(task);
                        if (!ResponsiveLayout.isDesktop(context)) {
                          _showMobileDetailSheet(context, ref, task);
                        }
                      },
                      onTaskContextMenu: (task, details) => 
                         _showTaskContextMenu(context, ref, task, details),
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

  Future<void> _safeAction(Future<void> Function() action, String name) async {
    try {
      await _logger.log('UI: $name started');
      await action();
    } catch (e, stack) {
      await _logger.error('UI: $name failed', e, stack);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Dialog Helpers
  Future<void> _createList(BuildContext context, WidgetRef ref) async {
     final controller = TextEditingController();
     await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: const Color(0xFF1E1E1E),
         title: const Text('New List', style: TextStyle(color: Colors.white)),
         content: TextField(controller: controller, style: const TextStyle(color: Colors.white)),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
           TextButton(onPressed: () {
             if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _safeAction(() async {
                  await ref.read(todoServiceProvider).createList(controller.text);
                  ref.invalidate(listsProvider);
                }, 'Create List');
             }
           }, child: const Text('Create')),
         ],
       ),
     );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
     // Similar to List
     final controller = TextEditingController();
     await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: const Color(0xFF1E1E1E),
         title: const Text('New Tag', style: TextStyle(color: Colors.white)),
         content: TextField(controller: controller, style: const TextStyle(color: Colors.white)),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
           TextButton(onPressed: () {
             if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _safeAction(() async {
                  await ref.read(todoServiceProvider).createTag(controller.text);
                  ref.invalidate(tagsProvider);
                }, 'Create Tag');
             }
           }, child: const Text('Create')),
         ],
       ),
     );
  }
  
  void _createFilter(BuildContext context, WidgetRef ref) {
     showDialog(context: context, builder: (c) => FilterEditorDialog(onSave: (name, criteria) {
        final f = CustomFilter(id: '', userId: '', name: name, criteria: criteria);
        _safeAction(() async {
          await ref.read(todoServiceProvider).createFilter(f);
          ref.invalidate(filtersProvider);
        }, 'Create Filter');
     }));
  }

  void _editFilter(BuildContext context, WidgetRef ref, CustomFilter filter) {
     showDialog(context: context, builder: (c) => FilterEditorDialog(filter: filter, onSave: (name, criteria) {
        final f = CustomFilter(id: filter.id, userId: filter.userId, name: name, criteria: criteria, icon: filter.icon, color: filter.color);
        _safeAction(() async {
          await ref.read(todoServiceProvider).updateFilter(f);
          ref.invalidate(filtersProvider);
        }, 'Update Filter');
     }));
  }

  void _showMobileDetailSheet(BuildContext context, WidgetRef ref, Task task) {
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
                 onUpdate: (t) => _safeAction(() => ref.read(tasksProvider.notifier).updateTask(t), 'Update Mobile'),
                 onDelete: (t) {
                    Navigator.pop(context);
                    _safeAction(() => ref.read(tasksProvider.notifier).deleteTask(t), 'Delete Mobile');
                 },
                 userLists: ref.read(listsProvider).value ?? [],
              ),
           ),
        ),
     );
  }

  void _showTaskContextMenu(BuildContext context, WidgetRef ref, Task task, TapUpDetails details) {
     final pos = details.globalPosition;
     final notifier = ref.read(tasksProvider.notifier);
     
     showMenu(
        context: context,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx+1, pos.dy+1),
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        items: TaskContextMenu.buildItems(
           context: context,
           task: task,
           onDateSelect: (d) {
              if (d == null) return; // Logic for date picker call needed if null
              final u = Task(id: task.id, userId: task.userId, listId: task.listId, title: task.title, isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, isPinned: task.isPinned, dueDate: d);
              _safeAction(() => notifier.updateTask(u), 'Context: Update Date');
           },
           onPrioritySelect: (p) {
               final u = Task(id: task.id, userId: task.userId, listId: task.listId, title: task.title, isCompleted: task.isCompleted, priority: p, tagIds: task.tagIds, isPinned: task.isPinned, dueDate: task.dueDate);
              _safeAction(() => notifier.updateTask(u), 'Context: Priority');
           },
           onPin: () {
               Navigator.pop(context);
               final u = Task(id: task.id, userId: task.userId, listId: task.listId, title: task.title, isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, isPinned: !task.isPinned, dueDate: task.dueDate);
              _safeAction(() => notifier.updateTask(u), 'Context: Pin');
           },
           onDuplicate: () {
              Navigator.pop(context);
              _safeAction(() => notifier.createTask(task.title), 'Context: Duplicate');
           },
           onMove: () { Navigator.pop(context); /* Implement Move Logic */ },
           onTags: () { Navigator.pop(context); /* Implement Tag Logic */ },
           onDelete: () { 
              Navigator.pop(context); 
              _safeAction(() => notifier.deleteTask(task), 'Context: Delete'); 
           },
        ),
     );
  }
}
