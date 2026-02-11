import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/search_dialog.dart';
import '../providers/app_providers.dart';
import '../models/task.dart';
import '../models/custom_filter.dart';
import '../widgets/task_context_menu.dart';
import '../services/logger.dart';
import '../widgets/glass_rail.dart';
import 'focus_page.dart';
import '../widgets/calendar/glass_calendar.dart';
import 'habit_page.dart';
import '../models/task_list.dart';

// Import new widgets for Docs
import 'docs_page.dart';
import '../widgets/docs/docs_sidebar.dart';

// NEW: Define Intent
class SearchIntent extends Intent {
  const SearchIntent();
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _taskController = TextEditingController();
  final FileLogger _logger = FileLogger();
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // Add Key
  final FocusNode _mainFocusNode = FocusNode(); // ADD THIS

  @override
  void initState() {
    super.initState();
    // Ensure the page grabs focus immediately to listen for shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    _mainFocusNode.dispose(); // ADD THIS
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    // Watch Data
    final listsAsync = ref.watch(listsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final filtersAsync = ref.watch(filtersProvider);
    
    // Watch UI State
    final activeTab = ref.watch(homeViewProvider.select((s) => s.activeTab));
    final selectedIndex = ref.watch(homeViewProvider.select((s) => s.selectedIndex));
    final selectedTask = ref.watch(homeViewProvider.select((s) => s.selectedTask));
    final isSidebarVisible = ref.watch(homeViewProvider.select((s) => s.isSidebarVisible));
    final isSearchVisible = ref.watch(homeViewProvider.select((s) => s.isSearchVisible));
    final notifier = ref.read(homeViewProvider.notifier);
    final tasksNotifier = ref.read(tasksProvider.notifier);

    // Inputs for Sidebar
    final lists = listsAsync.value ?? [];
    final tags = tagsAsync.value ?? [];
    final filters = filtersAsync.value ?? [];

    // Reusable Sidebar Widget
    final sidebar = GlassSidebar(
      width: isDesktop ? 250 : double.infinity, // Flexible width
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
      onItemSelected: (index) {
        notifier.setIndex(index);
        if (!isDesktop) Navigator.pop(context); // Close drawer on mobile
      },
    );

    // MODIFIED: Simplified Shortcut Logic using CallbackShortcuts + Explicit FocusNode
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          FileLogger().log('GESTURE: Keyboard Shortcut Ctrl+K recognized');
          // Ensure we clear focus from any active elements before opening search
          FocusScope.of(context).unfocus();
          notifier.toggleSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          FileLogger().log('GESTURE: Keyboard Shortcut Cmd+K recognized');
          // Ensure we clear focus from any active elements before opening search
          FocusScope.of(context).unfocus();
          notifier.toggleSearch();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (isSearchVisible) {
            FileLogger().log('GESTURE: Escape key pressed -> Closing Search');
            notifier.toggleSearch();
          }
        },
      },
      child: Focus(
        focusNode: _mainFocusNode, // Use the managed FocusNode
        autofocus: true,
        onFocusChange: (focused) {
          if (!focused && !isSearchVisible) {
            // Re-request focus if something else un-focuses the main listener
            _mainFocusNode.requestFocus();
          }
        },
        child: Scaffold(
          key: _scaffoldKey, // Attach Key
          extendBody: true,
        // Only show Drawer on mobile and when on Tasks or Docs tab
        drawer: (!isDesktop && (activeTab == AppTab.tasks || activeTab == AppTab.docs))
            ? Drawer(
                backgroundColor: const Color(0xFF0F0F0F),
                width: 300,
                child: Column(
                  children: [
                    _buildDrawerHeader(ref),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        // Swap sidebar based on tab
                        child: activeTab == AppTab.docs 
                            ? const DocsSidebar(width: double.infinity) 
                            : sidebar,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        body: Stack(
        children: [
          const LiquidBackground(),
          if (isDesktop)
            Row(
              children: [
                // 1. Main Navigation Rail
                GlassRail(
                  activeTab: activeTab,
                  onTabSelected: notifier.setActiveTab,
                ),

                // 2. Context Sidebar (Tasks only)
                if (activeTab == AppTab.tasks)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isSidebarVisible ? (isDesktop ? 250 : 0) : 0,
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: 250,
                        maxWidth: 250,
                        alignment: Alignment.centerLeft,
                        child: isSidebarVisible ? sidebar : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                
                // NEW: Docs Sidebar
                if (activeTab == AppTab.docs)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isSidebarVisible ? (isDesktop ? 250 : 0) : 0,
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: 250,
                        maxWidth: 250,
                        alignment: Alignment.centerLeft,
                        child: isSidebarVisible 
                            ? DocsSidebar(width: 250) 
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                // 3. Main Content
                Expanded(
                  child: _buildBodyContent(activeTab, ref),
                ),

                // 4. Detail Panel
                if (activeTab == AppTab.tasks && selectedTask != null) ...[
                  const VerticalDivider(width: 1, color: Colors.white10),
                  SizedBox(
                    width: 400,
                    child: _buildDetailPanel(
                      selectedTask,
                      notifier,
                      tasksNotifier,
                      lists,
                    ),
                  ),
                ],
              ],
            )
          else
            // Mobile Layout
            Stack(
              children: [
                SafeArea(
                  bottom: false,
                  // Add bottom padding to content to avoid overlapping nav bar
                  child: _buildBodyContent(activeTab, ref),
                ),
                GlassNavigationBar(
                  currentTab: activeTab,
                  onTabSelected: (tab) {
                    notifier.setActiveTab(tab);
                    // If switching to Tasks, ensure a valid index is set if needed
                    if (tab == AppTab.tasks && selectedIndex < 0) {
                      notifier.setIndex(0);
                    }
                  },
                ),
              ],
            ),
          
          if (isSearchVisible) ...[
            GestureDetector(
              onTap: () => notifier.toggleSearch(),
              child: Container(color: Colors.black54),
            ),
            const SearchDialog(),
          ],
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(
    Task selectedTask,
    dynamic notifier,
    dynamic tasksNotifier,
    List<TaskList> lists,
  ) {
    return TaskDetailPanel(
      task: selectedTask,
      onClose: () => notifier.selectTask(null),
      onUpdate: (t) =>
          _safeAction(() => tasksNotifier.updateTask(t), 'Update Task'),
      onDelete: (t) {
        notifier.selectTask(null);
        _safeAction(() => tasksNotifier.deleteTask(t), 'Delete Task');
      },
      userLists: lists,
    );
  }

  Widget _buildBodyContent(AppTab activeTab, WidgetRef ref) {
    final isMobile = ResponsiveLayout.isMobile(context);
    
    switch (activeTab) {
      case AppTab.calendar:
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, isMobile ? 100 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeAppBar(), // No drawer menu on calendar
               const SizedBox(height: 24),
               Expanded(
                 child: GlassCalendar(
                    onTaskTap: (task) {
                      ref.read(homeViewProvider.notifier).navigateToItem(task);
                    },
                 ),
               ),
            ],
          ),
        );
      case AppTab.focus:
        return const FocusPage();
      case AppTab.docs:
        return const DocsPage();
      case AppTab.habit:
        return const HabitPage();
      case AppTab.tasks:
        return _buildTaskContent(ref);
    }
  }

  Widget _buildTaskContent(WidgetRef ref) {
    final groupedTasks = ref.watch(groupedTasksProvider);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, isMobile ? 100 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeAppBar(
            // Handle both Mobile (Drawer) and Desktop (Sidebar Toggle)
            onMenuPressed: isMobile
                ? () => _scaffoldKey.currentState?.openDrawer()
                : () => ref.read(homeViewProvider.notifier).toggleSidebar(),
          ),
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
                FileLogger().log('GESTURE: Quick add task submitted: "$value"');
                 await _safeAction(() async {
                   await ref.read(tasksProvider.notifier).createTask(value);
                   if (mounted) _taskController.clear();
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
                padding: EdgeInsets.zero,
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
                        if (isMobile) {
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
                final service = ref.read(todoServiceProvider);
                Navigator.pop(context);
                _safeAction(() async {
                  await service.createList(controller.text);
                  if (mounted) ref.invalidate(listsProvider);
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
                final service = ref.read(todoServiceProvider);
                Navigator.pop(context);
                _safeAction(() async {
                  await service.createTag(controller.text);
                  if (mounted) ref.invalidate(tagsProvider);
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
          final service = ref.read(todoServiceProvider);
        _safeAction(() async {
            await service.createFilter(f);
            if (mounted) ref.invalidate(filtersProvider);
        }, 'Create Filter');
     }));
  }

  void _editFilter(BuildContext context, WidgetRef ref, CustomFilter filter) {
     showDialog(context: context, builder: (c) => FilterEditorDialog(filter: filter, onSave: (name, criteria) {
        final f = CustomFilter(id: filter.id, userId: filter.userId, name: name, criteria: criteria, icon: filter.icon, color: filter.color);
          final service = ref.read(todoServiceProvider);
        _safeAction(() async {
            await service.updateFilter(f);
            if (mounted) ref.invalidate(filtersProvider);
        }, 'Update Filter');
     }));
  }

  Future<void> _showMoveToDialog(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    await _logger.log('UI: Opening Move To Dialog for task ${task.id}');

    // Capture ref-dependent values BEFORE showing the dialog
    final lists = ref.read(listsProvider).value ?? [];
    final tasksNotifier = ref.read(tasksProvider.notifier);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Move to List',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.inbox, color: Colors.white54),
                        title: const Text(
                          'Inbox',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(dialogContext);
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
                            listId: null, // Move to Inbox
                          );
                          _safeAction(
                            () => tasksNotifier.updateTask(updated),
                            'Move to Inbox',
                          );
                        },
                      ),
                      ...lists.map(
                        (l) => ListTile(
                          leading: const Icon(
                            Icons.list,
                            color: Colors.white54,
                          ),
                          title: Text(
                            l.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(dialogContext);
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
                              listId: l.id, // Move to specific list
                            );
                            _safeAction(
                              () => tasksNotifier.updateTask(updated),
                              'Move to ${l.name}',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileDetailSheet(BuildContext context, WidgetRef ref, Task task) {
     // Capture ref-dependent values BEFORE showing the bottom sheet
     final tasksNotifier = ref.read(tasksProvider.notifier);
     final userLists = ref.read(listsProvider).value ?? [];

     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(
           heightFactor: 0.85,
           child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: TaskDetailPanel(
                 task: task,
                 onClose: () => Navigator.pop(sheetContext),
                 onUpdate: (t) {
                   _safeAction(() => tasksNotifier.updateTask(t), 'Update Mobile');
                 },
                 onDelete: (t) {
                   Navigator.pop(sheetContext);
                   _safeAction(() => tasksNotifier.deleteTask(t), 'Delete Mobile');
                 },
                 userLists: userLists,
              ),
           ),
        ),
     );
  }

  void _showTaskContextMenu(BuildContext context, WidgetRef ref, Task task, TapUpDetails details) {
     final pos = details.globalPosition;
     // Capture ref-dependent values BEFORE showing the menu
     final notifier = ref.read(tasksProvider.notifier);
     
     showMenu(
        context: context,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx+1, pos.dy+1),
        color: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent, // Add this to prevent M3 transparency issues
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        items: TaskContextMenu.buildItems(
           context: context,
           task: task,
           onDateSelect: (d) {
              if (d == null) return; // Logic for date picker call needed if null
              final u = Task(id: task.id, userId: task.userId, listId: task.listId, title: task.title, isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, isPinned: task.isPinned, dueDate: d);
              _safeAction(() => notifier.updateTask(u), 'Context: Update Date');
           },
        onPrioritySelect: (p) async {
          await _logger.log(
            'UI_CONTEXT: User selected priority $p for task ${task.id}',
          );
          final u = Task(
            id: task.id,
            userId: task.userId,
            listId: task.listId,
            title: task.title,
            isCompleted: task.isCompleted,
            priority: p,
            tagIds: task.tagIds,
            isPinned: task.isPinned,
            dueDate: task.dueDate,
          );
              _safeAction(() => notifier.updateTask(u), 'Context: Priority');
           },
        onPin: () async {
               Navigator.pop(context);
          await _logger.log('UI_CONTEXT: User toggled pin for task ${task.id}');
               final u = Task(id: task.id, userId: task.userId, listId: task.listId, title: task.title, isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, isPinned: !task.isPinned, dueDate: task.dueDate);
              _safeAction(() => notifier.updateTask(u), 'Context: Pin');
           },
           onDuplicate: () {
              Navigator.pop(context);
              _safeAction(() => notifier.createTask(task.title), 'Context: Duplicate');
           },
           // Capture ref eagerly so move dialog doesn't use a stale ref
           onMove: () {
             Navigator.pop(context);
             _showMoveToDialog(context, ref, task);
           },
           onTags: () { Navigator.pop(context); /* Implement Tag Logic */ },
           onDelete: () { 
              Navigator.pop(context); 
              _safeAction(() => notifier.deleteTask(task), 'Context: Delete'); 
           },
        ),
     );
  }

  Widget _buildDrawerHeader(WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white24),
              image: profileAsync.value?.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(profileAsync.value!.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: profileAsync.value?.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white70, size: 24)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profileAsync.value?.username ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                GestureDetector(
                  onTap: () => ref.read(authServiceProvider).signOut(),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
