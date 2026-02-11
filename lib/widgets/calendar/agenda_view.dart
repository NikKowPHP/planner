import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../theme/glass_theme.dart';

class AgendaView extends StatelessWidget {
  final DateTime focusedDay;
  final List<Task> tasks;
  final Function(Task) onTaskTap;

  const AgendaView({
    super.key,
    required this.focusedDay,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Filter and Group Tasks
    final tasksWithDate = tasks.where((t) => t.dueDate != null).toList();
    
    // Sort by date
    tasksWithDate.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    // Group by Day
    final Map<String, List<Task>> grouped = {};
    for (var task in tasksWithDate) {
      final dateKey = DateFormat('yyyy-MM-dd').format(task.dueDate!);
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(task);
    }

    // Get sorted keys
    final sortedKeys = grouped.keys.toList()..sort();

    // Filter keys to start near focusedDay (optional, but good for context)
    // For now, we show all, but we could scroll to focusedDay if we used a ScrollController
    
    if (sortedKeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text("No upcoming tasks", style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayTasks = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);
        final isToday = _isSameDay(date, DateTime.now());

        return _AgendaDayGroup(
          date: date,
          tasks: dayTasks,
          isToday: isToday,
          onTaskTap: onTaskTap,
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _AgendaDayGroup extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;
  final bool isToday;
  final Function(Task) onTaskTap;

  const _AgendaDayGroup({
    required this.date,
    required this.tasks,
    required this.isToday,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date Column
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isToday ? GlassTheme.accentColor : Colors.white,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday ? GlassTheme.accentColor : Colors.white54,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Timeline Column (Line + Dots)
          SizedBox(
            width: 30,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                Positioned(
                  top: 16,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),

          // 3. Tasks Column
          Expanded(
            child: Column(
              children: tasks.asMap().entries.map((entry) {
                final task = entry.value;
                return _AgendaTaskItem(
                  task: task,
                  onTap: onTaskTap,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaTaskItem extends StatelessWidget {
  final Task task;
  final Function(Task) onTap;

  const _AgendaTaskItem({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor(task.priority);
    final timeStr = DateFormat('HH:mm').format(task.dueDate!);
    // Mock end time (+1h)
    final endStr = DateFormat('HH:mm').format(task.dueDate!.add(const Duration(hours: 1)));

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(task);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Dot (Visual connection to the timeline column)
            Transform.translate(
              offset: const Offset(-20, 4), // Shift left to align with timeline column
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414), // Match background
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
            ),
            
            // Time Label
            SizedBox(
              width: 45,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  timeStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Task Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeStr - $endStr', // Mock duration
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3: return const Color(0xFFFF6B6B);
      case 2: return const Color(0xFFFECA57);
      case 1: return const Color(0xFF48DBFB);
      default: return const Color(0xFF54A0FF);
    }
  }
}
