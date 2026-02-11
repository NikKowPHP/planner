import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../theme/glass_theme.dart';
import '../glass_card.dart';
import '../task_item.dart';
import '../task_context_menu.dart';
import '../../services/logger.dart';

class DayDetailsSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final Function(Task) onTaskTap;

  const DayDetailsSheet({
    super.key,
    required this.date,
    required this.onTaskTap,
  });

  @override
  ConsumerState<DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends ConsumerState<DayDetailsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      // 1. Create task via provider (connects to Supabase)
      await ref.read(tasksProvider.notifier).createTask(
        text,
        dueDate: widget.date,
      );
      
      _controller.clear();
      // Keep focus to add multiple tasks
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- NEW CONTEXT MENU LOGIC ---

  Future<void> _safeAction(Future<void> Function() action, String name) async {
    try {
      await FileLogger().log('UI_SHEET: $name started');
      await action();
    } catch (e, stack) {
      await FileLogger().error('UI_SHEET: $name failed', e, stack);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showTaskContextMenu(BuildContext context, Task task, TapUpDetails details) {
    final pos = details.globalPosition;
    final notifier = ref.read(tasksProvider.notifier);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent, // Add this to prevent M3 transparency issues
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
      items: TaskContextMenu.buildItems(
        context: context,
        task: task,
        onDateSelect: (d) {
          if (d == null) {
            _pickDate(task);
          } else {
            final u = Task(
                id: task.id, userId: task.userId, listId: task.listId, title: task.title, 
                isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, 
                isPinned: task.isPinned, dueDate: d
            );
            _safeAction(() => notifier.updateTask(u), 'Context: Update Date');
          }
        },
        onPrioritySelect: (p) {
          final u = Task(
              id: task.id, userId: task.userId, listId: task.listId, title: task.title, 
              isCompleted: task.isCompleted, priority: p, tagIds: task.tagIds, 
              isPinned: task.isPinned, dueDate: task.dueDate
          );
          _safeAction(() => notifier.updateTask(u), 'Context: Priority');
        },
        onPin: () {
          Navigator.pop(context);
          final u = Task(
              id: task.id, userId: task.userId, listId: task.listId, title: task.title, 
              isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, 
              isPinned: !task.isPinned, dueDate: task.dueDate
          );
          _safeAction(() => notifier.updateTask(u), 'Context: Pin');
        },
        onDuplicate: () {
          Navigator.pop(context);
          _safeAction(() => notifier.createTask(task.title, listId: task.listId, dueDate: task.dueDate), 'Context: Duplicate');
        },
        onMove: () {
          Navigator.pop(context);
          _showMoveToDialog(context, task);
        },
        onTags: () { Navigator.pop(context); },
        onDelete: () {
          Navigator.pop(context);
          _safeAction(() => notifier.deleteTask(task), 'Context: Delete');
        },
      ),
    );
  }

  Future<void> _pickDate(Task task) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: GlassTheme.accentColor,
            surface: Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final u = Task(
          id: task.id, userId: task.userId, listId: task.listId, title: task.title, 
          isCompleted: task.isCompleted, priority: task.priority, tagIds: task.tagIds, 
          isPinned: task.isPinned, dueDate: picked
      );
      _safeAction(() => ref.read(tasksProvider.notifier).updateTask(u), 'Context: Pick Date');
    }
  }

  Future<void> _showMoveToDialog(BuildContext context, Task task) async {
    final lists = ref.read(listsProvider).value ?? [];
    final notifier = ref.read(tasksProvider.notifier);

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
              const Text('Move to List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.inbox, color: Colors.white54),
                        title: const Text('Inbox', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          final u = Task(
                              id: task.id, userId: task.userId, title: task.title, description: task.description, 
                              dueDate: task.dueDate, priority: task.priority, isCompleted: task.isCompleted, 
                              isPinned: task.isPinned, tagIds: task.tagIds, listId: null
                          );
                          _safeAction(() => notifier.updateTask(u), 'Move to Inbox');
                        },
                      ),
                      ...lists.map((l) => ListTile(
                        leading: const Icon(Icons.list, color: Colors.white54),
                        title: Text(l.name, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          final u = Task(
                              id: task.id, userId: task.userId, title: task.title, description: task.description, 
                              dueDate: task.dueDate, priority: task.priority, isCompleted: task.isCompleted, 
                              isPinned: task.isPinned, tagIds: task.tagIds, listId: l.id
                          );
                          _safeAction(() => notifier.updateTask(u), 'Move to ${l.name}');
                        },
                      )),
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

  @override
  Widget build(BuildContext context) {
    // Filter tasks for this specific day
    final allTasksMap = ref.watch(calendarTasksProvider);
    final normalizedDate = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final dayTasks = allTasksMap[normalizedDate] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Date Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(widget.date),
                      style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat('MMMM d').format(widget.date),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GlassTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayTasks.length} Tasks',
                    style: const TextStyle(color: GlassTheme.accentColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // 3. Task List
          Expanded(
            child: dayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text(
                          "No tasks for this day",
                          style: TextStyle(color: Colors.white38),
                        ),
                      ],
                    ).animate().fadeIn(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayTasks.length,
                    itemBuilder: (context, index) {
                      final task = dayTasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskItem(
                          task: task,
                          onToggle: (val) {
                            HapticFeedback.selectionClick();
                            final updated = Task(
                              id: task.id, userId: task.userId, listId: task.listId,
                              title: task.title, description: task.description,
                              dueDate: task.dueDate, priority: task.priority,
                              tagIds: task.tagIds, isPinned: task.isPinned,
                              isCompleted: val ?? false
                            );
                            _safeAction(() => ref.read(tasksProvider.notifier).updateTask(updated), 'Toggle Task');
                          },
                          onTap: () {
                            Navigator.pop(context); // Close sheet
                            widget.onTaskTap(task); // Open full detail panel
                          },
                          // NEW: Connect context menu
                          onContextMenu: (details) => _showTaskContextMenu(context, task, details),
                        ).animate().slideX(begin: 0.1, end: 0, delay: (index * 50).ms),
                      );
                    },
                  ),
          ),

          // 4. Quick Add Input
          Padding(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16
            ),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              borderRadius: 16,
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Add a task for this day...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addTask(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, color: GlassTheme.accentColor),
                    onPressed: _addTask,
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
