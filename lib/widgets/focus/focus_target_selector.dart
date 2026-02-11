import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../models/task.dart';
import '../../models/habit.dart';
import '../../theme/glass_theme.dart';
import '../glass_card.dart';

class FocusTargetSelector extends ConsumerWidget {
  final Function(dynamic) onSelected; // Task or Habit
  final dynamic currentSelection;

  const FocusTargetSelector({
    super.key,
    required this.onSelected,
    this.currentSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider); // Reusing filtered logic or create specific logic
    final habits = ref.watch(habitsProvider).asData?.value ?? [];
    
    // Filter for "Today" / "Overdue" logic manually if needed, or use existing filteredTasksProvider
    // For TickTick style, we usually show "Today" tasks
    final todayTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tDate = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return tDate.isAtSameMomentAs(today) || tDate.isBefore(today);
    }).toList();

    return GlassCard(
      width: 300,
      height: 400,
      padding: const EdgeInsets.all(0),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: GlassTheme.accentColor,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              tabs: [Tab(text: "Tasks"), Tab(text: "Habits")],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTaskList(todayTasks),
                  _buildHabitList(habits),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) return const Center(child: Text("No tasks for today", style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final t = tasks[index];
        final isSelected = currentSelection is Task && (currentSelection as Task).id == t.id;
        return ListTile(
          leading: Icon(Icons.circle_outlined, color: _getPriorityColor(t.priority), size: 16),
          title: Text(t.title, style: const TextStyle(color: Colors.white)),
          trailing: isSelected ? const Icon(Icons.check, color: GlassTheme.accentColor) : null,
          onTap: () => onSelected(t),
        );
      },
    );
  }

  Widget _buildHabitList(List<Habit> habits) {
    if (habits.isEmpty) return const Center(child: Text("No habits", style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final h = habits[index];
        final isSelected = currentSelection is Habit && (currentSelection as Habit).id == h.id;
        return ListTile(
          leading: Icon(Icons.loop, color: Colors.white70, size: 16),
          title: Text(h.name, style: const TextStyle(color: Colors.white)),
          trailing: isSelected ? const Icon(Icons.check, color: GlassTheme.accentColor) : null,
          onTap: () => onSelected(h),
        );
      },
    );
  }

  Color _getPriorityColor(int p) {
    switch(p) {
      case 3: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 1: return Colors.blueAccent;
      default: return Colors.grey;
    }
  }
}
