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
                            ref.read(tasksProvider.notifier).updateTask(updated);
                          },
                          onTap: () {
                            Navigator.pop(context); // Close sheet
                            widget.onTaskTap(task); // Open full detail panel
                          },
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
