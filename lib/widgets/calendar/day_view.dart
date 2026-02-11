import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../theme/glass_theme.dart';
import '../glass_card.dart';

class DayView extends StatefulWidget {
  final DateTime focusedDay;
  final List<Task> tasks;
  final Function(Task) onTaskTap;

  const DayView({
    super.key,
    required this.focusedDay,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  final double _hourHeight = 80.0;
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Scroll to current time on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      if (isSameDay(now, widget.focusedDay)) {
        final offset = (now.hour * _hourHeight) - 100; // Center slightly
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
        }
      }
    });
    
    // Update current time line every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    // Filter tasks that belong to this day
    final dayTasks = widget.tasks.where((t) {
      if (t.dueDate == null) return false;
      final tDate = t.dueDate!;
      return isSameDay(tDate, widget.focusedDay);
    }).toList();

    // Separate All-Day (time is 00:00) vs Time-Specific
    final allDayTasks = dayTasks.where((t) => t.dueDate!.hour == 0 && t.dueDate!.minute == 0).toList();
    final timedTasks = dayTasks.where((t) => t.dueDate!.hour != 0 || t.dueDate!.minute != 0).toList();

    return Column(
      children: [
        // All Day Section (if any)
        if (allDayTasks.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All Day', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDayTasks.map((t) => _AllDayTaskChip(task: t, onTap: widget.onTaskTap)).toList(),
                ),
              ],
            ),
          ),

        // Timeline
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Stack(
              children: [
                // 1. Grid Lines & Time Labels
                Column(
                  children: List.generate(24, (hour) {
                    return SizedBox(
                      height: _hourHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time Label
                          SizedBox(
                            width: 50,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 0), // Align with line
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Line
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                // 2. Task Blocks
                ...timedTasks.map((task) {
                  final hour = task.dueDate!.hour;
                  final minute = task.dueDate!.minute;
                  // Determine top position
                  final top = (hour * _hourHeight) + ((minute / 60) * _hourHeight);
                  // Default duration 1 hour for now since model doesn't have it
                  final height = _hourHeight; 

                  return Positioned(
                    top: top,
                    left: 70, // After time labels
                    right: 16,
                    height: height - 2, // Slight gap
                    child: _TimeTaskBlock(
                      task: task,
                      onTap: widget.onTaskTap,
                    ),
                  );
                }),

                // 3. Current Time Indicator
                if (isSameDay(DateTime.now(), widget.focusedDay))
                  Positioned(
                    top: (DateTime.now().hour * _hourHeight) + ((DateTime.now().minute / 60) * _hourHeight),
                    left: 0,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          alignment: Alignment.centerRight,
                          child: const Text(
                            'Now', // Or current time
                            style: TextStyle(color: GlassTheme.accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const CircleAvatar(radius: 3, backgroundColor: GlassTheme.accentColor),
                        Expanded(child: Container(height: 2, color: GlassTheme.accentColor)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeTaskBlock extends StatelessWidget {
  final Task task;
  final Function(Task) onTap;

  const _TimeTaskBlock({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor(task.priority);
    final start = DateFormat('HH:mm').format(task.dueDate!);
    // Mock end time (+1 hour)
    final end = DateFormat('HH:mm').format(task.dueDate!.add(const Duration(hours: 1)));

    return GestureDetector(
      onTap: () => onTap(task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$start - $end',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
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

class _AllDayTaskChip extends StatelessWidget {
  final Task task;
  final Function(Task) onTap;

  const _AllDayTaskChip({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(task),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: 8,
        child: Text(
          task.title,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
