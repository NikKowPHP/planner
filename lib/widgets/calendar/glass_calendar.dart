import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // For Haptics
import '../../models/task.dart';
import '../../theme/glass_theme.dart';
import '../../providers/app_providers.dart';
import '../glass_card.dart';
import 'day_details_sheet.dart'; // Import the new sheet
import 'day_view.dart';
import 'agenda_view.dart'; // Import AgendaView


class GlassCalendar extends ConsumerStatefulWidget {
  final Function(Task) onTaskTap;

  const GlassCalendar({super.key, required this.onTaskTap});

  @override
  ConsumerState<GlassCalendar> createState() => _GlassCalendarState();
}

class _GlassCalendarState extends ConsumerState<GlassCalendar> {
  DateTime _focusedDay = DateTime.now();
  
  // Custom View State (instead of just CalendarFormat)
  // 0 = Month, 1 = Week, 2 = Day, 3 = Agenda
  int _viewMode = 0; 
  CalendarFormat _calendarFormat = CalendarFormat.month;

  void _setFormat(int mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _viewMode = mode;
      if (mode == 0) _calendarFormat = CalendarFormat.month;
      if (mode == 1) _calendarFormat = CalendarFormat.week;
      // mode 2 (Day) & 3 (Agenda) use custom widgets
    });
  }

  // 1. Show Bottom Sheet on Tap
  void _showDayDetails(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75, // 75% height
        child: DayDetailsSheet(date: date, onTaskTap: widget.onTaskTap),
      ),
    );
  }

  // 2. Show Quick Add Dialog on Long Press
  Future<void> _showQuickAddDialog(DateTime date) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Add',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d').format(date),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Task name",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            Navigator.pop(ctx, controller.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GlassTheme.accentColor,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((value) {
      if (value != null && value.toString().isNotEmpty) {
        ref.read(tasksProvider.notifier).createTask(value, dueDate: date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksMap = ref.watch(calendarTasksProvider);
    // Get full list for Agenda View
    final allTasks = ref.watch(tasksProvider).asData?.value ?? [];

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(tasksMap, allTasks),
            ),
          ],
        ),
        
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Center(
            child: GlassCard(
              height: 50,
              width: 340, // Slightly wider for 4 buttons
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              borderRadius: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ViewSwitchButton(
                    text: 'Month',
                    isSelected: _viewMode == 0,
                    onTap: () => _setFormat(0),
                  ),
                  _ViewSwitchButton(
                    text: 'Week',
                    isSelected: _viewMode == 1,
                    onTap: () => _setFormat(1),
                  ),
                  _ViewSwitchButton(
                    text: 'Day',
                    isSelected: _viewMode == 2,
                    onTap: () => _setFormat(2),
                  ),
                  _ViewSwitchButton(
                    text: 'Agenda',
                    isSelected: _viewMode == 3,
                    onTap: () => _setFormat(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_focusedDay),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    // Adjust based on view mode? For now just month increment is fine or day
                    if (_viewMode == 2) {
                      _focusedDay = _focusedDay.subtract(
                        const Duration(days: 1),
                      );
                    } else {
                      _focusedDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month - 1,
                      );
                    }
                  });
                },
              ),
              TextButton(
                onPressed: () => setState(() => _focusedDay = DateTime.now()),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    if (_viewMode == 2) {
                      _focusedDay = _focusedDay.add(const Duration(days: 1));
                    } else {
                      _focusedDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month + 1,
                      );
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Map<DateTime, List<Task>> tasksMap, List<Task> allTasks) {
    if (_viewMode == 3) {
      return AgendaView(
        focusedDay: _focusedDay,
        tasks: allTasks,
        onTaskTap: widget.onTaskTap,
      );
    }

    if (_viewMode == 2) {
      return DayView(
        focusedDay: _focusedDay,
        tasks: allTasks,
        onTaskTap: widget.onTaskTap,
      );
    }

    return TableCalendar<Task>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      shouldFillViewport: true,
      rowHeight: 120,
      daysOfWeekHeight: 40,
      headerVisible: false,

      onDaySelected: (selectedDay, focusedDay) {
        HapticFeedback.lightImpact();
        setState(() => _focusedDay = focusedDay);
        _showDayDetails(selectedDay);
      },
      onDayLongPressed: (selectedDay, focusedDay) {
        HapticFeedback.heavyImpact();
        setState(() => _focusedDay = focusedDay);
        _showQuickAddDialog(selectedDay);
      },

      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white38, fontSize: 12),
        weekendStyle: TextStyle(color: Colors.white38, fontSize: 12),
      ),

      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) =>
            _buildCell(context, day, tasksMap, isToday: false),
        todayBuilder: (context, day, focusedDay) =>
            _buildCell(context, day, tasksMap, isToday: true),
        outsideBuilder: (context, day, focusedDay) =>
            _buildCell(context, day, tasksMap, isOutside: true),
        selectedBuilder: (context, day, focusedDay) => _buildCell(
          context,
          day,
          tasksMap,
          isToday: false,
          isSelected: true,
        ),
      ),

      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
      },
    );
  }

  Widget _buildCell(
    BuildContext context,
    DateTime day,
    Map<DateTime, List<Task>> tasksMap, {
    bool isToday = false,
    bool isOutside = false,
    bool isSelected = false,
  }) {
    final normalized = DateTime(day.year, day.month, day.day);
    final tasks = tasksMap[normalized] ?? [];

    // Wrap content in a transparent container to ensure the whole cell is tapable via TableCalendar
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        color: isSelected
            ? GlassTheme.accentColor.withValues(alpha: 0.1)
            : (isOutside
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.01)),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isToday ? GlassTheme.accentColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : (isOutside ? Colors.white24 : Colors.white70),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tasks List
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                if (index > 3) return const SizedBox.shrink();
                if (index == 3) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+${tasks.length - 3} more',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return _CalendarTaskItem(
                  task: tasks[index],
                  onTap: widget.onTaskTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTaskItem extends StatelessWidget {
  final Task task;
  final Function(Task) onTap;

  const _CalendarTaskItem({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getTaskColor(task);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick(); // Add haptic here too
        onTap(task);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Row(
          children: [
            if (!task.isCompleted)
              Container(
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4, 
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 9,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(Task task) {
    if (task.isCompleted) return Colors.grey;
    switch (task.priority) {
      case 3:
        return const Color(0xFFFF6B6B);
      case 2:
        return const Color(0xFFFECA57);
      case 1:
        return const Color(0xFF48DBFB);
      default: 
        final colors = [
          const Color(0xFF10AC84),
          const Color(0xFF5F27CD),
          const Color(0xFFFF9F43),
          const Color(0xFF54A0FF),
        ];
        return colors[task.title.hashCode % colors.length];
    }
  }
}

class _ViewSwitchButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ViewSwitchButton({
    required this.text,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
