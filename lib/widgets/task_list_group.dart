import 'package:flutter/material.dart';
import '../models/task.dart';
import 'task_item.dart';

class TaskListGroup extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final Function(Task, bool) onTaskToggle;
  final Function(Task)? onTaskTap;
  final Function(Task, TapUpDetails)? onTaskContextMenu;

  const TaskListGroup({
    super.key,
    required this.title,
    required this.tasks,
    required this.onTaskToggle,
    this.onTaskTap,
    this.onTaskContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              if (title == "Completed") 
                const Icon(Icons.check_circle_outline, size: 14, color: Colors.white54)
              else 
                const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tasks.length}',
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        // Tasks
        ...tasks.map((task) => TaskItem(
          task: task,
          onToggle: (val) => onTaskToggle(task, val ?? false),
          onTap: () => onTaskTap?.call(task),
            onContextMenu: (details) => onTaskContextMenu?.call(task, details),
        )),
      ],
    );
  }
}
