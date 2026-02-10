import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task.dart';
import '../theme/glass_theme.dart';

class TaskItem extends StatelessWidget {
  final Task task;
  final Function(bool?) onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Transform.scale(
              scale: 0.9,
              child: Checkbox(
                value: task.isCompleted,
                onChanged: onToggle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(color: Colors.white60, width: 1.5),
                activeColor: GlassTheme.accentColor,
                checkColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            
            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: task.isCompleted ? Colors.white38 : Colors.white,
                      fontSize: 15,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white38,
                    ),
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                     const SizedBox(height: 2),
                     Text(
                      task.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (task.dueDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(task.dueDate!),
                      style: TextStyle(
                        color: _getDateColor(task.dueDate!),
                        fontSize: 11,
                      ),
                    ),
                  ]
                ],
              ),
            ),

            // Priority Indicator (if high)
            if (task.priority > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.flag,
                  size: 16,
                  color: _getPriorityColor(task.priority),
                ),
              ),

             // List Name (e.g. Inbox)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                "Inbox", // Mock list name for now
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 1: return Colors.blueAccent;
      default: return Colors.transparent;
    }
  }

  String _formatDate(DateTime date) {
    // Simple date formatting, can be improved with intl
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) return 'Today';
    if (taskDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    
    return '${date.day}/${date.month}'; 
  }

  Color _getDateColor(DateTime date) {
     final now = DateTime.now();
     if (date.isBefore(now) && !task.isCompleted) return Colors.redAccent;
     return Colors.white38;
  }
}
